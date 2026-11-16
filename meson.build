project(
    'tree-sitter-vala',
    ['c', 'vala'],
    version: '0.54.0',
    license: 'LGPL-2.1-only',
    meson_version: '>= 1.10.0',
    default_options: ['c_std=c99'],
)

fs = import('fs')
pkgconfig = import('pkgconfig')
valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')
sh_bin = find_program('sh')

glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-2.0')

tree_sitter_dep = dependency('tree-sitter')
tree_sitter_lib = cc.find_library('tree-sitter')
grammar_file = files('grammar.js')

public_inc = include_directories('include')
vapi_dir = meson.current_source_dir() / 'vapi'

has_pregenerated_parser = fs.exists('src/parser.c')
if has_pregenerated_parser
    parser_sources = files('src/parser.c')
    private_inc = include_directories('src', 'include')
    tree_sitter_bin = find_program('tree-sitter', required: false)
    active_src_dir = meson.current_source_dir() / 'src'
else
    tree_sitter_bin = find_program('tree-sitter', required: true)
    ts_gen = custom_target(
        'generate-parser',
        input: [grammar_file, files('tree-sitter.json')],
        output: ['parser.c', 'grammar.json', 'node-types.json'],
        command: [
            sh_bin,
            '-c',
            'outdir=$(cd "$1" && pwd) && grammar=$(cd "$(dirname "$2")" && pwd)/$(basename "$2") && cd "$3" && exec "$4" generate --abi 15 -o "$outdir" "$grammar"',
            'sh',
            '@OUTDIR@',
            '@INPUT0@',
            meson.current_source_dir(),
            tree_sitter_bin,
        ],
    )
    parser_sources = ts_gen[0]
    private_inc = include_directories('.', 'include')
    active_src_dir = meson.current_build_dir()
endif

subdir('include/tree-sitter-vala')

tree_sitter_vala_lib = library(
    'tree-sitter-vala',
    parser_sources,
    include_directories: private_inc,
    dependencies: tree_sitter_dep,
    install: not meson.is_subproject(),
)

tree_sitter_vapi = valac.find_library('tree-sitter', dirs: vapi_dir)
tree_sitter_vala_vapi = valac.find_library('tree-sitter-vala', dirs: vapi_dir)

tree_sitter_vala_dep = declare_dependency(
    link_with: tree_sitter_vala_lib,
    sources: staged_headers,
    include_directories: public_inc,
    dependencies: [tree_sitter_lib, tree_sitter_vapi, tree_sitter_vala_vapi],
)

meson.override_dependency('tree-sitter-vala', tree_sitter_vala_dep)

if not meson.is_subproject()
    install_headers(
        'include/tree-sitter-vala/tree-sitter-vala.h',
        subdir: 'tree-sitter-vala',
    )

    install_data(
        'vapi/tree-sitter.vapi',
        'vapi/tree-sitter-vala.vapi',
        install_dir: get_option('datadir') / 'vala' / 'vapi',
    )

    pkgconfig.generate(
        tree_sitter_vala_lib,
        name: 'tree-sitter-vala',
        filebase: 'tree-sitter-vala',
        description: 'Vala grammar for tree-sitter',
        requires: ['tree-sitter'],
    )
endif

if tree_sitter_bin.found()
    meson.add_dist_script(
        sh_bin,
        '-c',
        'cd "$MESON_PROJECT_DIST_ROOT" && exec "$1" generate --abi 15 -o "$MESON_PROJECT_DIST_ROOT/src" "$MESON_PROJECT_DIST_ROOT/grammar.js"',
        'sh',
        tree_sitter_bin,
    )
endif

if get_option('tests')

    tree_sitter_vala_vapi_test = executable(
        'tree-sitter-vala-vapi-test',
        'test/vapi.vala',
        dependencies: [tree_sitter_vala_dep, glib_dep],
    )

    test(
        'vapi-usage',
        tree_sitter_vala_vapi_test,
        protocol: 'tap',
        suite: 'vapi',
    )

    tree_sitter_vala_codebase_test = executable(
        'tree-sitter-vala-codebase-test',
        'test/codebase-test.vala',
        dependencies: [tree_sitter_vala_dep, glib_dep, gio_dep],
    )

    test(
        'codebase',
        tree_sitter_vala_codebase_test,
        suite: 'library',
    )

    if tree_sitter_bin.found()
        corpus_files = files(
            'test/corpus/attributes.txt',
            'test/corpus/expressions.txt',
            'test/corpus/methods.txt',
            'test/corpus/namespaces.txt',
            'test/corpus/preprocessor.txt',
            'test/corpus/strings.txt',
            'test/corpus/using-directives.txt',
        )

        corpus_stamp = custom_target(
            'corpus-stamp',
            input: corpus_files,
            output: 'corpus.stamp',
            command: [find_program('touch'), '@OUTPUT@'],
            build_by_default: false,
        )

        corpus_test_dir = meson.current_build_dir() / 'corpus-test'

        test(
            'corpus',
            sh_bin,
            args: [
                '-c',
                'mkdir -p "$1/.cache" && ln -sfn "$2" "$1/test" && ln -sfn "$3" "$1/tree-sitter.json" && ln -sfn "$4" "$1/src" && cd "$1" && XDG_CACHE_HOME="$1/.cache" exec "$5" test --lib-path "$6" --lang-name vala',
                'sh',
                corpus_test_dir,
                meson.current_source_dir() / 'test',
                meson.current_source_dir() / 'tree-sitter.json',
                active_src_dir,
                tree_sitter_bin,
                tree_sitter_vala_lib.full_path(),
            ],
            suite: 'grammar',
            depends: [tree_sitter_vala_lib, corpus_stamp],
        )
    endif
endif
