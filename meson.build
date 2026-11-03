project(
    'tree-sitter-vala',
    ['c', 'vala'],
    version: '0.54.0',
    license: 'LGPL-2.1-only',
    meson_version: '>= 1.10.0',
    default_options: ['c_std=c99'],
)

pkgconfig = import('pkgconfig')
valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-2.0')

tree_sitter_dep = dependency('tree-sitter')
tree_sitter_lib = cc.find_library('tree-sitter')
tree_sitter_bin = find_program('tree-sitter', required: false)
grammar_file = files('grammar.js')
if tree_sitter_bin.found()
    run_target(
        'generate',
        command: [
            tree_sitter_bin,
            'generate',
            '--abi',
            '15',
            '-o',
            meson.current_source_dir() / 'src',
            grammar_file,
        ],
    )
endif

inc = include_directories('src')
vapi_dir = meson.current_source_dir() / 'vapi'

tree_sitter_vala_lib = library(
    'tree-sitter-vala',
    'src/parser.c',
    include_directories: inc,
    dependencies: tree_sitter_dep,
    install: not meson.is_subproject(),
)

tree_sitter_vapi = valac.find_library('tree-sitter', dirs: vapi_dir)
tree_sitter_vala_vapi = valac.find_library('tree-sitter-vala', dirs: vapi_dir)

tree_sitter_vala_dep = declare_dependency(
    link_with: tree_sitter_vala_lib,
    include_directories: inc,
    dependencies: [tree_sitter_lib, tree_sitter_vapi, tree_sitter_vala_vapi],
)

meson.override_dependency('tree-sitter-vala', tree_sitter_vala_dep)

if not meson.is_subproject()
    install_headers(
        'src/tree-sitter-vala/tree-sitter-vala.h',
        'src/tree_sitter/parser.h',
        'src/tree_sitter/alloc.h',
        'src/tree_sitter/array.h',
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
        subdirs: 'tree-sitter-vala',
        requires: ['tree-sitter'],
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

        test(
            'corpus',
            tree_sitter_bin,
            args: [
                'test',
                '--lib-path',
                tree_sitter_vala_lib.full_path(),
                '--lang-name',
                'vala',
            ],
            workdir: meson.current_source_dir(),
            suite: 'grammar',
            depends: [tree_sitter_vala_lib, corpus_stamp],
        )
    endif
endif
