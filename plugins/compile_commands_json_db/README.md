# Ceedling Plugin: JSON Compilation Database

Language Server Protocol (LSP) support for Clang tooling.

# Background

Syntax highlighting and code completion are hard. Historically each editor or IDE has implemented their own and then competed amongst themselves to offer the best experience for developers. Good syntax highlighting can be so valuable as to outweigh the consideration of alternate editors. If implementing sytnax highlighting and related features in a tool is hard for one language — and it is — imagine doing it for dozens of them. Further, on the flip side, imagine the complexities involved for a developer working with multiple languages at once.

In June of 2016, Microsoft with Red Hat and Codenvy got together to create the [Language Server Protocol (LSP)][lsp-microsoft] ([community site][lsp-community]). The idea was simple. By standardizing, any conforming IDE or editor would only need to support LSP instead of custom plugins for each language. In turn, the backend code that performs syntax highlighting and similar features can be written once and used by any IDE that supports LSP. Today, [Many editors support LSP][lsp-tools].

[lsp-microsoft]: https://microsoft.github.io/language-server-protocol/
[lsp-community]: https://langserver.org/
[lsp-tools]: https://microsoft.github.io/language-server-protocol/implementors/tools/

# Plugin Overview

For C and C++ projects, perhaps the most popular LSP server is the [`clangd`][clangd] backend. In order to provide features like _go to definition_, `clangd` needs to understand how to build a project so that it can discover all the pieces to the puzzle. Because of the various flavors of builds Ceedling supports and especially because of the complexities of test suite builds, components of a build can easily go missing from the view of `clangd`.

This plugin gives `clangd` — or any tool that understands a [JSON compilation database][json-compilation-database] — full visibility into a Ceedling build.

Once enabled, this plugin generates the database as `<build root>/artifacts/compile_commands.json` for each new build. Tools that understand JSON Compilation Database files can then process it to make their features fully available to you.

[clangd]: https://clangd.llvm.org
[json-compilation-database]: https://clang.llvm.org/docs/JSONCompilationDatabase.html

# Setup

Enable the plugin in your Ceedling project file by adding `compile_commands_json_db` to the list of enabled plugins.

``` YAML
:plugins:
  :enabled:
    - compile_commands_json_db
```

# Configuration

There is no additional configuration necessary to run this plugin.

`clangd` will search your build directory for the JSON compilation database, but in some instances on Unix-asbed platforms it can be easier and necessary to symlink the file into the root directory of your project (e.g. `ln -s ./build/artifacts/compile_commands.json .`).
