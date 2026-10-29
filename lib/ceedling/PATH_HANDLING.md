# Path Handling

Ceedling spells every path one way, compares places by whole directories, and places every build file by its source's path from the project root. Three guarantees follow. No build file lands outside the build root. No two inputs share one build file. A build file's own path leads back to exactly one input.

This document is for developers and coding agents changing code that reads, compares, collects, or places paths. It begins with orientation and ends with detail. The orientation explains why paths need one spelling, the rules that govern them, the modules involved, and the invariants a change must keep. The later sections trace each rule to its methods, data structures, and specs.

## Orientation

### Why paths need one spelling

A project names one place in many spellings. A `:paths` entry may read `src/**`, `./src/**`, `../app/src/**`, `~/sdk/include`, `C:\Keil_v5\Include`, or a path through a symlink. Collection returns files relative to the working directory. Some lookups use absolute paths.

Comparing these spellings as text gives wrong answers in two ways. Two spellings of one place compare unequal. A text prefix also suggests containment where there is none. The text `..` begins `../../../Keil_v5/Include`, yet that directory lies far outside `..`.

Placement poses a second challenge. Same-named sources live in many directories. Some lie outside the project or on another drive. Each build file needs a place that belongs to its source alone and still lies inside the build root.

### The rules

Five rules govern path handling. Each later section expands one of them.

1. **One spelling.** Intake spells each path once. The spelling is relative to the working directory, with `~` expanded and the symlinks of its existing part resolved. A path with no relative form stays absolute. `ProjectPaths.canonical` produces it.
2. **Containment by directory.** A path lies within a root only when the root is one of its whole ancestor directories. `ProjectPaths.contains?` and `ProjectPaths.subdir_below` answer this. No code asks whether one path's text starts with another's.
3. **Placement by project path.** A build file sits below its build output root at its source's own directory path from the project root. `BuildSubpath.encode` writes that path so it never climbs or goes absolute. `..` becomes `_up_`, another drive goes under `_abs_` or `_unc_`, and Ceedling's own installed files go under `_ceedling_`.
4. **Exact inversion.** `BuildSubpath.decode` turns a build subpath back into the source's path. A lookup from a build file therefore finds its source by exact path before it ever falls back to matching by name.
5. **Collection leaves out the build.** Collection never returns the directories Ceedling creates. A glob based above the build root returns nothing from it. Configuration refuses a build root that holds the project.

### The project root

The project root is the working directory. It is where `ceedling` runs, and every relative path in configuration resolves against it. Mixins also search the project file's directory, but resolved paths are still relative to the working directory. `ProjectPaths.working_dir` is that directory with its symlinks resolved.

### Code organization

The path modules sit at the top of `lib/ceedling/`. Most are pure module functions with no DIY dependency, so the launcher in `bin/` can use them too.

| File | Module or class | Role |
| --- | --- | --- |
| `project_paths.rb` | `ProjectPaths` | Spelling, absolute and relative forms, containment |
| `build_subpath.rb` | `BuildSubpath` | Encoding a directory into a build subpath and back |
| `path_spellings.rb` | `PathSpellings` | A place's listed and real spellings, and distances between places |
| `path_exclusions.rb` | `PathExclusions` | The three kinds of exclusion collection applies |
| `path_mirror.rb` | `PathMirror` | A file's subdirectory below the most specific containing root |
| `path_matcher.rb` | `PathMatcher` | Resolving `..` in a query, and matching trailing segments |
| `destination_collision.rb` | `DestinationCollision` | Stopping a build when two inputs map to one output |
| `file_path_collection_utils.rb` | `FilePathCollectionUtils` | Collecting `:paths` directories and `:files` revisions |
| `file_path_utils.rb` | `FilePathUtils` | Test names and every build file's path |
| `file_finder.rb` | `FileFinder` | Finding a build file's input from the build file's path |
| `config/build_root_policy.rb` | `BuildRootPolicy` | What a build root may be, and what Ceedling creates in it |
| `config/configurator_builder.rb` | `ConfiguratorBuilder` | Building collections with the exclusions applied |
| `test_invoker/mock_locator.rb` | `MockLocator` | Where a mock is generated and how its test reaches it |

### Invariants

Every change to path code must keep these invariants. Specs pin each one.

