namespace TreeSitter {
	[CCode (cname = "tree_sitter_vala", cheader_filename = "tree-sitter-vala/tree-sitter-vala.h")]
	public static unowned ValaLanguage vala_language ();

	[Compact]
	[CCode (cname = "const TSLanguage", has_type_id = false, free_function = "ts_language_delete", cheader_filename = "tree_sitter/parser.h")]
	public class ValaLanguage : Language {
		public uint32 abi_version;
		public uint32 symbol_count;
		public uint32 alias_count;
		public uint32 token_count;
		public uint32 external_token_count;
		public uint32 state_count;
		public uint32 large_state_count;
		public uint32 production_id_count;
		public uint32 field_count;
		public uint16 max_alias_sequence_length;
		[CCode (array_length = false)]
		public unowned uint16[] parse_table;
		[CCode (array_length = false)]
		public unowned uint16[] small_parse_table;
		[CCode (array_length = false)]
		public unowned uint32[] small_parse_table_map;
		[CCode (array_length = false)]
		public unowned string[] symbol_names;
		[CCode (array_length = false)]
		public unowned string[] field_names;
		[CCode (array_length = false)]
		public unowned ParserInternals.MapSlice[] field_map_slices;
		[CCode (array_length = false)]
		public unowned ParserInternals.FieldMapEntry[] field_map_entries;
		[CCode (array_length = false)]
		public unowned ParserInternals.SymbolMetadata[] symbol_metadata;
		[CCode (array_length = false)]
		public unowned Symbol[] public_symbol_map;
		[CCode (array_length = false)]
		public unowned uint16[] alias_map;
		[CCode (array_length = false)]
		public unowned Symbol[] alias_sequences;
		public Symbol keyword_capture_token;
		[CCode (array_length = false)]
		public unowned StateId[] primary_state_ids;
		public unowned string name;
		[CCode (array_length = false)]
		public unowned Symbol[] reserved_words;
		public uint16 max_reserved_word_set_size;
		public uint32 supertype_count;
		[CCode (array_length = false)]
		public unowned Symbol[] supertype_symbols;
		[CCode (array_length = false)]
		public unowned ParserInternals.MapSlice[] supertype_map_slices;
		[CCode (array_length = false)]
		public unowned Symbol[] supertype_map_entries;
		public LanguageMetadata metadata;
	}

	namespace ParserInternals {
		[CCode (cname = "TREE_SITTER_SERIALIZATION_BUFFER_SIZE", cheader_filename = "tree_sitter/parser.h")]
		public const int SERIALIZATION_BUFFER_SIZE;

		[CCode (cname = "ts_builtin_sym_error", cheader_filename = "tree_sitter/parser.h")]
		public const Symbol BUILTIN_SYM_ERROR;

		[CCode (cname = "ts_builtin_sym_end", cheader_filename = "tree_sitter/parser.h")]
		public const Symbol BUILTIN_SYM_END;

		[CCode (cname = "TSFieldMapEntry", has_type_id = false, cheader_filename = "tree_sitter/parser.h")]
		public struct FieldMapEntry {
			public FieldId field_id;
			public uint8 child_index;
			public bool inherited;
		}

		[CCode (cname = "TSMapSlice", has_type_id = false, cheader_filename = "tree_sitter/parser.h")]
		public struct MapSlice {
			public uint16 index;
			public uint16 length;
		}

		[CCode (cname = "TSSymbolMetadata", has_type_id = false, cheader_filename = "tree_sitter/parser.h")]
		public struct SymbolMetadata {
			public bool visible;
			public bool named;
			public bool supertype;
		}

		[CCode (cname = "TSParseActionType", cprefix = "TSParseActionType", has_type_id = false, cheader_filename = "tree_sitter/parser.h")]
		public enum ParseActionType {
			Shift,
			Reduce,
			Accept,
			Recover
		}

		[CCode (cname = "TSCharacterRange", has_type_id = false, cheader_filename = "tree_sitter/parser.h")]
		public struct CharacterRange {
			public int32 start;
			public int32 end;
		}

		[CCode (cname = "TSLexer", has_type_id = false, cheader_filename = "tree_sitter/parser.h")]
		[Compact]
		public class Lexer {
			public int32 lookahead;
			public Symbol result_symbol;
			[CCode (cname = "advance")]
			public unowned AdvanceFunc advance;
			[CCode (cname = "mark_end")]
			public unowned MarkEndFunc mark_end;
			[CCode (cname = "get_column")]
			public unowned GetColumnFunc get_column;
			[CCode (cname = "is_at_included_range_start")]
			public unowned IsAtIncludedRangeStartFunc is_at_included_range_start;
			[CCode (cname = "eof")]
			public unowned EofFunc eof;

			[CCode (has_target = false)]
			public delegate void AdvanceFunc (Lexer lexer, bool skip);
			[CCode (has_target = false)]
			public delegate void MarkEndFunc (Lexer lexer);
			[CCode (has_target = false)]
			public delegate uint32 GetColumnFunc (Lexer lexer);
			[CCode (has_target = false)]
			public delegate bool IsAtIncludedRangeStartFunc (Lexer lexer);
			[CCode (has_target = false)]
			public delegate bool EofFunc (Lexer lexer);
		}

		[CCode (cname = "set_contains", cheader_filename = "tree_sitter/parser.h")]
		public static bool set_contains ([CCode (array_length_pos = 1.1, array_length_type = "uint32_t")] CharacterRange[] ranges, int32 lookahead);
	}

	namespace Allocator {
		[CCode (cname = "ts_malloc", cheader_filename = "tree_sitter/alloc.h")]
		public static void* malloc (size_t size);

		[CCode (cname = "ts_calloc", cheader_filename = "tree_sitter/alloc.h")]
		public static void* calloc (size_t count, size_t size);

		[CCode (cname = "ts_realloc", cheader_filename = "tree_sitter/alloc.h")]
		public static void* realloc (void* ptr, size_t size);

		[CCode (cname = "ts_free", cheader_filename = "tree_sitter/alloc.h")]
		public static void free (void* ptr);
	}
}
