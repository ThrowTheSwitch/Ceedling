# Path values and matching

`PathRef` holds one path and every spelling of it. `Matchinator` compares paths by key and by whole segments. Together they give every component one spelling model and one case rule.

## Contents

- [PathRef](#pathref) is the value. Its sections cover intake, the spellings, the `..` rule, the case rule and equality.
- [Matchinator](#matchinator) holds the primitives: segments, trailing match, containment and generated-directory tests.
- [Code](#code) lists the files and what each depends on.

## PathRef

A `PathRef` is an immutable value for one file or directory. Stages pass `PathRef`s, never path strings. Two `PathRef`s are equal when their keys are equal, so a Hash or a Set holds each place once, however many spellings reach it.

### Intake

A path enters Ceedling as written text and a base directory. `PathRef.of( text, base: )` applies the intake rules once. The base is the project root for configuration and the launcher. For an include text it is the directory that answered the search.

- **Separators.** On Windows, `\` becomes `/`. Elsewhere `\` is a legal filename character and stays.
- **Home.** `~` and `~/…` expand to the home directory. `~user` names a directory called `~user` below the base, on every platform.
- **Escapes.** A line marker's filename is a C string literal, so intake unescapes it once. A dependency file's names are make-rule text, so intake unescapes `\ `, `\#` and `$$` once.
- **Ends.** A trailing `/` drops. A bare root such as `/` or `C:/` stays. A Windows drive letter is upper case.

Paths enter at these points: configuration load (`:paths`, `:files`, tool paths and plugin paths), the launcher's options (`--project`, `--logfile`, `--mixin` and `:which_ceedling`), build directives, include records, line markers and dependency files. Each one calls `PathRef.of`. Mixin files are deduplicated by key, so one file reached by two spellings merges once.

### Spellings

A `PathRef` has five spellings and one derived view. Each spelling after the written one is computed when first asked for, and memoized.

| Spelling | `proj_src/lnk/a.h`, with `lnk` → `other` | Reads disk | Used for |
| --- | --- | --- | --- |
| written | `./proj_src/lnk/a.h` | no | messages that quote the author |
| absolute | `/w/proj/proj_src/lnk/a.h` | for an inner `..` only | joins and the `..` rule |
| real | `/w/proj/other/a.h` | yes | the key and the build subpath |
| project-relative | `proj_src/lnk/a.h` | no | logs, the `-I` list and the contract tier |
| key | `/w/proj/other/a.h`, case-folded where its root folds case | through real | equality, hashing and every index |

- **Project-relative** keeps symlinked directories as configured, so logs and the compiler see the paths the configuration names. A path with no relative form, such as one on another Windows drive, keeps its absolute spelling here.
- **Build subpath** is a view, not a spelling. `BuildSubpath.encode` forms it from the real spelling's directory, so two spellings of one directory share one build directory. An overlay recreates each symlink a join passes through, so include text written through a link still reaches the generated file at that build subpath, as [PLACEMENT.md](PLACEMENT.md#overlays) says.

### The `..` rule

An inner `..` follows the kernel, which resolves a symlink before it climbs. So before an inner `..` collapses, the absolute spelling resolves the part before it on disk, where that part exists. With `lnk` → `real/sub`, the text `lnk/../b.h` is `real/b.h`, the file the compiler opens.

- Past the existing part, `.` and `..` collapse as text, since nothing on disk can redirect them yet.
- A leading `..` needs no read, because the project root's spelling is already real.
- Each distinct prefix is read once per build.

### The case rule

Whether `Foo.h` names `foo.h` depends on the file system that holds it. The case probe answers that once per root, at the collection point.

- **The probe** stats each root's directory under a case-swapped spelling and compares the result with the root's own. It probes the project root and the build root too.
- **Keys.** A path takes the finding of the nearest probed directory above it. Where that file system folds case, the key is the real spelling folded by `downcase`. Elsewhere the key keeps its case. `downcase` keeps `Straße.h` and `STRASSE.h` apart, as NTFS does.
- **Logging.** Each root's finding is logged at OBNOXIOUS. A case mismatch the file system accepts resolves with no message, as it does for the compiler.

`Collectinator` builds the probe's table once, as [EDGES.md](EDGES.md#the-collection-point) says, and hands it to `PathRef`. `PathRef` reads no configuration.

### Equality

`==`, `eql?` and `hash` use the key. Output that lists paths sorts by project-relative spelling, so it is stable from run to run.

## Matchinator

`Matchinator` holds the primitives every component compares paths with. Each works on keys and whole segments. No other component splits, matches or contains paths on its own.

| Function | Answer |
| --- | --- |
| `segments( path )` | The path's segments, split on `/`. `.` and empty segments drop, and `..` stays a segment |
| `trailing?( path, text )` | Whether the text's segments equal the path's last segments |
| `contains?( dir, path )` | Whether `dir` is `path` or one of its ancestors, by whole segments |
| `subpath_below( dir, path )` | The segments from `dir` down to `path`, or nil outside it |
| `segment_run?( path, text )` | Whether the text's segments appear in the path's segments, whole and in order |
| `generated?( path, roots )` | Whether the path lies in one of the build's generated directories |

- **Trailing match** needs whole segments. `drivers/uart.h` matches `src/drivers/uart.h` and never `src/xdrivers/uart.h`. Text with `..` collapses by the `..` rule before it is matched.
- **Case.** Each comparison uses the key rule of the path's root.
- **Containment** answers every question of the form "inside": the build root's filter on preprocessed dependencies, generated-directory tests, root membership and coverage filters.
- **`segment_run?`** selects tests for path tasks. A task argument `unit` selects `test/unit/test_a.c` and never `test/unit_extra/test_b.c`.

## Code

- `lib/ceedling/paths/path_ref.rb` holds `PathRef`, and `lib/ceedling/paths/matchinator.rb` holds `Matchinator`. Neither depends on a DIY object or on configuration. The probe's table is passed in.
- `PathRef` builds on `ProjectPaths` in `lib/ceedling/filesystem/` for its absolute, real and relative forms, and on `BuildSubpath` for its build subpath.
- Specs: `spec/units/paths/path_ref_spec.rb` and `matchinator_spec.rb`.