- A build file lies below the build root. No subpath holds `..` or begins at a filesystem root.
- Two distinct inputs never share one output. `DestinationCollision` stops the build when they would.
- `BuildSubpath.decode( BuildSubpath.encode( dir ) )` returns `dir` in intake's spelling.
- A collection holds each place once, however many entries or spellings reach it.
- `ProjectPaths` and `BuildSubpath` never depend on DIY objects or configuration.
- Comparison folds case on Windows only. Stored spellings never change case.

## Spelling paths: `ProjectPaths`

`ProjectPaths` gives every path one spelling and answers containment between spellings. Its functions are pure over strings except where noted. The ones that read the disk say so.

### Functions

| Function | Result | Reads disk |
| --- | --- | --- |
| `working_dir` | `Dir.pwd` with symlinks resolved, memoized per `Dir.pwd` | Once per directory |
| `standardize(path)` | Trimmed, `/`-separated, no trailing separator, `~` expanded, `+:`/`-:` decorator kept | No |
| `absolute(path)` | Absolute, with `.` and `..` resolved against `working_dir`, drive letter upper case | No |
| `real_absolute(path)` | `absolute` with the symlinks of its longest existing prefix resolved | Yes |
| `canonical(path)` | `relative( real_absolute( path ) )`, the intake spelling | Yes |
| `relative(absolute)` | Relative to `working_dir`, `.` for the directory itself, absolute when no relative form exists | No |
| `contains?(root, path)` | Whether `path` is `root` or lies below it | No |
| `subdir_below(root, path)` | The directories from `root` down to `path`, `''` for `root` itself, nil for outside | No |
| `segments(path)` | Segments split on either separator, `.` and empty segments dropped | No |
| `same?(a, b)`, `starts_with?(path, prefix)` | Text comparison that folds case on Windows | No |

### Standardizing

`standardize` is the first step for any path read from configuration or the command line. It trims whitespace and converts backslashes. It drops trailing separators but keeps a bare root such as `/` or `C:/`. It expands `~` and `~/…` to `Dir.home`, also after a `+:` or `-:` decorator. A `~user` path stays literal and names a directory called `~user`. `FilePathUtils.standardize_in_place` applies it across configuration. `bin/path_validator.rb` applies it in the launcher.

### Absolute form and its memo

`absolute` resolves a path without touching the disk. A path that is already clean and absolute returns unchanged through `clean_absolute?`. Any other result is memoized per `[Dir.pwd, Dir.home, path]` and frozen. A build asks for the same few roots thousands of times, so the memo keeps placement and lookup cheap. A `~user` path is prefixed with `./` before `File.expand_path`, so Ruby never reads it as a user's home.

### Canonical form

`canonical` is the spelling intake records. It resolves symlinks only along the longest existing prefix, through the private `real`. A path that does not exist yet keeps its missing tail as written. Collection resolves each entry's base this way. It never resolves every directory a glob yields, since an `#include` reaches a directory by its listed spelling.

### Containment

`subdir_below` compares absolute forms at a `/` boundary. `src` therefore never contains `src2`. The subdirectory it returns never holds `..` and is never absolute. `PathMirror.containing_subdir` builds on it and picks the shortest subdirectory, which is the most specific containing root.

## Placing build files: `BuildSubpath`

`BuildSubpath` turns a source's directory into the subpath its build files take below a build output root. The subpath is the directory's path from the project root, rewritten so it never climbs and never goes absolute.

### Markers

Four marker segments stand for what a relative path cannot hold.

| Marker | Stands for | Example directory | Encoded subpath |
| --- | --- | --- | --- |
| none | A directory inside the project | `src/drv` | `src/drv` |
| `_up_` | One `..` segment | `../shared/src` | `_up_/shared/src` |
| `_abs_` | A path with no relative form, on another Windows drive | `D:/sdk/inc` | `_abs_/D/sdk/inc` |
| `_unc_` | A Windows UNC share | `//server/share/inc` | `_unc_/server/share/inc` |
| `_ceedling_` | A file of the running Ceedling installation outside the project | `<installation>/plugins/fff/src` | `_ceedling_/plugins/fff/src` |

The project root itself encodes as `''`. Its files sit directly below the output root.

### Choosing a marker

