# Edges

The edges are where a path leaves Ceedling's own model, for a shell, a tool, the linker, a plugin or a task. The same rules hold there. Configuration expands Ruby once, on text the author wrote, and warns at load on a shell operator. `Collectinator` builds every root list and collection once per build, at that build's collection point. `CommandLineBuildinator` turns a tool template and its values into a command line, and the template owns quoting. `Linkinator` gives each link its inputs and each test run its loader path. Plugins read the build plan and call core components, and `CoverageScopinator` tells the coverage plugins which sources a report covers. `TestSelectinator` picks the tests a selection task runs.

## Contents

- [Configuration intake](#configuration-intake) covers Ruby expansion and the shell-operator check, the two checks on text the author wrote.
- [Collectinator](#collectinator) covers the collection point, roots and plugin entries.
- [Command lines](#command-lines) covers `CommandLineBuildinator`: templates, substitution, quoting and the Windows executable.
- [The link](#the-link) covers `Linkinator`: library entries, library files, link arguments and test runs.
- [Plugins](#plugins) covers plugin reads, plugin compiles, coverage scope (`CoverageScopinator`), the compilation database and the Dependencies plugin.
- [Tasks](#tasks) covers test selection (`TestSelectinator`) and task arguments.
- [The launcher](#the-launcher) covers the paths the launcher reads before configuration loads.
- [Windows](#windows) gathers the Windows rules and where each is described.
- [Code](#code) lists the files and the interfaces.

## Configuration intake

Configuration reads each path setting once, as written. Ruby expansion and the shell-operator check run on that text. Intake then makes each path a `PathRef`, as [PATHS.md](PATHS.md#intake) says. Roots and collections wait for the collection point.

### Ruby expansion

`RubyExpandinator` evaluates `#{…}` only in text the author wrote, and only once per value.

- **Configuration values.** Each path setting, `:environment` value and plugin load path expands once, at load.
- **Tool templates.** A tool's `:executable` and `:arguments` expand once, when the tool first builds a command line and before any value is substituted. So a template sees every constant Ceedling defines.
- **Never a value.** A value substituted into a template, such as a path from a collection, a glob or the build plan, is never expanded. A file named `a#{x}.c` compiles under its own name.
- **The gate.** `--ruby-replacement` enables Ruby expansion. With it off, configuration text that holds `#{` fails at load and names the setting. An escaped `\#{` is plain text either way, and loses its backslash.
- **Validation.** A `#{` with no closing `}`, a Ruby syntax error and an exception the code raises each fail with one message. It names the setting, quotes the segment and gives Ruby's own message. No Ruby backtrace reaches the user.
- **Quoting** inside a Ruby expansion is the author's.

### Shell operators

Ceedling escapes no path for a shell. A path that holds a shell operator is outside what Ceedling supports, so configuration warns about it at load.

- **What is checked.** Each `:paths` and `:files` entry as written, plugin entries included, and the build root, `:cmock` ↳ `:mock_path`, `:release_build` ↳ `:output` and the project root. A file name a glob matches is not checked.
- **The operators.** Every template double-quotes each path, so the operators are the characters a shell still reads inside double quotes.

| Host shell | Operators | Why |
| --- | --- | --- |
| `/bin/sh`, on Linux and macOS | `$`, `` ` ``, `"`, `\` | `$` and `` ` `` expand, `"` ends the argument, and `\` escapes the next character |
| `cmd.exe` and direct spawn, on Windows | `%`, `"` | `%` hands the line to `cmd.exe`, which expands `%NAME%` inside quotes. `"` ends the argument |

- **Never counted.** Glob syntax, text inside a Ruby expansion, and `\` in a configuration path on every platform, since intake makes it a separator there, as [PATHS.md](PATHS.md#intake) says. So `\` counts on Linux and macOS only in a setting intake doesn't convert, such as the project root's own spelling. `&`, `|`, `^`, `!`, `'` and spaces are plain text inside quotes on every platform.
- **The warning.** Once per entry, at COMPLAIN, which carries a WARNING label. It names the setting, the entry and the operator, and says that the path is unsupported and gives unpredictable results. A setting with one value, such as the build root, warns once.
- **Errors first.** A setting that fails at load for its double quote, as the project root and the build root do, draws its error alone and no warning, as [PLACEMENT.md](PLACEMENT.md#pinned-includes) says.

## Collectinator

`Collectinator` builds every root list, collection and `CollectionIndex` once per build, at that build's collection point, and freezes them. Every reader in a build takes the same lists: the search orders, `-L`, lookups, coverage and plugins.

### The collection point

- **Once per build.** A run holds a collection point for the test family's tasks, such as test, gcov, Bullseye, sanitize and valgrind, which share it. It comes the first time one of them reads a root list or a collection. The release has its own, the first time it reads one. Every other task that reads a collection, such as a listing task or cppcheck, shares the test family's.
- **Before it.** Rake runs a task's prerequisite tasks first, such as a Dependencies fetch and build. A task that Rake matches by a rule, such as `test:<name>` or `release:compile:<file>`, runs `:prepare` in the rule's lookup step before it reads a collection, so its fetch comes first too. Every `:pre_build` and `:pre_test_build` hook fires before the test family's collection point, and the release's `:pre_release_build` hooks fire before its own. A file any of them writes into a root is collected like any other, so `ceedling test:all release` collects what the release's hooks write.
- **What.** Glob expansion of every entry, the case probe for each root, each collection and its index, and the implicit roots. At the run's first collection point, `Placeinator` forms its table of shortened bases from the bases there, as [PLACEMENT.md](PLACEMENT.md#shortened-bases) says. The table depends only on the bases' spellings, so a later collection point reuses it.
- **Test files.** A test file is in no other collection. `Collectinator` removes each file of the test collection from the source collection and the release inputs, by key. It logs the overlap once at COMPLAIN with a WARNING label, naming the entries that reach the test files.
- **Frozen.** After a build's point, no code adds to or removes from that build's root lists or collections. A file a later stage writes is a generated file, which the build plan places.
- **Listing tasks**, such as `files:header` and `paths:include`, reach the test family's point with nothing before it.
- **Hooks.** A hook that fires before the point receives no collection.

### Roots

- **One list per kind**: test, source, include, support and library roots, and one for each other `:paths` key, such as `:test_toolchain_include` or a plugin's own key.
- **Glob expansion** follows `paths.md`. A glob yields each existing directory it matches, in expansion order. A glob whose base does not exist yields no root, and neither does a missing directory. Each such entry logs once at COMPLAIN, which carries a WARNING label, naming the setting and the entry, since the check comes after every fetch and hook that could create it.
- **The build root.** A directory Ceedling creates below the build root, or one a Ceedling setting names for generated files, such as `:cmock` ↳ `:mock_path`, is no root of any kind. An entry that names another directory below the build root collects, with a COMPLAIN WARNING that names the entry, as `paths.md` documents. A directory an external dependency's fetch creates can be a root.

### Plugin entries

A plugin adds paths only as entries, through configuration: its own configuration file or its configuration step at load.

- **Rules.** Plugin entries join `:paths`, `:files` and `:libraries` before the collection point, and follow every rule a user's entries follow.
- **Contributors.** Each entry records the plugin that contributed it. Coverage scope leaves out a plugin's sources by it, and a message can name where an entry came from.
- **Never a list.** No plugin writes a root list, a collection or a value built from one.

The Dependencies plugin adds each external dependency's entries this way. Its `:source` directory joins `:paths` ↳ `:source` and `:paths` ↳ `:include`, so its sources reach the release and its headers every compile. Its `:includes` entries join `:paths` ↳ `:include`, and a glob among them expands after the fetch, at the collection point.

## Command lines

`CommandLineBuildinator` turns a tool template and its values into the command line that one tool run hands to the host shell. `ToolExecutor` runs that line.

### Templates

- **Frozen.** A tool template is a tool's `:executable` and `:arguments` as configured. Configuration freezes it, and building a line never changes it.
- **Expansion.** Each template expands Ruby once, before substitution, as [Ruby expansion](#ruby-expansion) says.
- **Escapes.** A template's `\$` becomes `$` and its `\${n}` becomes the text `${n}`, once, in the template alone.

### Substitution

- **Literal values.** A `${n}` placeholder takes its value as literal text. No value is expanded, unescaped or read as a replacement pattern, so `\0`, `\&`, `\\`, `\$` and `#{` stay as they are.
- **Lists.** A list value gives one copy of the placeholder's argument per item, joined by spaces. An empty list drops the argument.
- **Hash arguments.** An argument such as `{"-I\"$\"" => 'COLLECTION_PATHS_INCLUDE'}` substitutes each item of the named list into its key, in the same way. The key's escapes apply once, before any item.
- **Spelling.** A `PathRef` enters as its project-relative spelling. A path with no relative form, such as one on another Windows drive, enters as its absolute spelling.

### Quoting

- **The template owns it.** Every default template quotes each placeholder that receives a path, as in `-I"${5}"` and `"${1}"`, the test linker's objects included. Callers pass values bare.
- **Validation.** For each tool whose placeholders the tools reference documents, ToolValidator logs a COMPLAIN NOTICE for a path placeholder outside quotes, since a path that holds a space then splits.
- **The executable** is the author's to quote. ToolValidator refuses an unquoted space in it.
- **No escapes.** Quoting never escapes a value. A value that holds a shell operator gives unpredictable results, as [Shell operators](#shell-operators) says.

### The Windows executable

- **Arguments keep `/`.** MinGW GCC, clang and MSVC's `cl` and `link` all read `/` in every path argument.
- **The executable takes `\`.** Ruby hands a line to `cmd.exe` when it holds `%` or an unquoted `&`, `|` or `>`, and `cmd.exe` reads a `/` in a command name as a switch.
- **No trailing `\`.** Intake drops a trailing separator, so no quoted path ends in `\`, which the C runtime would read as an escaped quote.

## The link

`Linkinator` gives each link its inputs: the link set's objects, its library arguments and its library search directories. It lists the library files the link depends on, and gives each test run its loader path. `-L` and `-I` read one library root list from `Collectinator`.

### Library entries

Each `:libraries` entry, under `:test`, `:release` or `:system`, is a library name or a library path.

- **A library path** holds a `/` after intake, or starts with `~` or a drive. On Windows a `\` becomes `/` first. It reaches the linker as a plain input, in its project-relative spelling. `./libfoo.a` names a file in the project root.
- **A library name** is every other entry. `:flag` turns it into an argument, `-l${1}` by default. `m`, `:libm.a` and MSVC's `mylib.lib` are names.
- **Symbols.** YAML loads an unquoted `:libm.a` as a Symbol. Intake gives it back its colon.
- **Plugins** publish each library they build as a library path, so a versioned `libv.so.1` links as that file.

### Library files

The library files a link depends on decide relinks, never what links. A library search is the linker's trial of the library roots for a library name, and `Linkinator` follows its shape.

- **A name.** For each library name, the first library root in `-L` order that holds any candidate answers, and every candidate in it counts.
- **Candidates.** `lib<name>` with each library extension: `.a`, `.so`, `.dylib`, `.tbd`, `.dll.a`, `.lib`, `.dll` and `:extension` ↳ `:libraries`. On Windows, `<name>` with `.dll.a`, `.lib` and `.dll` too.
- **An exact name.** `:<file>` joins each library root in order, and the first that holds it answers.
- **Case.** Extensions and names compare by key, so `foo.LIB` counts where its root folds case.
- **A library path** counts as itself, and so does each library file a plugin publishes.
- **No answer.** A name that no library root answers is left to the toolchain's own library search, and lists no library file.

### Link arguments

- **Order.** The link set's objects fill `${1}`. Every library entry fills `${4}` in configured order, a library path as itself and a library name through `:flag`. Each library root fills `${5}` through `:path_flag`.
- **Literal.** `:flag` and `:path_flag` substitute their value literally, as [Substitution](#substitution) says.
- **MSVC.** With MSVC's `link`, a library name needs `:flag: '${1}.lib'` and `:path_flag: '/LIBPATH:"${1}"'`. A library path links as itself.

### Test runs

- **The loader path.** A test executable runs with its library roots, in `-L` order, at the front of the loader path: `PATH` on Windows and `LD_LIBRARY_PATH` on Linux. The directory of each library path and each published library file follows them. The value the environment and `:environment` give comes after.
- **macOS** adds none, since SIP strips `DYLD_LIBRARY_PATH` from the shell that runs the line. A test that loads a `.dylib` outside its own directory needs an rpath in its link flags.
- **The crash report.** A test executable that ends without a result reports its process status. A status the loader gives for a missing shared library names that cause first: `0xC0000135` on Windows, or exit status 127 with the loader's message on Linux. Every other crash report lists a missing shared library among its possible causes.

## Plugins

Plugins follow core's rules by calling core, and no plugin holds its own copy of a path rule. [EXTENSIONS.md](EXTENSIONS.md#plugins) covers mock hooks and FFF.

### Plugin reads

- **The build plan.** Generated paths, kinds, link sets and Partial records come from the build plan. Hook arguments come from it too.
- **Conventions.** A plugin calls the core component for a convention: `MockNaminator` for mock names and `PartialModuleMatchinator` for a Partial's module.
- **Objects.** An object's directory comes from its placement, never from a test's name.
- **Partial credit.** A Partial's `#line` directives name its module's source by project-relative spelling, so coverage tools credit the module.

### Plugin compiles

- **Untested sources.** gcov and Bullseye compile an untested source with the configured order, less the `TEST_INCLUDE_PATH()` directories, since no test owns the compile. Support roots and `:test_toolchain_include` reach it as they reach a test's sources.
- **cppcheck** analyzes the source collection file by file, with the same order. `:files` ↳ `:source` additions are analyzed, and subtractions are not.
- `SearchOrderinator` gives each of these runs its order, as [STAGES.md](STAGES.md#stage-search-orders) says.

### Coverage scope

`CoverageScopinator` tells gcov and Bullseye which files a report covers. A file a tool reports enters through `PathRef.of` and is compared by key.

- **In scope**: the user source of each object in the build plan that is a source or a support file.
- **Out of scope**: every test file, every generated file and framework file, by the build plan's kinds, and every source a plugin entry contributed, such as an external dependency's. No filter matches a name, a prefix or a pattern. So `src/community.c`, `src/Mockups/driver.c` and `src/motor_runner.c` stay in scope.
- **Untested sources**: the source collection, less every source a link set holds, less the sources plugin entries contributed.
- **Partials** credit their module's source, from the build plan's Partial records.
- **Tool arguments.** Each tool's exclusion arguments list the out-of-scope files, or the generated roots that hold them, by absolute spelling. None is formed from raw path text.
- **User patterns.** ReportGenerator's `:gcov_exclude` patterns are the user's own, and match each notes file's build path. `Placeinator.unshortened` writes every base marker in that path back first, as [PLACEMENT.md](PLACEMENT.md#shortened-bases) says. So a pattern that names a long base's own directories, such as `Keil_v5/.*`, still excludes the files below it.

### compile_commands.json

The compile_commands_json_db plugin writes a compilation database.

- **One entry per object.** Each compiled object has its own entry, holding its command, directory and input, so each entry replays exactly one compile. Entries follow test collection order, then each further context in turn. A tool that takes a file's first entry gets the first test's.
- **Delta builds.** A build replaces the entries of the objects it compiles. It drops an entry whose object no test plans, by the ownership ledger.
- **Isolation copies.** An object compiled from an isolation copy names its origin as its file, with the copy's path replaced by the origin's in the command. A replay of that entry can resolve a quoted include in the origin's own directory, where the compile reached the test's substitute.

### Dependencies

The Dependencies plugin fetches, builds and links external dependencies.

- **Working paths.** Each one falls back as its docs say. `:fetch` falls back to `:source`, `:source` to `:fetch`, `:build` to `:source` and then `:fetch`, and `:artifact` to `:build`. With none set, each is `dependencies/<task name>`.
- **Cleaning** removes each working path after its fallbacks, except `:deploy`. An external dependency fetched by `:none` loses only its artifact path, never its source, and one with no fetch settings keeps every path.
- **Missing artifacts.** When an artifact is missing at its path after the build, and `dependencies/<task name>` holds it, the build stops and names `:artifact` as the fix.
- **Entries.** Its directories and sources join configuration as [plugin entries](#plugin-entries). Each built library's directory joins `:paths` ↳ `:libraries` as a plugin entry, so it reaches `-L`, `-I` and the loader path. The library itself links as a library path, as [Library entries](#library-entries) says.
- **`:build_lib`** compiles an external dependency's sources with its include roots in configured order, each glob in its expansion order.
- **Coverage.** Its sources are out of coverage scope.

## Tasks

### Test selection

`TestSelectinator` gives the tests a selection task runs. Core's `test:path` and `test:pattern` call it, and so does each plugin's copy, in gcov, Bullseye, sanitize and valgrind.

- **By path.** A test is selected when the project-relative spelling of its directory holds the argument's segments as one unbroken run, by `Matchinator.segment_run?`. `unit`, `test/unit`, `./test/unit` and `test/unit/` all select `test/unit/test_a.c`, and none selects `test/unit_extra/test_b.c`. An absolute or climbing argument enters by `PathRef.of` from the project root, and selects each test that lies below it, by `Matchinator.contains?`.
- **By pattern.** A test is selected when the argument, as a Ruby regular expression, matches the test's project-relative spelling.
- **A missing argument** fails with one message that names the task's form, such as `test:path[test/unit]`.
- **No match** logs the argument at ERRORS and runs nothing.

Tasks that take a file name look it up as [LOOKUP.md](LOOKUP.md#task-arguments) says.

### Task arguments

- **As typed.** The launcher doubles each `\` in a task's bracketed arguments, except one before a comma, before Rake reads them. Rake's unescaping then hands the task its argument as typed, so `test:path[test\unit]` and `test:pattern[\.c$]` arrive intact. A `\,` still escapes a comma.
- **Separators.** On Windows a path argument's `\` becomes `/` at intake, as for every path.

## The launcher

The launcher reads paths before configuration loads. Every one enters by `PathRef.of` from the project root, the directory the launcher starts in, as [PATHS.md](PATHS.md#intake) says: `--project`, `CEEDLING_PROJECT_FILE`, `--logfile`, `--mixin`, mixin load paths and `:which_ceedling`.

- **`~user`** names a directory of that name in the project root, on every platform. `~` and `~/` name the home directory.
- **Mixins** deduplicate by key, so one file reached by two spellings merges once. Each mixin's key takes its directory's case finding, which `PathRef` probes on first need, since the collection point comes later, as [PATHS.md](PATHS.md#the-case-rule) says.
- **Order.** Project discovery, the mixin load-path order and installation selection keep their documented order. `gem`, in any case, names the running launcher.
- **Components.** The launcher uses `PathRef` and `Matchinator` alone, since neither needs a DIY object or configuration.

## Windows

The Windows rules, each where it is described:

- **Separators.** Intake makes `\` a `/` in every path, include text, line markers and dependency files included. See [PATHS.md](PATHS.md#intake).
- **`..`.** The file system collapses `..` as text, across a symlink or junction too. See [PATHS.md](PATHS.md#the--rule).
- **Command lines.** Arguments keep `/`, and only the executable takes `\`. See [The Windows executable](#the-windows-executable).
- **Operators.** `%` and `"`. See [Shell operators](#shell-operators).
- **Drives.** A path on another drive keeps its absolute spelling, and its build subpath carries a drive marker. See [PATHS.md](PATHS.md#spellings) and [PLACEMENT.md](PLACEMENT.md#each-kinds-place).
- **Case.** The case probe decides each root's rule. See [PATHS.md](PATHS.md#the-case-rule).
- **Path length.** Shortened bases keep build paths short, and every placement is checked against the limit. See [PLACEMENT.md](PLACEMENT.md#shortened-bases) and [PLACEMENT.md](PLACEMENT.md#path-length).
- **DLLs.** The loader path is `PATH`, and the candidates include `.dll`. See [Test runs](#test-runs) and [Library files](#library-files).

## Code

- `lib/ceedling/paths/collectinator.rb` holds `Collectinator`, a DIY object. `roots( kind )`, `collection( kind )` and `index( kind )` build everything on the first call and return frozen values. `contributor( entry )` names a plugin entry's plugin.
- `lib/ceedling/tools/command_line_buildinator.rb` holds `CommandLineBuildinator`, a DIY object. `build( tool, *values )` returns the command line and the executable. `ToolExecutor` runs it.
- `lib/ceedling/tools/shell_quoting.rb` gains `ShellQuoting.operators( text, windows: )`, which skips Ruby expansions as `unclosed` does.
- `lib/ceedling/ruby_expandinator.rb` holds `RubyExpandinator`. `expand( text, source: )` validates before it evaluates.
- `lib/ceedling/paths/linkinator.rb` holds `Linkinator`, a DIY object. `arguments( link )`, `library_files( link )` and `loader_path( test )` give each part above.
- `lib/ceedling/paths/coverage_scopinator.rb` holds `CoverageScopinator`, a DIY object. `in_scope?( path )`, `untested` and `credit( partial )` read the build plan and the collections.
- `lib/ceedling/paths/test_selectinator.rb` holds `TestSelectinator`, a DIY object. `by_path( text )` and `by_pattern( text )` return tests in collection order, or raise with the message above.
- Specs: `spec/units/paths/<file>_spec.rb` and `spec/units/tools/<file>_spec.rb` for each file. Contract rows of area `LINK` check link sets and library files in real builds.
