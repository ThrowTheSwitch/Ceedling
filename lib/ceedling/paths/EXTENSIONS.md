# Extensions

Placement, ownership and stage search orders all key on artifact identity, so a later feature changes one rule rather than a layout. Each extension point below names the component that changes and what stays fixed. The first and largest is sharing one generated artifact among the tests that need an identical one.

## Contents

- [Shared artifacts](#shared-artifacts) covers the identity rule that sharing changes, and what follows from it.
- [Shared mocks](#shared-mocks) walks one kind through every component.
- [Other kinds](#other-kinds) covers which other artifacts can be shared.
- [Substituted module headers](#substituted-module-headers) covers a later step for Partials.
- [Plugins](#plugins) covers how plugins place and find artifacts.
- [New kinds and stages](#new-kinds-and-stages) covers adding an artifact kind or a stage.

## Shared artifacts

Sharing drops the owner from one kind's identity, apart from the artifacts that kind's rules keep per test, as [Shared mocks](#shared-mocks) keeps a mock of a generated header. Two tests whose artifacts have equal kind, origin and fingerprint then hold one identity, and so one artifact.

- **`ArtifactIdentity`.** The owner is empty for a shared identity. The fingerprint must then cover everything that can differ between tests, since nothing else keeps their artifacts apart. That includes the files an artifact's pinned includes name wherever a test's substitutes change them.
- **`Placeinator`.** A shared identity places below its own root, named by the identity's digest, in place of the test's root. The root holds that artifact and its recorded outputs alone. So a test's overlays hold exactly the files its own overlay root would, and each include reaches the file it reaches without sharing. For a shared identity the fingerprint is part of the root's name, so a changed fingerprint makes a new artifact, and the old one becomes a leftover.
- **`SearchOrderinator`.** Each test's order lists the overlay of every root its artifacts sit in. A test that reads many shared roots has a longer order, with one overlay per root for each search path that encloses its files, so about the shared mocks times their enclosing search paths.
- **`OwnershipLedger`.** An entry already holds several owners. A shared artifact becomes a leftover only when its last owner no longer plans it.
- **What stays.** Resolution, pinned includes, the stage search order table and the build plan's shape do not change.

## Shared mocks

A mock's identity is its mocked header plus its settings. Sharing it touches each component in turn.

1. **Fingerprint.** It already holds `:cmock` configuration, the generator, `:treat_inlines`, the mock include folder and, under `:treat_inlines` ↳ `:include`, the files CMock's copy pins. Under mock preprocessing it also holds the mocked header's preprocessing settings and its order's digest, which cover a test's defines and `TEST_INCLUDE_PATH()` directories.
2. **Pins.** CMock's copy pins the test's substitute for each hit, so two tests share a mock only when its copy pins the same files. A copy that pins one of the test's isolation copies names a file of that test alone, so its mock stays one per test. A copy that pins another shared copy names that mock's placement. So stage 5 forms a test's mock identities in include order, and mocked headers that include each other take one digest together.
3. **Placement.** The mock and CMock's copy sit in the identity's own root. A reach directory sits in the root of the mock it reaches. A test's isolation copies stay in its own overlay, since they depend on the test's substitutes. A mock of a generated header, such as a Partial's interface, keeps its owner and sits beside that header.
4. **Generation.** Under mock preprocessing, the preprocessed mocked header shares with its mock, so a shared mock has one input. Stages 9 and 10 run once per shared identity, and every owner's plan names the same placements.
5. **Objects.** A mock's object compiles with its test's order, so mock objects stay per test until that order no longer depends on the test.
6. **Names.** The mock include folder names the guard and lifecycle functions, and it is in the fingerprint. So only tests that write a header with the same folder share its mock.
7. **Hooks.** A shared mock generates once, so its mock generation hooks, `pre_mock_generate` and `post_mock_generate`, run once and receive every owner. Its preprocessed mocked header shares with it, so `pre_mock_preprocess` and `post_mock_preprocess` do the same.
8. **Docs.** The user docs promise each test its own generated mocks, so sharing needs a BreakingChanges entry.

## Other kinds

Each kind can be shared once its fingerprint covers every per-test setting.

- **Preprocessed mocked headers** share when their tool, flags, defines, order digest and pinned files match.
- **Objects** of one source share when their tool, flags, defines and order digest match.
- **Partials** stay per test. A Partial mock's input is the test's own interface header, and a Partial's remaps depend on the test's other Partials.

## Substituted module headers

A Partial module's header could be substituted in the overlay, as CMock's copy substitutes a mocked header. Every `#include` of the module header would then reach the Partial's version, and isolation would carry the quote rule to it. Guard spoofing and remapping would go. The change sits in `PartialRemapinator` and `Isolator` alone.

## Plugins

Plugins take every generated path from the build plan and ask `Placeinator` for any new one. A plugin never forms a path below the build root.

- **Mock hooks** receive each mock's placement and mocked header.
- **Coverage plugins** read each object's placement and source from the build plan.
- **FFF** is a mock generator. Its class is in the mock's fingerprint, and it reads the mock's placement, folder and pinned include from the plan.
- **Conventions.** A plugin calls the core component for a convention, such as `MockNaminator` for mock names, and never repeats its rule.
- **Entries, compiles and coverage.** [EDGES.md](EDGES.md#plugins) covers how a plugin adds entries, which order its compiles take and how coverage scope is set.

## New kinds and stages

A new artifact kind adds a row to the placement rules and the fingerprint table in [PLACEMENT.md](PLACEMENT.md). `Placeinator` places it, and the ledger owns it. A new stage that compiles or preprocesses adds a row to `SearchOrderinator`'s table in [STAGES.md](STAGES.md) and records its runs in the build plan.
