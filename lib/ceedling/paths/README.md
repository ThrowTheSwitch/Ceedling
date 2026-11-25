# Paths

Ceedling turns text into files in three ways. **Resolution** finds the file an `#include` names, by the compiler's rules. **Conventions** layer Ceedling's own rules on a resolved result: mock names, pairing, Partial modules and `TEST_SOURCE_FILE()` entries. **Lookup** finds a user file in a collection from text a user wrote, such as a task argument. Every path is a `PathRef`, and every comparison of paths goes through `Matchinator`. Each path is resolved once and recorded in the build plan, and later stages read the record.

Ceedling also places every file it generates. **Placement** turns each artifact's identity into one location, and overlays put generated files where the compiler's own search finds them. **Stage search orders** give each compile the directories it searches. The **build plan** records all of it for the run.

Paths leave Ceedling at **the edges**: command lines, the link, plugins and tasks. Every root list and collection is built once, at the collection point. A tool template owns its quoting, and no substituted value is expanded. The link follows the linker's library search, and plugins read the build plan rather than repeating a rule.

These docs are for developers and coding agents. [GLOSSARY.md](GLOSSARY.md) defines every term they use, and they use no others.

## Contents

- [PATHS.md](PATHS.md) covers path values and matching. It describes `PathRef`, its spellings and its intake rules, the `..` rule and the case rule. It then describes `Matchinator`'s segments, trailing match and containment.
- [RESOLUTION.md](RESOLUTION.md) covers `Resolvinator`. It describes include records, the model a search runs on, the quote rule, results, resolution records, cross-checks and fallback.
- [CONVENTIONS.md](CONVENTIONS.md) covers the four conventions. They are mock names (`MockNaminator`), pairing (`SourcePairinator`), Partial modules (`PartialModuleMatchinator`) and `TEST_SOURCE_FILE()` entries.
- [LOOKUP.md](LOOKUP.md) covers `FileLookupinator` and `CollectionIndex`. It describes collections, the three kinds of lookup, ties and misses, and task arguments.
- [PLACEMENT.md](PLACEMENT.md) covers `ArtifactIdentity`, `Placeinator`, overlays and pinned includes. It describes the layout, the rule for each artifact kind, reach directories, stand-ins and release placement.
- [ISOLATION.md](ISOLATION.md) covers `Isolator`. It describes the quote rule's gap, planning, isolation copies, sources and rebuilds.
- [OWNERSHIP.md](OWNERSHIP.md) covers `OwnershipLedger`. It describes entries, leftovers, and clean and clobber.
- [STAGES.md](STAGES.md) covers `SearchOrderinator` and `BuildPlan`. It describes the configured order, the order of each stage's runs, stage 4, stage 15, tool outputs, release planning and the dependency cache.
- [PARTIALS.md](PARTIALS.md) covers routes (`PartialRoutinator`), Partial placement, remapping and module qualifiers (`PartialRemapinator`), and directive arguments.
- [EDGES.md](EDGES.md) covers configuration intake and the shell-operator check, `Collectinator`, command lines (`CommandLineBuildinator`), the link (`Linkinator`), plugins and coverage scope (`CoverageScopinator`), test selection (`TestSelectinator`), the launcher and Windows.
- [EXTENSIONS.md](EXTENSIONS.md) covers where later features plug in, starting with shared mocks.

## How an `#include` becomes a file

One `#include` passes through five steps. Each step reads only what the steps before it recorded.

1. A text scan or line markers give an include record: the include text, its form, its includer and its line.
2. `Resolvinator` searches. A quoted include tries its includer's directory first. Every include then tries the compile's search order. The first directory that holds the include text answers.
3. `MockNaminator` classifies the result. An include that resolves to no user file, and whose basename carries the mock prefix and suffix, is a mock include. Its mocked header resolves as any include text does.
4. `SourcePairinator` pairs the resolved header with the source that implements it.
5. The resolution record, with its misses, joins the build plan. Later stages read it, and the dependency cache saves it for delta builds.

Lookups run beside these steps, for build directives, Partial module sources and task arguments. A lookup never looks up a generated file. The build plan holds every generated file's placement.

## How a generated file gets its place

A generated file passes through four steps, recorded in the build plan as it goes.

