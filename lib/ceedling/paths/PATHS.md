# Path values and matching

`PathRef` holds one path and every spelling of it. `Matchinator` compares paths by key and by whole segments. Together they give every component one spelling model and one case rule.

## Contents

- [PathRef](#pathref) is the value. Its sections cover intake, the spellings, the `..` rule, the case rule and equality.
- [Matchinator](#matchinator) holds the primitives: segments, trailing match, containment and generated-directory tests.
- [Code](#code) lists the files and what each depends on.

## PathRef

A `PathRef` is an immutable value for one file or directory. Stages pass `PathRef`s, never path strings. Two `PathRef`s are equal when their keys are equal, so a Hash or a Set holds each place once, however many spellings reach it.

### Intake

A path enters Ceedling as written text and a base directory. `PathRef.of( text, base: )` applies the intake rules once, in the order listed below.

- **Escapes** come first, since each source escapes its own text. A line marker's filename is a C string literal, so intake unescapes it once. A dependency file's names are make-rule text, so intake unescapes them by make's rule: `2n+1` backslashes before a space or `#` stand for `n` backslashes and that character, and `$$` stands for `$`.
- **Separators.** On Windows, `\` becomes `/`. Elsewhere `\` is a legal filename character and stays.
- **Home.** In configuration and the launcher's options, `~` and `~/…` expand to the home directory, and `~user` names a directory called `~user` below the base, on every platform. Include text, line markers and dependency files keep `~` as written, since the compiler reads it literally.
- **Ends.** A trailing `/` drops. A bare root such as `/` or `C:/` stays. A Windows drive letter is upper case.

Paths enter at these points, each with its base.

| Intake point | Base |
| --- | --- |
| configuration load: `:paths`, `:files`, tool paths and plugin paths | the project root |
| the launcher's options: `--project`, `CEEDLING_PROJECT_FILE`, `--logfile`, `--mixin`, mixin load paths and `:which_ceedling` | the project root, which the launcher starts in |
| `TEST_INCLUDE_PATH()` directories | the project root |
| `TEST_SOURCE_FILE()` entries | each source root in turn, as [CONVENTIONS.md](CONVENTIONS.md#test_source_file-entries) says |
| include records | the directory that answered the search |
| line markers and dependency files | the project root, where every tool runs |

Each one calls `PathRef.of`. Mixin files are deduplicated by key, so one file reached by two spellings merges once.

### Spellings

A `PathRef` has five spellings and one derived view. Each spelling after the written one is computed when first asked for, and memoized. The real spelling and the key are memoized for the build by absolute spelling, so each distinct file reads disk once per build, however many `PathRef`s name it.

| Spelling | `proj_src/lnk/a.h`, with `lnk` → `other` | Reads disk | Used for |
| --- | --- | --- | --- |
| written | `./proj_src/lnk/a.h` | no | messages that quote the author |
| absolute | `/w/proj/proj_src/lnk/a.h` | for an inner `..` only | joins and the `..` rule |
| real | `/w/proj/other/a.h` | yes | the key and the build subpath |
| project-relative | `proj_src/lnk/a.h` | no | logs, the `-I` list and the contract tier |
| key | `/w/proj/other/a.h`, case-folded where its root folds case | through real | equality, hashing and every index |

- **Project-relative** keeps symlinked directories as configured, so logs and the compiler see the paths the configuration names. A path with no relative form, such as one on another Windows drive, keeps its absolute spelling here.
- **Build subpath** is a view, not a spelling. `BuildSubpath.encode` forms it from the real spelling's directory, so two spellings of one directory share one build directory. Below a shortened base it starts with the base's marker, from the table `Placeinator` passes, as [PLACEMENT.md](PLACEMENT.md#shortened-bases) says. An overlay recreates each symlink a join passes through, and links each shortened base a join enters. So include text written through a link, or into a base, still reaches the generated file at that build subpath, as [PLACEMENT.md](PLACEMENT.md#overlays) says.

### The `..` rule

An inner `..` follows the kernel, which resolves a symlink before it climbs. So before an inner `..` collapses, the absolute spelling resolves the part before it on disk, where that part exists. With `lnk` → `real/sub`, the text `lnk/../b.h` is `real/b.h`, the file the compiler opens.

- Past the existing part, `.` and `..` collapse as text, since nothing on disk can redirect them yet. That forms spellings of paths not on disk yet, such as placements. A search never collapses past a missing directory, as [RESOLUTION.md](RESOLUTION.md#the-model) says.
- A leading `..` in configuration text needs no read, since its base is the project root, whose spelling is already real. Include text joins its search path first, so its leading `..` is an inner `..` of the joined path.
- Each distinct prefix is read once per build.
- **Windows.** The Windows file system API collapses `.` and `..` as text before it follows a symlink or junction. So on Windows the rule collapses as text, and `lnk/../b.h` names the `b.h` beside `lnk`.

### The case rule

Whether `Foo.h` names `foo.h` depends on the file system that holds it. The case probe answers that once for each directory it is asked about.

- **The probe** stats an entry inside the directory, one whose name holds a cased letter, under a case-swapped spelling, and compares the result with the entry's own. A directory with no such entry takes its parent's finding.
- **When.** The collection point probes every root, the project root and the build root. A key asked for before it, as the launcher's mixins and the checks at configuration load ask, takes its own directory's finding, which `PathRef` probes once on first need. The collection point reuses every finding made before it.
- **Keys.** A path takes the finding of the nearest probed directory above it. Where that file system folds case, the key is the real spelling folded by `downcase`. Elsewhere the key keeps its case. `downcase` keeps `Straße.h` and `STRASSE.h` apart, as NTFS does.
- **Logging.** Each finding is logged at OBNOXIOUS. A case mismatch the file system accepts resolves with no message from Ceedling. GCC accepts it silently, and Clang warns with `-Wnonportable-include-path`.

`PathRef` holds the probe's table for the run. `Collectinator` fills it for every root at the collection point, as [EDGES.md](EDGES.md#the-collection-point) says, and `PathRef` adds each directory it probes on first need. `PathRef` reads no configuration.

### Equality

`==`, `eql?` and `hash` use the key. Output that lists paths sorts by project-relative spelling, so it is stable from run to run. A list of candidates is the exception: it keeps the configured or collection order that ranked them.

## Matchinator

`Matchinator` holds the primitives every component compares paths with. Each works on whole segments, and on keys apart from `segment_run?`, which reads project-relative spellings. No other component splits, matches or contains paths on its own.

| Function | Answer |
| --- | --- |
| `segments( path )` | The path's segments, split on `/`. `.` and empty segments drop, and `..` stays a segment |
| `trailing?( path, text )` | Whether the text's segments equal the path's last segments |
| `contains?( dir, path )` | Whether `dir` is `path` or one of its ancestors, by whole segments |
| `subpath_below( dir, path )` | The segments from `dir` down to `path`, or nil outside it |
| `segment_run?( path, text )` | Whether the text's segments appear as one unbroken run in the path's project-relative segments, compared under the key rule of the path's root |
| `generated?( path, roots )` | Whether the path lies in one of the build's generated directories |

- **Trailing match** needs whole segments. `drivers/uart.h` matches `src/drivers/uart.h` and never `src/xdrivers/uart.h`. Text with `..` collapses by the `..` rule before it is matched.
- **Case.** Each comparison uses the key rule of the path's root.
- **Containment** answers every question of the form "inside": root membership, coverage filters and generated-directory tests. The filter that keeps generated files out of preprocessed dependencies calls `generated?( path, roots )` with the build plan's generated roots, so it also catches a `:cmock` ↳ `:mock_path` outside the build root.
- **`segment_run?`** selects tests for path tasks. A task argument `unit` selects `test/unit/test_a.c` and never `test/unit_extra/test_b.c`. It reads the project-relative spelling, so the project's own parent directories never match, and a symlinked test directory matches as configured.

## Code

- `lib/ceedling/paths/path_ref.rb` holds `PathRef`, and `lib/ceedling/paths/matchinator.rb` holds `Matchinator`. Neither depends on a DIY object or on configuration. `Collectinator` fills the probe's table for the roots, and `PathRef` probes any other directory itself.
- `PathRef` builds on `ProjectPaths` in `lib/ceedling/filesystem/` for its absolute, real and relative forms, and on `BuildSubpath` for its build subpath.
- Specs: `spec/units/paths/path_ref_spec.rb` and `matchinator_spec.rb`.
