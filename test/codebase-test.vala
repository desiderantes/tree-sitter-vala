/*
 * Generic codebase validation test tool for tree-sitter-vala.
 *
 * Recursively scans any codebase for Vala source files, parses each one using
 * tree-sitter-vala, detects root syntax errors / missing nodes, and prints
 * summary statistics and detailed error locations.
 *
 * Exits with code 77 (SKIP) if no codebase directory is given or if the directory
 * does not exist.
 */

public class ErrorInfo {
	public string file_path;
	public string rel_path;
	public uint row;
	public uint col;
	public string snippet;

	public ErrorInfo (string file_path, string rel_path, uint row, uint col, string snippet) {
		this.file_path = file_path;
		this.rel_path = rel_path;
		this.row = row;
		this.col = col;
		this.snippet = snippet;
	}
}

public class CodebaseTester {
	public string? codebase_dir = null;
	public string? log_file = null;
	public bool write_summary = false;
	public GenericArray<PatternSpec> exclude_patterns = new GenericArray<PatternSpec> ();

	private GenericArray<string> vala_files = new GenericArray<string> ();
	private GenericArray<ErrorInfo> error_details = new GenericArray<ErrorInfo> ();
	private uint total_parsed = 0;
	private uint successful_parses = 0;
	private uint failed_parses = 0;

	public void add_exclude_pattern (string pattern) {
		string p = pattern.strip ();
		if (p == "") {
			return;
		}

		// If pattern ends with '/', match everything under that directory
		if (p.has_suffix ("/")) {
			p += "*";
		}

		exclude_patterns.add (new PatternSpec (p));
	}

	public int run () {
		if (codebase_dir == null || codebase_dir == "") {
			print ("No codebase directory specified. Skipping codebase validation test.\n");
			print ("Usage: tree-sitter-vala-codebase-test --codebase <path> [--exclude <pattern>] [--log-file <path>] [--summary]\n");
			return 77; // Standard Meson / Automake skip exit code
		}

		File dir = File.new_for_path (codebase_dir);
		if (!dir.query_exists ()) {
			stderr.printf ("Codebase directory '%s' does not exist. Skipping.\n", codebase_dir);
			return 77;
		}

		print ("=== Scanning Vala files in: %s ===\n", codebase_dir);
		scan_directory (dir);
		print ("Found %u .vala files to parse.\n", vala_files.length);

		if (vala_files.length == 0) {
			print ("No .vala files found in '%s'. Skipping.\n", codebase_dir);
			return 77;
		}

		var parser = new TreeSitter.Parser ();
		if (!parser.set_language (TreeSitter.vala_language ())) {
			stderr.printf ("Error: Failed to set tree-sitter-vala language on parser!\n");
			return 1;
		}

		var timer = new Timer ();
		timer.start ();

		for (uint i = 0; i < vala_files.length; i++) {
			parse_file (parser, vala_files.get (i));
		}

		timer.stop ();
		double elapsed = timer.elapsed ();

		print_report (elapsed);
		write_output_log ();
		write_github_step_summary ();

		return failed_parses > 0 ? 1 : 0;
	}

	[CCode (cname = "g_pattern_spec_match_string")]
	private static extern bool match_pattern (PatternSpec pspec, string str);

	private bool is_excluded (string rel_path, bool is_dir) {
		for (uint i = 0; i < exclude_patterns.length; i++) {
			unowned PatternSpec ps = exclude_patterns.get (i);
			if (match_pattern (ps, rel_path)) {
				return true;
			}
			if (is_dir && match_pattern (ps, rel_path + "/")) {
				return true;
			}
		}
		return false;
	}

	private void scan_directory (File dir) {
		try {
			var enumerator = dir.enumerate_children (
				FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
				FileQueryInfoFlags.NOFOLLOW_SYMLINKS
			);

			FileInfo? info = null;
			while ((info = enumerator.next_file ()) != null) {
				string name = info.get_name ();
				if (name.has_prefix (".")) {
					continue;
				}

				File child = dir.get_child (name);
				FileType ftype = info.get_file_type ();

				string rel_path = get_relative_path (child.get_path ());

				if (ftype == FileType.DIRECTORY) {
					if (!is_excluded (rel_path, true)) {
						scan_directory (child);
					}
				} else if (ftype == FileType.REGULAR && name.has_suffix (".vala")) {
					if (!is_excluded (rel_path, false)) {
						vala_files.add (child.get_path ());
					}
				}
			}
		} catch (Error e) {
			stderr.printf ("Failed to enumerate %s: %s\n", dir.get_path (), e.message);
		}
	}

