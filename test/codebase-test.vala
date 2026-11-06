/*
 * Generic codebase validation test tool for tree-sitter-vala.
 *
 * Recursively scans any codebase for Vala source files, parses each one using
 * tree-sitter-vala, detects root syntax errors / missing nodes, and prints
 * summary statistics and detailed error locations.
 *
 * Also supports negative parse matching (--expect-fail): files matching these
 * patterns are expected to contain syntax errors. If any such file parses without
 * error, it is recorded as an unexpected success (too lenient grammar).
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
	public bool is_unexpected_success;

	public ErrorInfo (string file_path, string rel_path, uint row, uint col, string snippet, bool is_unexpected_success = false) {
		this.file_path = file_path;
		this.rel_path = rel_path;
		this.row = row;
		this.col = col;
		this.snippet = snippet;
		this.is_unexpected_success = is_unexpected_success;
	}
}

public class CodebaseTester {
	public string? codebase_dir = null;
	public string? log_file = null;
	public bool write_summary = false;
	public GenericArray<PatternSpec> exclude_patterns = new GenericArray<PatternSpec> ();
	public GenericArray<PatternSpec> expect_fail_patterns = new GenericArray<PatternSpec> ();

	private GenericArray<string> vala_files = new GenericArray<string> ();
	private GenericArray<ErrorInfo> error_details = new GenericArray<ErrorInfo> ();
	private uint total_parsed = 0;
	private uint successful_parses = 0;
	private uint failed_parses = 0;
	private uint expected_fail_total = 0;
	private uint expected_fail_passed = 0;
	private uint unexpected_successes = 0;

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

	public void add_expect_fail_pattern (string pattern) {
		string p = pattern.strip ();
		if (p == "") {
			return;
		}

		if (p.has_suffix ("/")) {
			p += "*";
		}

		expect_fail_patterns.add (new PatternSpec (p));
	}

	public int run () {
		if (codebase_dir == null || codebase_dir == "") {
			print ("No codebase directory specified. Skipping codebase validation test.\n");
			print ("Usage: tree-sitter-vala-codebase-test --codebase <path> [--exclude <pattern>] [--expect-fail <pattern>] [--log-file <path>] [--summary]\n");
			return 77; // Standard Meson / Automake skip exit code
		}

		File dir = File.new_for_path (codebase_dir);
		if (!dir.query_exists ()) {
			stderr.printf ("Error: Target codebase directory does not exist: %s\n", codebase_dir);
			return 77;
		}

		print ("=== Scanning Vala files in: %s ===\n", codebase_dir);
		scan_directory (dir);
		print ("Found %u .vala files to parse.\n", vala_files.length);

		if (vala_files.length == 0) {
			print ("Warning: No .vala files found in target codebase.\n");
			return 77;
		}

		var parser = new TreeSitter.Parser ();
		if (!parser.set_language (TreeSitter.vala_language ())) {
			stderr.printf ("Error: Failed to set parser language to Vala (ABI mismatch?)\n");
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

		if (failed_parses > 0 || unexpected_successes > 0) {
			return 1;
		}

		return 0;
	}

	private bool is_excluded (string rel_path, bool is_dir) {
		string path_to_match = rel_path;
		if (is_dir && !path_to_match.has_suffix ("/")) {
			path_to_match += "/";
		}

		for (uint i = 0; i < exclude_patterns.length; i++) {
			unowned PatternSpec pattern = exclude_patterns.get (i);
			if (pattern.match_string (path_to_match) || pattern.match_string (rel_path)) {
				return true;
			}
		}
		return false;
	}

	private bool is_expected_to_fail (string rel_path) {
		for (uint i = 0; i < expect_fail_patterns.length; i++) {
			unowned PatternSpec pattern = expect_fail_patterns.get (i);
			if (pattern.match_string (rel_path)) {
				return true;
			}
		}
		return false;
	}

	private void scan_directory (File dir) {
		try {
			FileEnumerator enumerator = dir.enumerate_children (
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
		bool expected_fail = is_expected_to_fail (rel_path);
		if (expected_fail) {
			expected_fail_total++;
		}

		string source_code;
		try {
			FileUtils.get_contents (file_path, out source_code);
		} catch (FileError e) {
			if (expected_fail) {
				expected_fail_passed++;
			} else {
				failed_parses++;
				error_details.add (new ErrorInfo (file_path, rel_path, 0, 0, "Could not read file: " + e.message));
			}
			return;
		}

		TreeSitter.Tree? tree = parser.parse_string (source_code, null);
		if (tree == null) {
			if (expected_fail) {
				expected_fail_passed++;
			} else {
				failed_parses++;
				error_details.add (new ErrorInfo (file_path, rel_path, 0, 0, "tree-sitter returned null tree"));
			}
			return;
		}

		TreeSitter.Node root = tree.root_node ();
		if (root.has_error) {
			if (expected_fail) {
				// Expected to fail, and syntax error correctly detected!
				expected_fail_passed++;
			} else {
				failed_parses++;
				TreeSitter.Node? first_err = find_first_error_node (root);
				if (first_err != null) {
					TreeSitter.Point pt = first_err.start_point;
					string snippet = extract_snippet (source_code, pt.row, pt.column);
					error_details.add (new ErrorInfo (file_path, rel_path, pt.row + 1, pt.column + 1, snippet));
				} else {
					error_details.add (new ErrorInfo (file_path, rel_path, 1, 1, "has_error is true but no error node located"));
				}
			}
		} else {
			if (expected_fail) {
				// Too lenient! It parsed cleanly when syntax error was expected.
				unexpected_successes++;
				error_details.add (new ErrorInfo (
					file_path,
					rel_path,
					1,
					1,
					"UNEXPECTED SUCCESS: File was expected to fail parsing but parsed cleanly without syntax errors (grammar is too lenient).",
					true
				));
			} else {
				successful_parses++;
			}
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
		uint regular_total = total_parsed - expected_fail_total;
		double rate = regular_total > 0 ? ((double) successful_parses / regular_total) * 100.0 : 100.0;
		print ("\n======================================================================\n");
		print ("CODEBASE VALIDATION REPORT\n");
		print ("======================================================================\n");
		print ("Total files parsed       : %u\n", total_parsed);
		print ("Regular files parsed     : %u\n", regular_total);
		print ("Successful parses        : %u\n", successful_parses);
		print ("Unexpected syntax errors : %u\n", failed_parses);
		print ("Success rate             : %.2f%%\n", rate);
		if (expected_fail_total > 0) {
			print ("Expected fail files      : %u\n", expected_fail_total);
			print ("Expectedly failed        : %u\n", expected_fail_passed);
			print ("Unexpected successes     : %u (too lenient)\n", unexpected_successes);
		}
		print ("Elapsed time             : %.2fs (%.1f files/s)\n", elapsed, elapsed > 0 ? total_parsed / elapsed : 0);
		print ("======================================================================\n");

		if (failed_parses > 0 || unexpected_successes > 0) {
			print ("\nFailures (%u total):\n", error_details.length);
			uint display_count = error_details.length > 25 ? 25 : error_details.length;
			for (uint i = 0; i < display_count; i++) {
				ErrorInfo err = error_details.get (i);
				if (err.is_unexpected_success) {
					print ("\n⚠️  UNEXPECTED SUCCESS: %s\n    %s\n", err.rel_path, err.snippet);
				} else {
					print ("\n✗ %s:%u:%u\n", err.rel_path, err.row, err.col);
					string[] snippet_lines = err.snippet.split ("\n");
					foreach (unowned string sline in snippet_lines) {
						print ("    %s\n", sline);
					}
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
			uint regular_total = total_parsed - expected_fail_total;
			double rate = regular_total > 0 ? ((double) successful_parses / regular_total) * 100.0 : 100.0;
			sb.append ("# Codebase Validation Results\n\n");
			sb.append_printf ("- **Target directory**: `%s`\n", codebase_dir);
			sb.append_printf ("- **Total files**: %u\n", total_parsed);
			sb.append_printf ("- **Regular files**: %u\n", regular_total);
			sb.append_printf ("- **Passed**: %u\n", successful_parses);
			sb.append_printf ("- **Failed**: %u\n", failed_parses);
			if (expected_fail_total > 0) {
				sb.append_printf ("- **Expected failure files**: %u\n", expected_fail_total);
				sb.append_printf ("- **Correctly rejected**: %u\n", expected_fail_passed);
				sb.append_printf ("- **Unexpected passes (too lenient)**: %u\n", unexpected_successes);
			}
			sb.append_printf ("- **Success Rate**: %.2f%%\n\n", rate);

			if (error_details.length > 0) {
				sb.append ("## Failing Files Details\n\n");
				sb.append ("| File | Type | Line | Details |\n");
				sb.append ("| :--- | :---: | :---: | :--- |\n");
				for (uint i = 0; i < error_details.length; i++) {
					ErrorInfo err = error_details.get (i);
					string escaped = err.snippet.replace ("|", "\\|").replace ("\n", "<br>");
					string kind = err.is_unexpected_success ? "Too Lenient (Pass)" : "Syntax Error";
					sb.append_printf ("| `%s` | %s | %u:%u | `<pre>%s</pre>` |\n", err.rel_path, kind, err.row, err.col, escaped);
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
			uint regular_total = total_parsed - expected_fail_total;
			double rate = regular_total > 0 ? ((double) successful_parses / regular_total) * 100.0 : 100.0;
			sb.append ("### 🌳 Tree-sitter Vala Codebase Validation Report\n\n");
			sb.append_printf ("Parsed **%u** files in `%s` with **%.2f%%** success (%u passed, %u failed).\n\n",
				regular_total, codebase_dir, rate, successful_parses, failed_parses);

			if (expected_fail_total > 0) {
				sb.append_printf ("- Negative test files checked: **%u** (correctly rejected: **%u**, unexpected passes: **%u**)\n\n",
					expected_fail_total, expected_fail_passed, unexpected_successes);
			}

			if (error_details.length > 0) {
				sb.append_printf ("<details><summary><b>Detailed Error List (%u items)</b></summary>\n\n", error_details.length);
				sb.append ("| File | Type | Line | Details |\n");
				sb.append ("| :--- | :---: | :---: | :--- |\n");
				for (uint i = 0; i < error_details.length; i++) {
					ErrorInfo err = error_details.get (i);
					string escaped = err.snippet.replace ("|", "\\|").replace ("\n", "<br>");
					string kind = err.is_unexpected_success ? "Too Lenient (Pass)" : "Syntax Error";
					sb.append_printf ("| `%s` | %s | %u:%u | `<pre>%s</pre>` |\n", err.rel_path, kind, err.row, err.col, escaped);
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
		} else if ((args[i] == "--expect-fail" || args[i] == "--negative" || args[i] == "-x") && i + 1 < args.length) {
			app.add_expect_fail_pattern (args[++i]);
		} else if (!args[i].has_prefix ("-")) {
			app.codebase_dir = args[i];
		}
	}

	return app.run ();
}