`encode(path)` decides in a fixed order. It first asks whether the path lies outside the working directory by containment. If so and the path lies inside `INSTALLATION_ROOT`, the file is Ceedling's own and goes under `_ceedling_`. `INSTALLATION_ROOT` is the directory two levels above `lib/ceedling/`. If the relative form is still absolute, the path takes `_abs_` or `_unc_`. Otherwise each `..` becomes `_up_`.

`_ceedling_` keeps Ceedling's own files short and stable. A gem installation can sit many directories away from a project. Without the marker its plugin sources would encode as a long chain of `_up_` segments that changes with every install location. A Ceedling copy vendored inside the project lies within the working directory, so it encodes by its ordinary path.

### Escaping a marker-named directory

A real directory named like a marker gains one leading `_`. `MARKER_NAMED` matches `_up_`, `_abs_`, `_unc_`, and `_ceedling_`, already led by any number of `_`, in any case. So `src/_up_/x` encodes as `src/__up_/x`, and `src/__abs_` as `src/___abs_`. `decode` strips one leading `_` from a marker-named segment that begins with `__`. The match ignores case because macOS and Windows file systems fold case, so `_UP_` and `_up_` can name one directory there.

### Decoding

`decode(subpath)` inverts `encode` exactly. A leading `_ceedling_` joins the rest to `INSTALLATION_ROOT` and returns it relative to the working directory. A leading `_unc_` rebuilds `//server/share/…`. A leading `_abs_` rebuilds `D:/…` from its drive segment. Any other subpath maps each `_up_` back to `..` and unescapes the rest.

### Memo

`of_directory(dir)` memoizes `encode` per working directory and directory behind a Mutex. A build places many files from each directory, and build threads share the memo.

## Placement rules: `FilePathUtils`

`FilePathUtils#form_build_subpath(file, generated_roots:)` is the one placement rule. Every object, preprocessed file, dependencies file, and list file takes its subpath from it.

### The rule

The rule has three cases, tried in order.

1. A file below one of the caller's `generated_roots` mirrors below that root. These roots are the test's own mock and Partials directories, from `generated_roots(test)`. A mock's object therefore keeps the mock's own subdirectory.
2. A file elsewhere below the build root lands flat. These are vendored framework sources and runners, which never share a basename within one test.
3. Any other file lands at `BuildSubpath.of_directory( File.dirname( file ) )`.

In test `test/drivers/test_uart`, the source `src/drivers/uart.c` builds to `build/test/out/test/drivers/test_uart/src/drivers/uart.o`. A release builds it to `build/release/out/src/drivers/uart.o`. The source `../shared/crc.c` builds to `…/_up_/shared/crc.o`.

### Forming paths

`build_filepath(file, root:, ext:, generated_roots:)` joins the output root, the subpath, and the basename with the new extension. It checks each formed path's length once through `FileWrapper#check_path_length`. `@formed_paths`, a Set behind `@formed_lock`, remembers which paths were checked.

`mirror_build_objects(files, root:, ext:, generated_roots:)` maps a list of sources at once. It first drops duplicate sources by absolute path, since one file can reach a list under two spellings. It then calls `validate_distinct_build_files!`. That method uses `DestinationCollision.find` and `DestinationCollision.raise_for` to stop the build when two sources would build to one file. The message reads "`a` and `b` would build to the same file `x`. Rename one, or move it to its own directory."

These callers use the rule.

- `form_test_object_filepath` and `form_test_build_objects_filelist` place test objects below `build/test/out/<test name>/`.
- `form_release_build_objects_filelist` and `form_release_dependencies_filelist` place release objects and their `.d` files.
- `form_release_dependencies_filepath` mirrors a release object's own subpath below the release dependencies directory.
- `preprocessed_file_subpath` places preprocessed headers and sources below each test's preprocessing directories.
- The gcov and Bullseye plugins call `form_test_object_filepath` with their own context. Their untested sources land below `build/<plugin>/out/` by the same rule.

### Test names

A test's name is its path from the project root without its extension. `form_test_name(filepath)` is `BuildSubpath.encode( filepath.ext( '' ) )`. The name places the test's build output, results, runner, mocks, preprocessing, and logs. `test/unit/test_foo.c` is named `test/unit/test_foo`. A test at `../tests/test_x.c` is named `_up_/tests/test_x`. `TestBuildValidations` stops the build through `DestinationCollision` when two tests share a name.

### The Dependencies plugin

