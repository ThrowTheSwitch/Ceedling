# Paths

Ceedling turns text into files in three ways. **Resolution** finds the file an `#include` names, by the compiler's rules. **Conventions** layer Ceedling's own rules on a resolved result: mock names, pairing, Partial modules and `TEST_SOURCE_FILE()` entries. **Lookup** finds a user file in a collection from text a user wrote, such as a task argument. Every path is a `PathRef`, and every comparison of paths goes through `Matchinator`. Each path is resolved once and recorded in the build plan, and later stages read the record.

These docs are for developers and coding agents. [GLOSSARY.md](GLOSSARY.md) defines every term they use, and they use no others.

## Contents

- [PATHS.md](PATHS.md) covers path values and matching. It describes `PathRef`, its spellings and its intake rules, the `..` rule and the case rule. It then describes `Matchinator`'s segments, trailing match and containment.
- [RESOLUTION.md](RESOLUTION.md) covers `Resolvinator`. It describes include records, the model a search runs on, the quote rule, results, resolution records, cross-checks and fallback.
- [CONVENTIONS.md](CONVENTIONS.md) covers the four conventions. They are mock names (`MockNaminator`), pairing (`SourcePairinator`), Partial modules (`PartialModuleMatchinator`) and `TEST_SOURCE_FILE()` entries.
- [LOOKUP.md](LOOKUP.md) covers `FileLookupinator` and `CollectionIndex`. It describes collections, the three kinds of lookup, ties and misses, and task arguments.

## How an `#include` becomes a file

One `#include` passes through five steps. Each step reads only what the steps before it recorded.

1. A text scan or line markers give an include record: the include text, its form, its includer and its line.
2. `Resolvinator` searches. A quoted include tries its includer's directory first. Every include then tries the compile's search order. The first directory that holds the include text answers.
3. `MockNaminator` classifies the result. An include that resolves to no user file, and whose basename carries the mock prefix and suffix, is a mock include. Its mocked header resolves as any include text does.
4. `SourcePairinator` pairs the resolved header with the source that implements it.
5. The resolution record, with its misses, joins the build plan. Later stages read it, and the dependency cache saves it for delta builds.

Lookups run beside these steps, for build directives, Partial module sources and task arguments. A lookup never looks up a generated file. The build plan holds every generated file's placement.

## Components

Every component lives in `lib/ceedling/paths/`. A value or a set of primitives uses no DIY objects and reads no configuration, so the launcher in `bin/` can use it. A service is a DIY object.

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

## Rules every component keeps

Eight rules hold across the components. A change to any of them must keep all eight.

1. **Compiler-faithful first.** Resolution follows the compiler's rules. A convention runs only on a resolved result, and each convention has one implementation.
2. **One path, one value.** Intake makes a `PathRef`. Code compares `PathRef`s by key and never compares spellings as text.
3. **Containment by segments.** A path lies within a directory only when the directory's segments begin the path's segments. No code tests a text prefix.
4. **One case rule.** A key folds case only where its root's file system folds case, as the case probe found.
5. **Only the configured order settles a tie.** Search order settles a resolution, and root order settles a root-relative lookup. A glob's expansion order is part of the configured order. Each settled tie logs at COMPLAIN with a NOTICE label that names the order. Any other tie fails and lists the candidates.
6. **Resolve once.** Each path is resolved once per build and recorded in the build plan. No later stage searches or looks up again.
7. **Generated files are planned.** Their placements come from the build plan, and no lookup returns one.
8. **Forward slashes.** Every path Ceedling holds uses `/`. Intake converts.

## Neighbors

- `lib/ceedling/filesystem/` holds `ProjectPaths`, whose spelling functions `PathRef` builds on, and `BuildSubpath`, which forms `PathRef`'s build subpath. It also holds collection building, whose results `CollectionIndex` indexes.
- Partials, mocks and the build plan consume these components' answers. They never repeat a convention's rule.

## Specs

- **Unit.** Each component has `spec/units/paths/<file>_spec.rb`. Case-folding and Windows examples stub the case probe's table, so they run on every host.
- **Contract.** The rows in `spec/contract/` pin what resolution, pairing and lookups give in real builds, beside the compiler's answer, on every platform. The `RES`, `MOCK`, `PART` and `LINK` areas cover these components.
