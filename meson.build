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

tree_sitter_dep = dependency('tree-sitter')
tree_sitter_lib = cc.find_library('tree-sitter')

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
    install_headers('src/tree_sitter/parser.h', subdir: 'tree_sitter')

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

if get_option('tests')
    glib_dep = dependency('glib-2.0')

    tree_sitter_vala_vapi_test = executable(
        'tree-sitter-vala-vapi-test',
        'test/vapi.vala',
        dependencies: [tree_sitter_vala_dep, glib_dep],
    )

    test('vapi', tree_sitter_vala_vapi_test, protocol: 'tap')

    tree_sitter_bin = find_program('tree-sitter', required: false)
    if tree_sitter_bin.found()
        test(
            'corpus',
            tree_sitter_bin,
            args: ['test'],
            workdir: meson.current_source_dir(),
        )
    endif
endif
