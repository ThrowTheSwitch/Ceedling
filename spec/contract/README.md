# Contract rows

The contract tier states what Ceedling does with a project's files and configuration, and what the compiler does with the same files. Each row is a small project. A runner builds it with this checkout's own Ceedling and reports what happened at each stage, and an oracle asks the compiler which file each `#include` enters. The two answers sit side by side in the row's recorded file, so a change to path handling shows as a diff of `recorded/`.

Run the tier with `bundle exec rspec spec/contract`. It needs the compiler as `gcc`, as Ceedling's defaults do.

## Layout

The tier lives in spec code only, and finds everything through this checkout, so it runs from an installed gem as it does from a clone.

| Path | Holds |
|---|---|
| `spec/contract/rows/<ID>.yml` | One row's inputs and its target column, written by hand |
| `spec/contract/recorded/<ID>.yml` | The row's recorded current and compiler columns, written by the recorder |
| `spec/contract/contract_rows_spec.rb` | One example group per row file |
| `spec/contract/harness/*_spec.rb` | Specs of the harness itself |
| `spec/support/contract/` | The loader, tree writer, runner, report, oracle, normalizer and recorder |
| `spec/support/contract/probe/contract_probe.rb` | The Ceedling plugin the runner enables to observe a build |

## Row IDs

A row's ID names a behavior area and a number, such as `ISO-001`. An ID is permanent. It is never renumbered or reused, and a retired row's ID stays retired. The title names the scenario the row builds.

| Area | Behavior |
|---|---|
| `RES` | Include resolution |
| `MOCK` | Mock naming and lookup |
| `PART` | Partials |
| `LINK` | The link set and header-to-source pairing |
| `GEN` | Generated-file identity and placement |
| `ISO` | Header isolation |
| `DELTA` | Delta builds |
| `COV` | Coverage plugins |
| `ORC` | Oracle self-checks |

## The row format

A row file is YAML. The loader rejects any key it does not know, at every level, so a misspelled field fails loudly.

```yaml
id: ISO-001
title: Sibling isolation for a mocked inline header reached through -I .
platforms: [linux, macos, windows]  # the default
platform_note: ...                  # required when platforms is narrowed
modes: [tests]                      # :use_test_preprocessor values
plugins: []                         # plugins every leg enables
tree:                               # every file, by path
  src/drivers/foo.h: |
    ...
project:                            # merged over the base project file
  :paths:
    :include: [.]
steps:                              # optional; the default is one `build: test:all`
  - build: test:all
legs:                               # optional; the default is one unnamed leg
  gcov:
    plugins: [gcov]
divergences:                        # where Ceedling differs from the compiler, and why
  - at: resolved test/test_helper.c "src/drivers/mock_foo.h"
    kind: convention
    note: A mock include names the mocked header, which the compiler never sees
target: ~                           # the redesign's promised behavior, when written
```

- **`tree`** holds every file the project needs, so `#include` spellings appear inside sources, headers and test files alike. A path starting `../` lands beside the project, and one starting `%{far}/` lands in a directory far outside it. `%{far}` also expands inside file text and the project configuration.
- **`modes`** lists the `:use_test_preprocessor` values the row runs: `none`, `mocks`, `tests` and `all`. Partials force `all`, so a row with `:use_partials` lists only `all`.
- **`project`** is merged over a base project. The base sets the build root to `build`, mocking on with the `mock_` prefix, backtraces off, `:test` paths `test/**`, `:source` paths `src/**`, and `:which_ceedling` to this checkout. Hashes merge key by key. A list replaces the base's list.
- **`steps`** run in order. `build` runs a task and reports it. `write` adds or replaces files, `delete` removes files or directories, and `clobber` runs `ceedling clobber`. A row with steps is a delta-build row, and its report holds one entry per build step.
- **`legs`** are separate ways to build the row. A leg may add `plugins`, merge more `project` configuration, replace the row's `steps`, name tools it `requires` and a compiler `cc` the oracle runs, and carry a `note`. A leg whose tool or compiler is absent is skipped, and its recorded section stays as it was.
- **`divergences`** declare each resolved entry where Ceedling's answer differs from the compiler's. Each has a `kind`, `defect` for a difference the redesign removes or `convention` for a deliberate rule layered on the compiler, and a plain `note`.

A row expecting a failed build records the failure in its current column. A failure is an observation, not a spec failure.

## What the runner reports

The runner builds each variant, one mode of one leg, in a fresh temporary workspace. It writes the tree and a `project.yml`, then runs `bin/ceedling` in a subprocess with the probe plugin enabled and console decorations off. The probe records each compile, link, mock and runner through plugin hooks, each test's pipeline record at stage 5 through `TestInvoker#state`, and the whole record again at `post_test_build`. After each build step the runner turns the probe's record and the build's log into a report.