1. The planner forms the file's `ArtifactIdentity`: its kind, origin, fingerprint and owning test.
2. `OwnershipLedger` records the identity, then removes the test's leftovers of that kind.
3. `Placeinator` gives the identity its placement. A mock or substitute lands in the test's overlay, at its origin's build subpath.
4. `SearchOrderinator` puts each overlay just ahead of the search path it repeats, so include text reaches the generated file as it would have reached the origin. Every `#include` Ceedling writes is pinned to its file.

## Components

Every component lives in `lib/ceedling/paths/`, except `CommandLineBuildinator`, which lives in `lib/ceedling/tools/` beside `ToolExecutor`. A value or a set of primitives uses no DIY objects and reads no configuration, so the launcher in `bin/` can use it. A service is a DIY object. A record is a DIY object that keeps its state between builds.

| Component | File | Kind | Job | Described in |
| --- | --- | --- | --- | --- |
| `PathRef` | `path_ref.rb` | value | One path and its spellings | [PATHS.md](PATHS.md#pathref) |
| `Matchinator` | `matchinator.rb` | primitives | Segments, trailing match, containment, generated-directory tests | [PATHS.md](PATHS.md#matchinator) |
| `Resolvinator` | `resolvinator.rb` | service | Resolution by the compiler's rules | [RESOLUTION.md](RESOLUTION.md) |
| `ResolutionRecord` | `resolution_record.rb` | value | One resolution and its misses | [RESOLUTION.md](RESOLUTION.md#resolution-records) |
| `MockNaminator` | `mock_naminator.rb` | primitives | A mock name and its mocked header's include text, and mock classification | [CONVENTIONS.md](CONVENTIONS.md#mock-names-mocknaminator) |
| `SourcePairinator` | `source_pairinator.rb` | service | Pairing a resolved header with its source | [CONVENTIONS.md](CONVENTIONS.md#pairing-sourcepairinator) |
| `PartialModuleMatchinator` | `partial_module_matchinator.rb` | service | A Partial directive's module header and source | [CONVENTIONS.md](CONVENTIONS.md#partial-modules-partialmodulematchinator) |
| `FileLookupinator` | `file_lookupinator.rb` | service | Lookups in collections | [LOOKUP.md](LOOKUP.md) |
| `CollectionIndex` | `collection_index.rb` | value | One collection's index | [LOOKUP.md](LOOKUP.md#collectionindex) |
| `ArtifactIdentity` | `artifact_identity.rb` | value | An artifact's kind, origin, fingerprint and owner | [PLACEMENT.md](PLACEMENT.md#artifact-identity) |
| `Placeinator` | `placeinator.rb` | service | Every placement below the build root, and every generated name | [PLACEMENT.md](PLACEMENT.md#placeinator) |
| `Isolator` | `isolator.rb` | service | The isolation copies each test enters | [ISOLATION.md](ISOLATION.md) |
| `OwnershipLedger` | `ownership_ledger.rb` | record | The owners of each artifact, and leftover removal | [OWNERSHIP.md](OWNERSHIP.md) |
| `SearchOrderinator` | `search_orderinator.rb` | service | The stage search order of each run | [STAGES.md](STAGES.md#stage-search-orders) |
| `BuildPlan` | `build_plan.rb` | value | What one build compiles, links and places, and where each path resolved | [STAGES.md](STAGES.md#buildplan) |
| `PartialRoutinator` | `partial_routinator.rb` | service | Each test's routes headers | [PARTIALS.md](PARTIALS.md#routes) |
| `PartialRemapinator` | `partial_remapinator.rb` | service | Remapped Partial includes and module qualifiers | [PARTIALS.md](PARTIALS.md#remapping) |
| `Collectinator` | `collectinator.rb` | service | Every root list, collection and index, built once at the collection point | [EDGES.md](EDGES.md#collectinator) |
| `CommandLineBuildinator` | `lib/ceedling/tools/command_line_buildinator.rb` | service | Each tool run's command line, from its template and values | [EDGES.md](EDGES.md#command-lines) |
| `Linkinator` | `linkinator.rb` | service | Each link's arguments and library files, and each test run's loader path | [EDGES.md](EDGES.md#the-link) |
| `CoverageScopinator` | `coverage_scopinator.rb` | service | The files a coverage report covers, the untested sources and Partial credit | [EDGES.md](EDGES.md#coverage-scope) |
| `TestSelectinator` | `test_selectinator.rb` | service | The tests a selection task runs | [EDGES.md](EDGES.md#test-selection) |

## Rules every component keeps

Fifteen rules hold across the components. A change to any of them must keep all fifteen.

1. **Compiler-faithful first.** Resolution follows the compiler's rules. A convention runs only on a resolved result, and each convention has one implementation.
2. **One path, one value.** Intake makes a `PathRef`. Code compares `PathRef`s by key and never compares spellings as text.
3. **Containment by segments.** A path lies within a directory only when the directory's segments begin the path's segments. No code tests a text prefix.
4. **One case rule.** A key folds case only where its root's file system folds case, as the case probe found.
5. **Only the configured order settles a tie.** Search order settles a resolution, and root order settles a root-relative lookup. A glob's expansion order is part of the configured order. Each settled tie logs at COMPLAIN with a NOTICE label that names the order. Any other tie fails and lists the candidates.
6. **Resolve once.** Each path is resolved once per build and recorded in the build plan. No later stage searches or looks up again.
7. **Generated files are planned.** Their placements come from the build plan, and no lookup returns one.
8. **Forward slashes.** Every path Ceedling holds uses `/`. Intake converts.
9. **One placement authority.** Only `Placeinator` forms a path below the build root, and it forms each one from an artifact identity. No code reads an identity back from a path.
10. **Pinned includes.** Every `#include` Ceedling writes names its file by absolute spelling, so no search or shadowing can redirect it.
11. **Removal by record.** During a build, only `OwnershipLedger` removes an artifact, and only one it recorded.
12. **Collect once.** Root lists and collections are built once per run, at the collection point, and never change after it. Plugins add entries through configuration alone.
13. **Expand only what the author wrote.** Ruby expansion runs once on each configuration value and tool template, and never on a substituted value.
14. **Templates quote, nothing escapes.** A tool template quotes each path it receives. Ceedling escapes no path for a shell, and warns at load on a shell operator.
15. **Messages speak to C developers.** A message says in plain words what went wrong. It names every file, line, `#include` and setting involved, and gives the fix when it knows one. A NOTICE or WARNING logs at its cause's first occurrence in a run, and repeats log only at OBNOXIOUS. Every message follows the developer docs' page on writing log messages, `docs/mkdocs/development/log-messages.md`.

## Neighbors

- `lib/ceedling/filesystem/` holds `ProjectPaths`, whose spelling functions `PathRef` builds on, and `BuildSubpath`, which forms `PathRef`'s build subpath. It also holds the glob expansion `Collectinator` calls.
- `lib/ceedling/tools/` holds `ToolExecutor`, which runs each command line, `ToolValidator` and `ShellQuoting`. `lib/ceedling/ruby_expandinator.rb` holds `RubyExpandinator`.
- `plugins/` call these components for every path rule, as [EDGES.md](EDGES.md#plugins) says.
- `lib/ceedling/test_invoker/` holds the test pipeline's stages and planner, which fill the build plan. `lib/ceedling/release_invoker/` does the same for a release.
- `lib/ceedling/partials/` generates Partials. It takes placements, routes and remaps from these components.
- Partials, mocks and the stages consume these components' answers. They never repeat a convention's rule.

## User docs

The user docs under `docs/mkdocs/` describe these behaviors for users. Each track B PR corrects the user docs on the behavior it changes, as uncommitted diffs reviewed last. Every page it touches on paths or `#include`s links the Glossary section of `testing-guide/conventions.md`.

## Specs

- **Unit.** Each component has `spec/units/paths/<file>_spec.rb`. Case-folding and Windows examples stub the case probe's table, so they run on every host.
- **Contract.** The rows in `spec/contract/` pin what resolution, pairing, lookups and placement give in real builds, beside the compiler's answer, on every platform. The `RES`, `MOCK`, `PART` and `LINK` areas cover resolution and the conventions. The `GEN`, `ISO`, `DELTA` and `COV` areas cover placement, isolation, delta builds and coverage. Each PR adds the rows its fixes meet.