The Dependencies plugin places objects by a different root. `Dependencies#prepared_object` takes the source's subdirectory below the dependency's own `:source` path through `ProjectPaths.subdir_below`. A dependency builds from its own tree, so its project root is that tree.

## Mocks: `MockLocator`

Mocks keep placement relative to their include root, not the project root. CMock's folder semantics need it. The test's search path `-I build/test/mocks/<test>` must resolve `#include "drv/mock_gpio.h"` as written. A mock's identity, its CMock symbols and runner entries, also comes from that path.

`FileFinder#resolve_mock` finds the mocked header. It then takes the header's subdirectory below the most specific root of `collection_mirror_roots_headers` through `PathMirror.relative_subdir_from_clean_roots`. Containment is by whole directories, so a header outside every root yields `''`. Its mock then lands flat in the test's mock directory.

`MockLocator#placement(mocks_root:, subdir:, include_path:)` returns a `MockPlacement` struct with four fields.

- `folder` is the `#include` text's directory when `:cmock` ↳ `:mock_name_include_folder` is on, otherwise nil.
- `directory` is where the mock's files are generated.
- `root` is the mock path CMock is configured with. CMock writes the mock at `folder` below it, which leads to `directory`.
- `reach` is the search path from which the test's `#include` text reaches `directory`.

An `#include` folder that climbs with `..` needs one more step. `written_spot` places the mock below `mocks_root/_up_/…` and sets `reach` to an anchor of `_up_` segments. The `#include` then climbs from that anchor back down to the mock, and the mock never leaves the test's mock directory. `MockLocator#search_directories` gives the test `[directory, reach].uniq` as search paths. `StandinHeaderinator` creates `reach` when it lies outside `directory`.

## Finding inputs from build files: `FileFinder`

A lookup from a build file inverts placement exactly. It finds the input by path before it matches by name, so a same-named file elsewhere never interferes.

`mirrored_query(filepath, release:, test:, context:)` turns an object path into a source query.

1. A path outside the build root is a source-tree query from an `#include` or `TEST_SOURCE_FILE()`. `header_root_relative_query` handles it.
2. Inside the build root, `placement_root` names the release output root or the test's build path.
3. The subdirectory below that root is decoded by `BuildSubpath.decode` and joined with the basename. The query is marked exact.

`find_compiled_input` tries an exact query first through `exact_file`. `exact_file` builds an index per collection, keyed by `compare_by_identity` and then by absolute path. A tail match by trailing segments follows only when the exact query misses. It also serves a query that is not exact, such as an object below a third-party plugin's build root that placement does not know.

`test_context_of(filepath)` recovers a test name from a path below `build/test/out/`. Objects nest below the name at their own paths, so it returns the longest known test name that the directory begins with.

`header_root_relative_query(filepath)` correlates a header with the source beside it. Headers and sources often sit below different roots, such as `include/` and `src/`. The query is the header's subdirectory below its root in `collection_mirror_roots_include`, so `include/drv/gpio.h` looks for a source whose path ends in `drv/gpio`. `Partializer` uses the same roots for module sources.

## Collecting paths: `FilePathCollectionUtils`

Collection turns `:paths` entries into directories and `:files` revisions into files. Each place is collected once and spelled through its entry's real base. Exclusions are judged by distance between places, never by text.

### Spellings and distance

`PathSpellings` holds the tools collection compares with. `PathSpellings.of(paths)` is the Set of both spellings of each path, absolute and real, as compared. `PathSpellings.key` folds case on Windows only. `PathSpellings.through_real(paths, base)` respells paths found below `base` through `base`'s real path, so a project reached through a symlink never collects one directory twice. `PathSpellings.nearer(spellings, spelled)` walks up from a place and counts the steps to the nearest place in `spelled`. It returns 0 for the place itself and infinity for none.

### Directories from `:paths`

`collect_paths(paths, exclude:, reserved:)` collects directories in three steps.

1. `named_directories` lists every directory each additive entry names. `entry_directories` globs the entry, adds Ceedling's parent directories for a `/**` or `/*` tail, and respells the results through the entry's real base. A bracket in a path is literal, never glob syntax.
2. Each directory becomes a `Named` struct of `spelled`, `spellings`, and `distance`. `distance` is how far below the nearest base of the entries naming it the directory lies. A directory reached by two entries keeps its first spelling and its smallest distance.
3. A `PathExclusions` decides which directories stay. The kept ones return relative to the working directory.

