# Glossary: path handling terms

Each core concept in Ceedling's path handling has one name and one definition. Log text, errors, user docs, developer docs, comments and class names all use it.

**Columns.** "Seen in" says where a term appears: **L** log text and errors, **U** user docs, **D** developer docs and comments, **C** class and method names. "Retires" lists the words a term replaces. A retired word leaves docs, comments and log text as each change rewrites them. "Retired words" lists them all, for a grep check.

## Naming rules

1. **The precise word wins.** Ceedling's users are C developers. An exact technical word serves them in logs and user docs as well as in code.
2. **The compiler's word, when it is plain.** Where GCC or the C standard names a concept in common words, Ceedling uses that word, such as "search path", "line markers", "quoted" and "angle". An obscure one, such as the standard's "header name", gives way to a plain Ceedling term.
3. **An overloaded word is always qualified.** A word with several meanings never appears bare. Each meaning is a qualified term, such as "build root" or "Ruby expansion". A meaning that cannot be qualified cleanly gets a different word, as "absolute" replaces the "resolved" spelling.
4. **A new class name carries its term's stem.** A service that acts takes the `-inator` form, as in `Resolvinator` from resolution. A value or record takes a plain noun, as in `BuildPlan`. An existing class is renamed only by the change that rewrites it. Log text and user docs never print class names.
5. **One word where possible.** A short phrase is used only where one word would be ambiguous, such as "include text".
6. **In messages, a term labels a plain sentence.** Rule 1 picks the word, and this rule places it. A log message says what happened in plain words, with terms as its nouns. A C term, such as include text, search order or quoted include, stands alone. A Ceedling-specific term, such as shadow, stand-in, route or isolation copy, appears only beside a clause that says what it means, so the reader learns the word to search the docs for. The Ceedling docs page on writing log messages holds the rest of the message rules.

## Paths and spellings

A path has one value and several spellings. Logs print the project-relative spelling, and comparisons use the key.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| spelling | One way of writing a path as text. One path has several spellings | L U D | form, rendering |
| written | The spelling exactly as the author wrote it, in configuration, an `#include` or a build directive | L U D | as written, raw, standardized |
| absolute | The spelling from the filesystem root. Before an inner `..` collapses, the part before it is resolved on disk where it exists, so the spelling never names another file. Past the existing part, `.` and `..` collapse as text | D C | lexical absolute, expanded, resolved (as a spelling) |
| real | The absolute spelling with every symlink resolved on disk | D C | real absolute |
| project-relative | The absolute spelling relative to the project root, with forward slashes. Symlinked directories stay as configured | L U D C | canonical, relative, working-dir relative, collected |
| key | The spelling Ceedling compares and hashes: the real spelling, with case folded by `downcase` only where its root's file system folds case | D C | comparison key, case-folded key, dependency key |
| case probe | The check, once per directory, of whether names inside it fold case: every root at the collection point, and any directory a key needs before it | L D C | — |
| build subpath | The directory below a build directory that mirrors a path, with markers for paths outside the project and for shortened bases | D C | encoded subpath |
| shortened base | An outermost base whose build subpaths start with its base marker in place of its own path, since the marker is shorter | L U D C | shortened root, long root |
| base marker | The `_<name>_<hash>` segment that stands for a shortened base at the start of a build subpath | L U D C | root marker, short name |
| mirror | A file's path below its base. Pairing's mirror tier looks it up below each source root, and a build subpath below a base marker repeats it | U D | mirrored subdirectory |
| segment | One directory or file name in a path | D C | component, part |
| containment | Whether a path lies at or below a directory, judged on keys and whole segments | D C | prefix check, inside |
| project root | The directory Ceedling runs in, which usually holds the project file, `project.yml` or `ceedling.yml`. Relative paths in configuration and in the launcher's options start from it | L U D | working directory, cwd (in prose) |
| build root | The directory `:project` ↳ `:build_root` names. Every artifact goes below it | L U D | build directory (as a root) |
| PathRef | The immutable value that holds one path and its spellings. Stages pass it and compare it by key | D C | PathSpellings, ad hoc path strings |

## Configuration and collections