	private string get_relative_path (string full_path) {
		if (full_path.has_prefix (codebase_dir)) {
			string rel = full_path.substring (codebase_dir.length);
			if (rel.has_prefix ("/")) {
				return rel.substring (1);
			}
			return rel;
		}
		return full_path;
	}

	private void parse_file (TreeSitter.Parser parser, string file_path) {
		total_parsed++;
		string rel_path = get_relative_path (file_path);

		string source_code;
		try {
			FileUtils.get_contents (file_path, out source_code);
		} catch (FileError e) {
			failed_parses++;
			error_details.add (new ErrorInfo (file_path, rel_path, 0, 0, "Could not read file: " + e.message));
			return;
		}

		TreeSitter.Tree? tree = parser.parse_string (source_code, null);
		if (tree == null) {
			failed_parses++;
			error_details.add (new ErrorInfo (file_path, rel_path, 0, 0, "tree-sitter returned null tree"));
			return;
		}

		TreeSitter.Node root = tree.root_node ();
		if (root.has_error) {
			failed_parses++;
			TreeSitter.Node? first_err = find_first_error_node (root);
			if (first_err != null) {
				TreeSitter.Point pt = first_err.start_point;
				string snippet = extract_snippet (source_code, pt.row, pt.column);
				error_details.add (new ErrorInfo (file_path, rel_path, pt.row + 1, pt.column + 1, snippet));
			} else {
				error_details.add (new ErrorInfo (file_path, rel_path, 1, 1, "has_error is true but no error node located"));
			}
		} else {
			successful_parses++;
		}
	}

	private TreeSitter.Node? find_first_error_node (TreeSitter.Node node) {
		if (node.is_error || node.is_missing) {
			return node;
		}
		uint count = node.child_count;
		for (uint i = 0; i < count; i++) {
			TreeSitter.Node child = node.child (i);
			if (child.has_error) {
				TreeSitter.Node? found = find_first_error_node (child);
				if (found != null) {
					return found;
				}
			}
		}
		return null;
	}

	private string extract_snippet (string source, uint row, uint col) {
		string[] lines = source.split ("\n");
		if (row >= lines.length) {
			return "(end of file)";
		}
		string line = lines[row];
		var pointer = new StringBuilder ();
		for (uint i = 0; i < col; i++) {
			if (i < line.length && line[(long) i] == '\t') {
				pointer.append_c ('\t');
			} else {
				pointer.append_c (' ');
			}
		}
		pointer.append_c ('^');
		return "%s\n%s".printf (line, pointer.str);
	}

	private void print_report (double elapsed) {
		double rate = total_parsed > 0 ? ((double) successful_parses / total_parsed) * 100.0 : 100.0;
		print ("\n======================================================================\n");
		print ("CODEBASE VALIDATION REPORT\n");
		print ("======================================================================\n");
		print ("Total files parsed  : %u\n", total_parsed);
		print ("Successful parses   : %u\n", successful_parses);
		print ("Failed parses       : %u\n", failed_parses);
		print ("Success rate        : %.2f%%\n", rate);
		print ("Elapsed time        : %.2fs (%.1f files/s)\n", elapsed, elapsed > 0 ? total_parsed / elapsed : 0);
		print ("======================================================================\n");

		if (failed_parses > 0) {
			print ("\nFailed files (%u total):\n", failed_parses);
			uint display_count = error_details.length > 25 ? 25 : error_details.length;
			for (uint i = 0; i < display_count; i++) {
				ErrorInfo err = error_details.get (i);
				print ("\n✗ %s:%u:%u\n", err.rel_path, err.row, err.col);
				string[] snippet_lines = err.snippet.split ("\n");
				foreach (unowned string sline in snippet_lines) {
					print ("    %s\n", sline);
				}
			}
			if (error_details.length > display_count) {
				print ("\n... and %u more failures (see log file if specified).\n", error_details.length - display_count);
			}
		}
	}

