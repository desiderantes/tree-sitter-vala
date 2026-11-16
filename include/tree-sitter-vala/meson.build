# Stage tree_sitter internal headers under <builddir>/include/tree-sitter-vala/
# so builds/tests/installs resolve #include <tree-sitter-vala/*.h> while keeping
# tree_sitter/ private.
if has_pregenerated_parser
    staged_headers = [
        configure_file(
            input: '../../src/tree_sitter/parser.h',
            output: 'parser.h',
            copy: true,
            install: not meson.is_subproject(),
            install_dir: get_option('includedir') / 'tree-sitter-vala',
        ),
        configure_file(
            input: '../../src/tree_sitter/alloc.h',
            output: 'alloc.h',
            copy: true,
            install: not meson.is_subproject(),
            install_dir: get_option('includedir') / 'tree-sitter-vala',
        ),
        configure_file(
            input: '../../src/tree_sitter/array.h',
            output: 'array.h',
            copy: true,
            install: not meson.is_subproject(),
            install_dir: get_option('includedir') / 'tree-sitter-vala',
        ),
    ]
else
    staged_headers = custom_target(
        'stage-tree-sitter-headers',
        depends: ts_gen,
        input: ts_gen[0],
        output: ['parser.h', 'alloc.h', 'array.h'],
        command: [
            sh_bin,
            '-c',
            'cp -f "$1/tree_sitter/parser.h" "$1/tree_sitter/alloc.h" "$1/tree_sitter/array.h" "$2/"',
            'sh',
            meson.project_build_root(),
            '@OUTDIR@',
        ],
        install: not meson.is_subproject(),
        install_dir: get_option('includedir') / 'tree-sitter-vala',
    )
endif