An entry yields roots. Some roots become search paths, and one compile's search paths in order are its search order.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| entry | One item of a `:paths` or `:files` list, as written | L U D | path entry, config entry |
| root | One directory a `:paths` entry yields after glob expansion, named by kind: source root, include root, test root, support root, library root. `src/**` yields the roots `src`, `src/a` and so on. A directory `Placeinator` forms is a generated root, never a root | L U D | path (for a configured directory) |
| base | A `:paths` entry's directory before any glob. Mirrors are formed below it | D C | mirror root |
| implicit root | A source root that a `:files` ↳ `:source` addition outside every source root adds: the added file's own directory, after the configured roots | U D C | — |
| search path | One directory of a compile's search order, which its `-I` options give: a root, a generated directory, a `TEST_INCLUDE_PATH()` directory, or a directory a `:files` ↳ `:include` header adds | L U D C | include path, `-I` path, include directory |
| search order | The search paths of one compile, in order | L U D C | search list, include path list, `-I` list (in prose) |
| collection | The user files of one kind that Ceedling gathers at the collection point from `:paths` and `:files` | U D C | file list |
| index | A collection's lookup table, keyed by key and by basename, built with its collection | D C | — |
| configured order | A test's user search paths, in the order the compiler searches them. Every stage search order builds on it, and the release has its own | L U D C | — |
| root order | The order of one kind's roots: `:paths` order, each glob in its expansion order, then the implicit roots. It settles a root-relative lookup's tie | U D | — |

## Kinds of file

Resolution, lookups and logs sort every file into one of four kinds.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| user file | A file collected from `:paths` or `:files` | L U D C | project file (for these), source (for these) |
| generated file | An artifact that is C text a later compile reads: a mock, CMock's copy, runner, Partial, routes header, preprocessed file, stand-in or isolation copy | L U D C | — |
| framework file | A Unity, CMock or CException file that Ceedling supplies | L U D | vendor file |
| system header | A toolchain header outside every root | L U D | system include (for the file) |

## Includes and resolution

Resolution is the compiler's rule, applied by Ceedling's own model of the search order. Line markers and dependency files cross-check it where they exist.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| `#include` | A C include directive. Its form is quoted or angle | L U D | include statement, directive (bare) |
| include record | One `#include`'s include text, form, includer and line, as a text scan or line markers give it | D C | `Include` (for the record) |
| listing | The names one directory holds, read once per build. Resolution checks listings, never the disk file by file | D C | header listing |
| include text | The text between an `#include`'s quotes or angle brackets | L U D C | include spelling, `#include` text, operand, header name |
| quoted include, angle include | An `#include` written `"…"`, or one written `<…>` | L U D C | bracket form, quote form |
| includer | The file that holds an `#include`. Messages may say "including file", since it explains itself | L U D C | including file (in docs and code) |
| resolution | Finding the file an `#include` names, by the compiler's rules. The verb is "resolve" | L U D C | reconcile, respell, header lookup |
| search | Resolution's trial of directories in order: the includer's directory for a quoted include, then each search path. Only resolution searches. The linker's trial is a library search | L U D C | find (for includes) |
| quote rule | A quoted include searches its includer's directory first. An angle include skips it | U D | — |
| enter | The compiler enters a file when it opens it for an `#include` | D | open, read (for includes) |
| candidate | A file that could answer an `#include` or a lookup | L U D | match (as a noun) |
| ambiguity | Two or more candidates where one must win | L U D | collision (for lookups) |
| shadow | A header earlier in the search order shadows a same-named header later in it | L U D | hide, mask |
| miss | A directory a search tried before the one that held the file | D C | negative lookup |
| near miss | A quoted include that no directory of its search answers, though a user header's path ends with its include text | L U D C | — |
| resolution record | One include record's resolution, with its misses. The build plan holds every record for the run, and the dependency cache saves each target's | D C | `@configured_headers` snapshot |
| line markers | The preprocessor's output lines that name each file the compiler entered | L U D | linemarkers |
| dependency file | The `.d` file a compiler writes, listing the headers an object entered | L U D | `.d` (alone, in prose) |
| dependency cache | What Ceedling saves between builds so a delta build can tell what changed | U D C | — |
| cross-check | Comparing Ceedling's resolution with line markers or a dependency file, where they exist | L D C | verify, reconcile |

## Lookups and conventions

