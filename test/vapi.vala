using TreeSitter;

bool cancel_immediately (ref ParseState state) {
	return true;
}

Parser create_parser () {
	var parser = new Parser ();
	assert (parser.set_language (vala_language ()));
	return parser;
}

void test_language () {
	unowned Language language = vala_language ();
	assert (language.symbol_count () > 0);
	assert (language.symbol_for_name ("class_declaration") != 0);
	assert (language.field_id_for_name ("expression") != 0);

	Language language_dup = language.dup ();
	assert (language_dup.symbol_count () == language.symbol_count ());

	LookaheadIterator? lookahead = LookaheadIterator.create (language, 1);
	assert (lookahead != null);
	assert (lookahead.next ());
}

void test_parse_string_and_bytes () {
	var parser = create_parser ();

	TreeSitter.Tree? valid_tree = parser.parse_string ("class Example {}\n");
	assert (valid_tree != null);
	assert (!valid_tree.root_node ().has_error);

	string raw_input = "class Raw {}\n";
	TreeSitter.Tree? bytes_tree = parser.parse_bytes (raw_input.data);
	assert (bytes_tree != null);
	assert (!bytes_tree.root_node ().has_error);

	TreeSitter.Tree tree_dup = valid_tree.dup ();
	assert (!tree_dup.root_node ().has_error);

	TreeSitter.Tree? invalid_tree = parser.parse_string ("class {\n");
	assert (invalid_tree != null);
	assert (invalid_tree.root_node ().has_error);
}

void test_node_properties () {
	var parser = create_parser ();

	TreeSitter.Tree tree = parser.parse_string ("class Example {}\n");
	TreeSitter.Node root = tree.root_node ();
	assert (root.type == "source_file");
	assert (root.symbol_name () == "source_file");
	assert (root.text ("class Example {}\n") == "class Example {}\n");
	assert (root.start_byte == 0);
	assert (root.end_byte == 17);
	assert (root.end_point.row == 1);
	assert (root.named_child_count == 1);
	assert (root.parent.is_null);
	assert (root.named_child (0).parent.equal (root));
	assert (root.language.symbol_count () > 0);

	TreeSitter.Tree directive_tree = parser.parse_string ("#if FOO\n#endif\n");
	TreeSitter.Node if_directive = directive_tree.root_node ().named_child (0);
	assert (if_directive.type == "if_directive");
	assert (!if_directive.child_by_field_name ("expression").is_null);
}

void test_tree_cursor () {
	var parser = create_parser ();

	TreeSitter.Tree tree = parser.parse_string ("class Example {}\n");
	TreeCursor cursor = TreeCursor (tree.root_node ());
	assert (cursor.goto_first_child ());

	TreeCursor copy = cursor.copy ();
	assert (copy.current_node ().equal (cursor.current_node ()));
	assert (copy.goto_parent ());
	assert (copy.current_node ().type == "source_file");
	assert (cursor.current_node ().type != "source_file");
}

void test_edits () {
	var parser = create_parser ();

	string source = "class Example {}\n";
	TreeSitter.Tree tree = parser.parse_string (source);
	TreeSitter.Node class_node = tree.root_node ().named_child (0).named_child (0);
	assert (class_node.start_byte == 0);

	// Insert "public " at the start of the document.
	InputEdit edit = {
		0, 0, 7,
		{ 0, 0 }, { 0, 0 }, { 0, 7 }
	};
	tree.edit (edit);
	assert (tree.root_node ().has_changes);

	edit.apply_to_node (ref class_node);
	assert (class_node.start_byte == 7);

	TreeSitter.Point point = { 0, 10 };
	uint32 point_byte = 10;
	edit.apply_to_point (ref point, ref point_byte);
	assert (point.column == 17);
	assert (point_byte == 17);

	TreeSitter.Range range = { { 0, 10 }, { 0, 12 }, 10, 12 };
	edit.apply_to_range (ref range);
	assert (range.start_byte == 17 && range.end_byte == 19);

	TreeSitter.Tree? new_tree = parser.parse_string ("public " + source, tree);
	assert (new_tree != null);
	assert (!new_tree.root_node ().has_error);
}

void test_callbacks () {
	var parser = create_parser ();

	int log_calls = 0;
	parser.logger = { (log_type, message) => { log_calls++; } };
	parser.parse_string ("class A {}\n");
	assert (log_calls > 0);
	parser.logger = { null };

	string text = "class A { void f () {} }\n";
	int read_calls = 0;
	Input input = {
		(byte_index, position) => {
			read_calls++;
			if (byte_index >= text.length) {
				return null;
			}
			return text.data[byte_index:text.length];
		},
		InputEncoding.UTF8,
		null
	};
	TreeSitter.Tree? tree = parser.parse (input);
	assert (tree != null);
	assert (read_calls > 0);
	assert (!tree.root_node ().has_error);

	// The progress callback is only polled periodically, so use a larger input.
	var big = new StringBuilder ();
	for (int i = 0; i < 200; i++) {
		big.append_printf ("class C%d { void f () {} }\n", i);
	}
	text = big.str;
	ParseOptions options = { null, cancel_immediately };
	assert (parser.parse_with_options (input, options) == null);
	parser.reset ();
}

void test_query () {
	var parser = create_parser ();

	unowned Language language = vala_language ();
	uint32 error_offset;
	QueryError error_type;
	Query? query = Query.create (language, "(class_declaration (unqualified_type) @name) @class", out error_offset, out error_type);
	assert (query != null);
	assert (error_type == QueryError.NONE);
	assert (query.pattern_count () == 1);
	assert (query.capture_count () == 2);
	assert (query.capture_name_for_id (0) == "name");
	assert (query.capture_name_for_id (1) == "class");

	Query? bad = Query.create (language, "(not_a_node)", out error_offset, out error_type);
	assert (bad == null);
	assert (error_type == QueryError.NODE_TYPE);

	TreeSitter.Tree tree = parser.parse_string ("class A {}\nclass B {}\n");
	var cursor = new QueryCursor ();
	QueryCursorOptions options = {};
	cursor.exec_with_options (query, tree.root_node (), options);
	int matches = 0;
	QueryMatch match;
	while (cursor.next_match (out match)) {
		matches++;
		assert (match.captures.length == 2);
	}
	assert (matches == 2);

	query.disable_capture ("class");
	assert (query.capture_count () == 2);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/tree_sitter/language", test_language);
	Test.add_func ("/tree_sitter/parser/string_and_bytes", test_parse_string_and_bytes);
	Test.add_func ("/tree_sitter/node/properties", test_node_properties);
	Test.add_func ("/tree_sitter/tree_cursor", test_tree_cursor);
	Test.add_func ("/tree_sitter/edits", test_edits);
	Test.add_func ("/tree_sitter/callbacks", test_callbacks);
	Test.add_func ("/tree_sitter/query", test_query);

	return Test.run ();
}