	private void write_output_log () {
		if (log_file == null || log_file == "") {
			return;
		}

		try {
			var sb = new StringBuilder ();
			double rate = total_parsed > 0 ? ((double) successful_parses / total_parsed) * 100.0 : 100.0;
			sb.append ("# Codebase Validation Results\n\n");
			sb.append_printf ("- **Target directory**: `%s`\n", codebase_dir);
			sb.append_printf ("- **Total files**: %u\n", total_parsed);
			sb.append_printf ("- **Passed**: %u\n", successful_parses);
			sb.append_printf ("- **Failed**: %u\n", failed_parses);
			sb.append_printf ("- **Success Rate**: %.2f%%\n\n", rate);

			if (failed_parses > 0) {
				sb.append ("## Failing Files Details\n\n");
				sb.append ("| File | Line | Snippet |\n");
				sb.append ("| :--- | :---: | :--- |\n");
				for (uint i = 0; i < error_details.length; i++) {
					ErrorInfo err = error_details.get (i);
					string escaped = err.snippet.replace ("|", "\\|").replace ("\n", "<br>");
					sb.append_printf ("| `%s` | %u:%u | `<pre>%s</pre>` |\n", err.rel_path, err.row, err.col, escaped);
				}
			}

			File f = File.new_for_path (log_file);
			File? parent = f.get_parent ();
			if (parent != null && !parent.query_exists ()) {
				parent.make_directory_with_parents ();
			}
			FileUtils.set_contents (log_file, sb.str);
			print ("\nWrote failure log to: %s\n", log_file);
		} catch (Error e) {
			stderr.printf ("Failed to write log file '%s': %s\n", log_file, e.message);
		}
	}

	private void write_github_step_summary () {
		string? summary_file = Environment.get_variable ("GITHUB_STEP_SUMMARY");
		if (!write_summary || summary_file == null || summary_file == "") {
			return;
		}

		try {
			var sb = new StringBuilder ();
			double rate = total_parsed > 0 ? ((double) successful_parses / total_parsed) * 100.0 : 100.0;
			sb.append ("### 🌳 Tree-sitter Vala Codebase Validation Report\n\n");
			sb.append_printf ("Parsed **%u** files in `%s` with **%.2f%%** success (%u passed, %u failed).\n\n",
				total_parsed, codebase_dir, rate, successful_parses, failed_parses);

			if (failed_parses > 0) {
				sb.append_printf ("<details><summary><b>Detailed Error List (%u failures)</b></summary>\n\n", failed_parses);
				sb.append ("| File | Line | Snippet |\n");
				sb.append ("| :--- | :---: | :--- |\n");
				for (uint i = 0; i < error_details.length; i++) {
					ErrorInfo err = error_details.get (i);
					string escaped = err.snippet.replace ("|", "\\|").replace ("\n", "<br>");
					sb.append_printf ("| `%s` | %u:%u | `<pre>%s</pre>` |\n", err.rel_path, err.row, err.col, escaped);
				}
				sb.append ("\n</details>\n");
			}

			File sum_f = File.new_for_path (summary_file);
			FileOutputStream stream = sum_f.append_to (FileCreateFlags.NONE);
			stream.write_all (sb.str.data, null);
		} catch (Error e) {
			stderr.printf ("Failed to write GitHub summary: %s\n", e.message);
		}
	}
}

int main (string[] args) {
	var app = new CodebaseTester ();

	string? env_codebase = Environment.get_variable ("VALA_CODEBASE");
	if (env_codebase != null && env_codebase != "") {
		app.codebase_dir = env_codebase;
	}

	for (int i = 1; i < args.length; i++) {
		if (args[i] == "--summary") {
			app.write_summary = true;
		} else if ((args[i] == "--codebase" || args[i] == "--codebase-dir") && i + 1 < args.length) {
			app.codebase_dir = args[++i];
		} else if (args[i] == "--log-file" && i + 1 < args.length) {
			app.log_file = args[++i];
		} else if ((args[i] == "--exclude" || args[i] == "-e") && i + 1 < args.length) {
			app.add_exclude_pattern (args[++i]);
		} else if (!args[i].has_prefix ("-")) {
			app.codebase_dir = args[i];
		}
	}

	return app.run ();
}
