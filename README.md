# tree-sitter-vala

A Tree-sitter grammar and Vala integration library for
the [Vala programming language](https://wiki.gnome.org/Projects/Vala).

This repository provides:

- **Tree-sitter Grammar for Vala**: Accurate grammar definitions and generated parser for syntax highlighting, code
  navigation, and AST tooling.
- **Tree-sitter VAPI Bindings**: A comprehensive VAPI (`vapi/tree-sitter.vapi`) that exposes the Tree-sitter C API
  directly to Vala code with idiomatic types and memory safety.
- **Compiled Vala Library (`libtree-sitter-vala`)**: A Meson-packaged shared library and VAPI
  (`vapi/tree-sitter-vala.vapi`) making the compiled Tree-sitter Vala parser immediately callable and ready to use in
  any Vala application or library (such as formatters, language servers, or linters).

---

## Building and Installing

This project uses the Meson build system.

### Dependencies

- `meson` (>= 1.10.0) & `ninja`
- `valac`
- `tree-sitter` (>= 0.25.0)
- `glib-2.0`
- `gio-2.0`

### Build

```bash
meson setup build -Dtests=true
ninja -C build
```

### Run Tests

```bash
meson test -C build --verbose
```

### Installation

```bash
sudo ninja -C build install
```

When installed, `tree-sitter-vala.pc` and both VAPI files (`tree-sitter.vapi`, `tree-sitter-vala.vapi`) are installed
into system paths for easy consumption via `pkg-config --pkg tree-sitter-vala`.

---

## Validating Against Real-World Codebases

To track coverage and ensure the grammar reliably parses real-world Vala code in the wild, the project includes a
dedicated validation tool (`tree-sitter-vala-codebase-test`).

This tool recursively traverses any Vala codebase, parses every source file using `libtree-sitter-vala`, collects
pass/fail metrics, and outputs exact error locations and snippets for files that encounter syntax errors:

```bash
# Validate against any local repository or directory
./build/tree-sitter-vala-codebase-test \
  --codebase /path/to/any-vala-project \
  --log-file build/failures.md \
  --exclude "build/*" \
  --exclude "subprojects/*"
```

Parameters:

- `--codebase <path>`: Target codebase directory to scan and validate.
- `--exclude <pattern>` (or `-e`): Exclude paths matching a GLib glob pattern (e.g. `"build/*"`). Can be specified multiple times.
- `--expect-fail <pattern>` (or `--negative`, `-x`): Specify patterns for negative test files that are expected to contain syntax errors. If any file matching this pattern parses without syntax errors, it is flagged as an unexpected success (guarding against an overly lenient grammar).
- `--log-file <path>`: Output detailed Markdown log of all parse errors with line numbers and source snippets.
- `--summary`: Output a Markdown summary to `$GITHUB_STEP_SUMMARY` in CI environments.

---

## Grammar Development Workflow

1. Edit `grammar.js`
2. Regenerate parser using the Meson target:
   ```bash
   ninja -C build generate
   # or
   meson compile -C build generate
   ```
   *(This automatically executes `tree-sitter generate --abi 15` and refreshes `src/` artifacts.)*
3. Run tests:
   ```bash
   meson test -C build
   ```

You can also use `tree-sitter parse <file>` and `tree-sitter highlight <file>` to inspect syntax trees and token
highlighting directly.

---

## Neovim Integration

For Neovim integration, install this grammar with:

```vim
:TSInstall vala
```

And install the [vala.vim](https://github.com/vala-lang/vala.vim) plugin to recognize the filetype.
For [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'vala-lang/vala.vim'
```

Then run:

```vim
:PlugUpdate
```

---