### The three exclusions

`PathExclusions` is a Struct of three spelling sets, built by `PathExclusions.of(minus, excluded, reserved)`. `keeps?(spellings, distance)` keeps a place only if all three tests pass.

| Set | Source | A place stays when |
| --- | --- | --- |
| `minus` | `-:` entries | It lies strictly nearer its entry's base than any `-:` place above it |
| `excluded` | The build root | It lies no farther from its entry's base than the build root above it |
| `reserved` | `BuildRootPolicy.reserved` | No reserved directory lies at or above it |

The `minus` rule lets `+:src/legacy/keep` survive beside `-:src/legacy`, because its own entry names it more closely. The `excluded` rule lets `../**` or `./**` sweep the project without reaching into `build/`. An entry based at or below the build root, such as `build/gen/**`, still collects there. The `reserved` rule has no override, so no entry collects Ceedling's own output.

### Files from `:files`

`revise_filelist(list, revisions, exclude:, reserved:)` adds and removes files. `revision_files` globs each revision and respells it through its real base. `added_files` keeps an additive revision's file only if `PathExclusions#keeps?` passes. The distance is measured from the revision's own base, so `+:**/*.c` adds nothing from `build/`, and `+:build/gen/*.c` adds what it names. `kept_files` then drops duplicates and subtracted files by `real_key`, which compares a file through its directory's real path. The result is a literal FileList, so no entry is read as a glob again.

### Mirror roots

`collect_mirror_roots(entries)` computes the roots that mocks and header lookups measure against, once, at configuration time. It strips a `/**` or `/*` tail, expands a glob in the middle of an entry into one root per directory, and canonicalizes each. `ConfiguratorBuilder#collect_mirror_roots` stores two lists. `collection_mirror_roots_include` comes from `:paths` ↳ `:include`. `collection_mirror_roots_headers` adds `:test` and `:support`.

## The build root: `BuildRootPolicy`

`BuildRootPolicy` says what a build root may be and what in it collection must never return. `clobber` empties the directories Ceedling creates there, so the policy protects the project from them.

- `problem(root)` refuses an empty build root, the project directory, or any directory above it. It compares canonical spellings, so a symlinked spelling of the project is refused too. `ConfiguratorPathsValidator#validate_build_root` logs `message(root, problem)` as an error.
- `entries_within(root, config)` lists each additive `:paths` and `:files` entry whose base lies in the build root. `warnings` turns each into a COMPLAIN message. Such entries collect, but the warning names them.
- `reserved(config)` lists the directories Ceedling creates. It reads the settings in `CREATED`: the artifacts, test, release, vendor, and cache directories, the log path, and the mock path. It adds `<build_root>/<plugin>` for each enabled plugin. An empty setting names nothing, so the project directory is never reserved by accident.

`ConfiguratorBuilder#build_exclusions` passes the build root as `exclude:` and `reserved` as `reserved:` to every `:paths` collection and every `:files` revision. `ConfiguratorBuilder#without_tests` then removes test files from the source collection after revisions, with a warning. It removes them from the release build input without a second warning.

A `-:` entry that matches nothing is never an error. `ConfiguratorPathsValidator#subtracts_nothing` warns of one outside the build root and stays silent below it. Below the build root nothing exists before a first build.

## Other intake points

Several settings reach paths outside `:paths` and `:files`. Each spells its paths through `ProjectPaths` at intake.

- `TestContextExtractor` canonicalizes every `TEST_INCLUDE_PATH()` entry. `IncludePathinator#prioritized_header_files` then ranks headers by walking up each header's directories to the nearest search root, with `rank_key` folding case on Windows.
- `LibraryResolver#search_directories` collects `:paths` ↳ `:libraries` through `collect_paths` and memoizes the result. `search_path_arguments` forms the `-L` arguments from it.
- `ConfiguratorBuilder#set_release_target` standardizes `:release_build` ↳ `:output`. An absolute output names the artifact itself.
- `CliHelper#process_logging_path` applies inline Ruby expansion and `standardize` to the build root before configuration loads. It refuses one that expands to nothing.
- `RakefileComponentResolver.prepare_plugin_load_paths` standardizes `:plugins` ↳ `:load_paths` with the same expander `lib/` uses.
- `DependencySpec` in the Dependencies plugin standardizes each dependency's paths.
- `Setupinator` runs `Configurator#populate_cmock_helpers` after `standardize_paths`, so the Unity helper paths are already standardized.