Lookup is Ceedling's own way of finding a user file from text a user wrote. Conventions are Ceedling's rules layered on the compiler's answer.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| lookup | Finding a user file in a collection from text a user wrote, such as a `TEST_SOURCE_FILE()` entry, a task argument or a Partial module's source. The verb is "look up" | L U D C | find, search (for collections) |
| root-relative lookup | A lookup that joins text with each root of one kind, in order, as resolution joins include text with each search path | U D C | header-root-relative query |
| trailing match | A lookup that matches text against a path's last whole segments. `drivers/uart.h` matches `src/drivers/uart.h`, never `src/xdrivers/uart.h` | U D C | tail match, suffix match, trailing-segment match |
| convention | A Ceedling rule layered on the compiler's answer | U D | — |
| mock | A CMock-generated double of a header's functions | L U D C | — |
| mocked header | The header a mock stands for. It is the mock's origin | L U D C | mock's header, original header, mockable header |
| mock include | An `#include` of a mock, such as `#include "mock_uart.h"` | L U D C | — |
| mock name | A mock's file name: its mocked header's name with the mock prefix and suffix | L U D C | — |
| mock prefix, mock suffix | The text `:mock_prefix` and `:mock_suffix` add to a mocked header's name | L U D | — |
| module | A source file and the header that shares its stem. A module may lack either one | L U D C | unit, component |
| pairing | Finding the source file that implements a header, so a test that includes `uart.h` links `uart.c`. Its result is the paired source | L U D C | header/source correspondence, header-to-source matching |
| link set | The objects one test executable links | L U D C | — |
| build directive | A macro in a test file that steers its build, such as `TEST_SOURCE_FILE()` or `TEST_INCLUDE_PATH()` | U D | directive (bare), directive macro |
| Partial | The generated files that let a test call or mock a module's selected functions | L U D C | — |
| Test Partial, Mock Partial | A Partial a test calls directly, or one CMock mocks | L U D | — |
| Partial directive | A `TEST_PARTIAL_*` or `MOCK_PARTIAL_*` macro | L U D | directive macro |
| module directory | The directory argument of an `_AT` Partial directive | U D | `_AT` directory |
| route, routes header | The name a Partial directive's `#include` expands to, keyed by the directive's line. A test's routes header defines each route as its Partial file's absolute spelling | L U D C | — |
| remap | Writing a Partial's `#include` of another Partial module's header as that module's Partial header | D C | — |
| module qualifier | The text an `_AT` directive's module directory adds to the C names Ceedling forms from its module, so two same-named modules stay apart. Each `/` and every other character a C name can't hold is written as `_` | L U D C | — |

## Artifacts and placement

Every artifact has an identity, and placement turns the identity into a location. Ownership records which tests use each artifact.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| artifact | Any file a build writes below the build root. A release artifact is the release build's final output | L U D C | build output, output file |
| origin | The file an artifact is made from, such as a mock's mocked header, a Partial's module or an object's source. An isolation copy's origin is the user file it copies, a header or a source. A mock of a generated header, such as a Partial's interface, has a generated origin | L U D C | original, source (for artifacts) |
| artifact kind | What an artifact is, such as a mock, stand-in, isolation copy, Partial, runner, object or executable | D C | — |
| fingerprint | A digest of every setting that changes an artifact, supplemented where needed by build details derived from settings, such as a search order's digest or the files the artifact's pinned includes name | D C | settings hash |
| identity | An artifact's kind, origin, fingerprint and owner. Two equal identities are one artifact | D C | — |
| placement | The location `Placeinator` gives an identity. The verb is "place" | L D C | spot, written spot |
| owner | A test that uses an artifact, or the release for a release artifact. An artifact may have several owners | D C | — |
| generated root | A directory `Placeinator` forms for one kind of generated file, such as the overlay root, the stand-in root or the Partials root. `Matchinator.generated?` tests a path against the build plan's generated roots | D C | roots (for these) |
| overlay | A generated directory that repeats a user directory's build subpath below a test's overlay root, or below the stand-in root for stage 4, and stands just ahead of that directory in a search order, so a generated file in it answers first. A quote-rule origin's overlay follows the configured order instead. It recreates each symlink a join through it passes, pointed at the overlay of the link's target, and links each shortened base a join enters to the base's overlay | U D C | mock root, mock directories, mock search paths (for these) |
| substitute | A generated file that takes a user file's place under the user file's own name, such as CMock's copy of a mocked header or an isolation copy | D C | — |
| reach directory | A generated directory a search order holds so that include text climbing above the directory its search path's build subpath mirrors still joins to its generated file | D C | reach root, `written_spot` |
| pinned include | An `#include` that Ceedling writes, naming its file by absolute spelling so the compiler opens it with no search. A header whose text holds `#include_next` is never pinned | D C | respelled include |
| stand-in | A placeholder header Ceedling writes in its own root, at the place a mock or Partial will take, so stage 4 can run before it exists | L D C | — |
| isolation | Entering a user file through an isolation copy, so an `#include` the quote rule would send to an origin reaches the test's substitute | L U D C | sibling isolation (as a general term) |
| isolation copy | A copy of a user file at its origin's build subpath in the overlay, with pinned includes, that isolation enters in the origin's place | L D C | sibling copy |
| stale | An artifact whose fingerprint, input files or resolution records changed since it was written, or whose own file no longer matches what was written. A delta build rewrites it | L U D | out of date |
| leftover | An artifact that no owner in this build plans. Delta-build handling or a clobber removes it | L U D | stray, orphan, stale (for these) |