| Section | Content |
|---|---|
| `outcome` | `pass` or `fail` by exit status, the first error line and the stage it fell under, and `stages`, each stage heading's progress lines |
| `resolved` | Ceedling's answer for each test-file `#include` it holds a belief about: a mock's header, a Partial's module header and source, a plain header, and the linked sources sharing that header's stem |
| `search_paths` | Per test, the derived paths and refusals, the search paths and mock search paths at stage 5, and the final paths where isolation changed them. Per object, its compile search paths. Per executable, its link library paths. |
| `placements` | The mocks, stand-ins, header copies, Partials, runners and preprocessed files on disk, each object compiled, each mock's header as Ceedling holds it, isolation copies, and what this build generated |
| `link_set` | Each linked executable's objects, mapped back to their sources |
| `entered` | The headers each compiled object's `.d` file lists, and the files each test's directives-only preprocessing entered by its line markers, raw beside normalized. `mocks_read` says whether that preprocessing found a generated mock or a stand-in at each mock's path. |

A resolved entry is keyed by its includer and directive, as `test/test_a.c "a.h"`, `test/test_a.c <a.h>` or `test/test_a.c TEST_PARTIAL_MODULE(a)`. A Partial's source and a header's paired sources add ` source` to the key. Without test preprocessing a plain `#include` holds only its text, so only its paired sources are reported.

Every path is normalized before it is compared. It is relative to the project root, with forward slashes and no `.` segments. A file beside the project keeps its `../`, a far file starts `%{far}/`, a file in this checkout starts `%{ceedling}/`, and any other file outside the workspace is `<system>`. A temporary directory name a build makes is `<tmp>`. In log text, times and linker section offsets are masked.

## The oracle

The oracle answers one question per directive: given this includer, this spelling and the configured search order, which file does the compiler enter? The compiler answers it, not a rule in Ruby.

- It writes the row's files into a scratch workspace, away from the build.
- For each directive it writes a one-line probe file holding that `#include` into the includer's directory. It runs `gcc -E -H` on it with `-I` from the `:test`, `:support`, `:include` and `:libraries` paths, in that order, with globs expanded as Ceedling documents them.
- The first depth-1 `-H` entry is the answer. A missing file is `missing`. The quote rule and the angle-bracket skip come from the compiler unaided.
- A Partials directive names a module, not a file. The compiler expands the macro with Ceedling's own `ceedling.h` and the row's test defines, and the answer is what the expanded `<dir>/<module>.h` resolves to from the includer's directory.
- Unity, CMock, CException and `ceedling.h` includes are left out, since every build supplies them.

The oracle checks its own answers. An angle include answered from its includer's directory, which no search path names, raises an error, as does a probe with neither an entry nor a missing-file error.

`CONTRACT_CC` picks the compiler. The default is `gcc`, which is Apple Clang on macOS and MinGW GCC on Windows. A leg's `cc` overrides it for that leg.

## The three columns

A row has three columns, and each example checks one of them for one variant.

- **Compiler** covers `resolved` only, since the link set, placements and search paths have no compiler answer. It is stored once, not per platform, as one list of answers per build step. Every variant on every platform asserts that its live oracle equals it, so a toolchain that resolves differently fails the row.
- **Current** covers every section. Each platform has its own section in the recorded file, and in it one list of build reports per variant. A variant asserts its live reports equal its platform's section. A missing section fails.
- **Target** is the behavior the redesign promises. A row's `target` maps a variant key to its promised build reports, giving only the sections it promises. A row with a target asserts it as pending until a change makes it pass.

Where current and compiler both answer a resolved entry and differ, the row must declare it in `divergences`. An undeclared difference fails the row, and so does a declaration no variant shows.

## Recording

`CONTRACT_RECORD=1 bundle exec rspec spec/contract` rewrites the running platform's sections in each recorded file, and the compiler column. Variants that cannot run here keep what was recorded. While recording, the current and compiler checks are skipped, and the divergence checks still run.

On a mismatch, or while recording, a row also writes its whole recorded file, with this platform's live sections merged in, to `$CONTRACT_OUT/<ID>.yml`. Each run writes the time per row and the tier's total to `$CONTRACT_OUT/timings-<platform>.txt`. `CONTRACT_OUT` defaults to `ceedling-contract` in the system temporary directory. CI uploads it as an artifact on every run, so a platform's sections can be recorded from a CI run by copying its files into `recorded/`.

## Adding a row

A new path behavior starts as a row.

1. Write `rows/<ID>.yml` with the next free number in its area.
2. Run `CONTRACT_RECORD=1 bundle exec rspec spec/contract -e <ID>` to record this platform and the compiler column.
3. Read the recorded file. Declare each divergence the run reports, with a note saying why Ceedling differs.
4. Record the other platforms from their own runs or from CI's artifact.