## Platform differences

Paths behave differently on Windows, macOS, and other POSIX systems. The code handles each difference in one place. `ProjectPaths::WINDOWS` selects the Windows behavior from `RbConfig::CONFIG['host_os']`.

### Windows

- **Case.** Comparison folds case through `same?`, `starts_with?`, `PathSpellings.key`, and `IncludePathinator#rank_key`. Stored spellings keep their case.
- **Drive letters.** `absolute` upper-cases the drive letter. `ROOTED` requires one for a clean absolute path.
- **`_abs_`.** Only Windows produces `_abs_`. A path on another drive has no relative form, and `Pathname#relative_path_from` raises `ArgumentError`. `relative` then returns the absolute path, and `encode` places it under `_abs_/<drive>/…`.
- **UNC shares.** `unc?` is true only on Windows. `unc_absolute` resolves `..` but never climbs above `//server/share`. A share encodes under `_unc_`.
- **Unclean segments.** `File.expand_path` lengthens a short `~1` name and drops a trailing dot or space. `UNCLEAN` therefore treats `~`, a trailing dot, and a trailing space as unclean, so those paths always pass through `File.expand_path`.
- **Path length.** Placement by project path lengthens build paths. A source far from the project gains one `_up_` per climbing level. `build_filepath` checks each path once against the 260-character limit through `FileWrapper#check_path_length`, which warns. `_ceedling_` keeps installed files short.
- **Real-path casing.** Intake takes a path's on-disk casing from `File.realpath`, along the existing part of the path.

### macOS

- **Symlinked temporary directories.** `/tmp` and `/var` are symlinks into `/private`. `working_dir` and `canonical` resolve them, so `/tmp/proj` and `/private/tmp/proj` compare as one place.
- **Case-insensitive volumes.** APFS and HFS+ usually ignore case, but Ceedling compares case exactly outside Windows. Two spellings that differ only by case count as two places. `MARKER_NAMED` ignores case so that `_UP_` is still escaped.

### Linux and other POSIX systems

- **Absolute paths.** Every absolute path has a relative form. A header at `/opt/sdk/inc` encodes as a chain of `_up_` segments followed by `opt/sdk/inc`, never as `_abs_`. The chain grows with the project's depth below `/`.
- **Doubled separators.** A leading `//` is the filesystem root, not a share. `absolute` squeezes it to `/`.

## Changing path code

A change to path code keeps the invariants by following the patterns above. These checks catch the usual mistakes.

- Compare places with `ProjectPaths.contains?` or `subdir_below`. Never compare path text with `start_with?` or `include?`.
- Spell configured paths with `standardize` at intake and `canonical` where a symlinked spelling matters.
- Place build files through `form_build_subpath` or `build_filepath`. Never join a source's directory under a build root directly.
- Run a new list of outputs through `DestinationCollision`.
- Add a marker by updating `MARKER_NAMED`, `encode`, and `decode` together, with a round-trip spec.
- Keep `ProjectPaths`, `BuildSubpath`, `PathSpellings`, and `PathExclusions` free of DIY objects and configuration.

## Specs

Each tier pins a different layer of this design.

- **Unit.** `spec/units/project_paths_spec.rb`, `build_subpath_spec.rb`, `path_mirror_spec.rb`, `path_matcher_spec.rb`, `destination_collision_spec.rb`, `file_path_utils_spec.rb`, `file_path_collection_utils_spec.rb`, `file_finder_spec.rb`, `mock_locator_spec.rb`, `library_resolver_spec.rb`, and `spec/units/config/build_root_policy_spec.rb`. Windows drive and UNC examples run only on Windows.
- **Integration.** `spec/integration/path_scenarios_spec.rb` and `path_intake_scenarios_spec.rb` configure real projects in temporary workspaces through `spec/support/integration/path_scenario_harness.rb`. `expect_collections_outside_build` and `expect_one_spelling_each` assert the invariants.
- **System.** `spec/system/path_handling_probes_spec.rb`, `build_output_mirroring_spec.rb`, `rake_release_task_path_disambiguation_spec.rb`, `bracket_path_handling_spec.rb`, and `special_path_characters_spec.rb` run full builds.