## Stages and the build plan

The build plan is the source of truth. Later stages read it and never search or look up again.

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| stage | One numbered step of the test pipeline | D | step, phase |
| build plan | The record of what one build compiles, links and places, and where each path resolved | D C | build structure, testable |
| stage search order | The search order a stage gives each of its compiles | D C | stage search list |
| fallback | Preprocessing's best-effort route when a file's directives-only preprocessing fails | L U D | — |
| delta build | A build that redoes only what changed since the last one | L U D | incremental build |
| target | An artifact a delta build checks, by the fingerprint, input files, resolution records and file digest the dependency cache saved for it. A release target is the release's final executable | D C | — |
| comparison mode | A temporary switch that runs the old and new resolution side by side. The build uses the old answer, and each difference is written down | D | shadow mode |

## Edges

| Term | Definition | Seen in | Retires |
|---|---|---|---|
| Ruby expansion | Evaluating `#{…}` in configuration text and tool templates | L U D | expansion (bare), interpolation |
| macro expansion | The C preprocessor replacing a macro with its definition | L U D | expansion (bare) |
| glob expansion | Turning a glob entry into the roots or files it matches | L U D | expansion (bare) |
| shell operator | A character the host shell still reads inside a double-quoted argument: `$`, `` ` ``, `"` and `\` for `/bin/sh`, and `%` and `"` on Windows | L U D | special character |
| library name, library path | A `:libraries` entry that names a library for `:flag`, or one that holds a separator, or starts with `~` or a drive, and names a file | L U D | — |
| intake | Where a path enters Ceedling, from text and a base directory: configuration load, the launcher's options, a build directive scan, an include record, line markers or a dependency file | D C | — |
| collection point | The moment, once per build, when `Collectinator` builds every root list, collection and index. The test family's tasks share one in a run, when one of them first reads a list, after its prerequisite tasks and the `:pre_build` hooks. The release has its own, after its prerequisite tasks and its `:pre_release` hooks | D C | — |
| plugin entry | An entry a plugin adds to `:paths`, `:files` or `:libraries` through configuration. It records its plugin | D C | — |
| command line | The one line of text a tool run hands to the host shell | L U D C | command-line spelling |
| tool template | A tool's `:executable` and `:arguments` as configured | U D C | — |
| placeholder | A `${n}` in a tool template, which a value replaces | U D | replacement operator, substitution string |
| library search | The linker's trial of the library roots for a library name | D C | resolve (for libraries) |
| library file | A file a link reads for a library entry: an archive, a shared library or an import library | D C | — |
| loader path | The directories the operating system searches for an executable's shared libraries when it starts: `PATH` on Windows, `LD_LIBRARY_PATH` on Linux | L U D C | — |
| coverage scope | The sources and support files a coverage report covers. No test file is in it | U D C | — |
| untested source | A user source that no link set holds | L U D C | — |
| test selection | The tests a selection task, such as `test:path` or `test:pattern`, runs | U D C | — |
| external dependency | A library the Dependencies plugin fetches, builds and links | L U D | dependency (bare, for these) |
| working path | One of an external dependency's directories: `:fetch`, `:source`, `:build`, `:artifact` or `:deploy` | U D | — |
| compilation database | The `compile_commands.json` file that lists each compile's command | U D | — |

## Components

Each component's name follows rule 4. The Doc column names the doc in this directory that describes it.

| Concept | Name | Doc |
|---|---|---|
| a path and its spellings | `PathRef` | [PATHS.md](PATHS.md) |
| trailing match, containment, segments | `Matchinator` | [PATHS.md](PATHS.md) |
| resolution | `Resolvinator` | [RESOLUTION.md](RESOLUTION.md) |
| a resolution record | `ResolutionRecord` | [RESOLUTION.md](RESOLUTION.md) |
| mock name | `MockNaminator` | [CONVENTIONS.md](CONVENTIONS.md) |
| pairing | `SourcePairinator` | [CONVENTIONS.md](CONVENTIONS.md) |
| a Partial module's header and source | `PartialModuleMatchinator` | [CONVENTIONS.md](CONVENTIONS.md) |
| a `TEST_SOURCE_FILE()` entry | — | [LOOKUP.md](LOOKUP.md): no class; it uses `FileLookupinator`'s root-relative lookup |
| lookup | `FileLookupinator` | [LOOKUP.md](LOOKUP.md) |
| a collection's index | `CollectionIndex` | [LOOKUP.md](LOOKUP.md) |
| placement | `Placeinator` | [PLACEMENT.md](PLACEMENT.md) |
| an artifact's identity | `ArtifactIdentity` | [PLACEMENT.md](PLACEMENT.md) |
| ownership | `OwnershipLedger` | [OWNERSHIP.md](OWNERSHIP.md) |
| isolation | `Isolator` | [ISOLATION.md](ISOLATION.md) |
| stage search order | `SearchOrderinator` | [STAGES.md](STAGES.md) |
| the build plan | `BuildPlan` | [STAGES.md](STAGES.md) |
| routes | `PartialRoutinator` | [PARTIALS.md](PARTIALS.md) |
| remap and module qualifiers | `PartialRemapinator` | [PARTIALS.md](PARTIALS.md) |
| comparison mode | — | no class name, since the switch is temporary |
| root lists and collections, at the collection point | `Collectinator` | [EDGES.md](EDGES.md) |
| a command line | `CommandLineBuildinator` | [EDGES.md](EDGES.md) |
| the link, library files and loader paths | `Linkinator` | [EDGES.md](EDGES.md) |
| coverage scope | `CoverageScopinator` | [EDGES.md](EDGES.md) |
| test selection | `TestSelectinator` | [EDGES.md](EDGES.md) |
| Ruby expansion | `RubyExpandinator` | [EDGES.md](EDGES.md) |
| shell operators | `ShellQuoting` | [EDGES.md](EDGES.md) |

## Retired words

Each retired word with the term that replaces it, for a grep check. Some retired words stay correct in other senses, so each hit needs a reader's judgment.

| Retired | Use |
|---|---|
| `#include` text, include spelling, header name, operand | include text |
| `-I` list, include path list, search list | search order |
| `-I` path, include directory, include path | search path |
| `_AT` directory | module directory |
| bracket form, quote form | quoted include, angle include |
| command-line spelling | command line |
| dependency (bare, for the Dependencies plugin's) | external dependency |
| replacement operator, substitution string | placeholder |
| resolve (for libraries) | library search |
| build output, output file | artifact |
| build structure, testable | build plan |
| canonical, collected, relative, working-dir relative | project-relative |
| comparison key, case-folded key, dependency key | key |
| encoded subpath | build subpath |
| expanded, lexical absolute, resolved (as a spelling) | absolute |
| expansion (bare) | Ruby expansion, macro expansion or glob expansion |
| find (for collections), search (for collections) | lookup |
| find (for includes) | search |
| header listing | listing |
| header-root-relative query | root-relative lookup |
| header/source correspondence, header-to-source matching | pairing |
| incremental build | delta build |
| mirror root | base |
| mirrored subdirectory | mirror |
| mock root, mock directories, mock search paths | overlay root, overlays |
| mock's header, mockable header, original header | mocked header |
| negative lookup | miss |
| original | origin |
| project file (for a user's own files) | user file |
| reconcile, respell | resolution, or cross-check |
| respelled include | pinned include |
| reach root, `written_spot` | reach directory |
| root marker, short name (for a base) | base marker |
| shortened root, long root | shortened base |
| shadow mode | comparison mode |
| sibling copy | isolation copy |
| stale (for a file no identity owns), stray, orphan | leftover |
| tail match, suffix match, trailing-segment match | trailing match |
| vendor file | framework file |
