# Placement

`Placeinator` turns every artifact's identity into its location, and no other code forms a path below the build root. An identity is an artifact's kind, origin, fingerprint and owner. Generated files that user text reaches sit in each test's overlays, just ahead of the search paths they repeat, so the compiler's own search finds them. Every `#include` Ceedling writes is pinned to its file. `Isolator` plans which user files a test enters through isolation copies, and `OwnershipLedger` records what each test owns, so a delta build removes leftovers by record.

## Contents

- [Artifact identity](#artifact-identity) defines the value every placement starts from, and its fingerprints.
- [Placeinator](#placeinator) covers the layout, the rule for each artifact kind, names, path length and release placement.
- [Overlays](#overlays) covers how include text reaches mocks and substitutes, reach directories and stand-ins.
- [Pinned includes](#pinned-includes) covers the text of every `#include` Ceedling writes.
- [Isolation](#isolation) covers `Isolator` and the copies that carry the quote rule to a substitute.
- [OwnershipLedger](#ownershipledger) covers ownership records and leftovers.
- [CMock settings](#cmock-settings) covers the settings Ceedling owns.
- [Code](#code) lists the files and the interface.

## Artifact identity

An `ArtifactIdentity` is an immutable value that names one artifact. Two equal identities are one artifact, and one identity has one placement.

| Field | Holds |
| --- | --- |
| `kind` | The artifact kind, such as mock, stand-in, isolation copy, Partial, routes header, preprocessed file, runner, object, dependency file, executable, results or release target |
| `origin` | The origin's `PathRef`. A runner's and an executable's origin is the test file |
| `fingerprint` | A digest of every setting that changes the artifact |
| `owner` | The test that uses the artifact, or none for a release artifact |

- **Equality** compares the kind, the origin's key, the fingerprint and the owner.
- **The owner** is part of every test artifact's identity, so each test has its own. A later rule may drop it for a kind, as [EXTENSIONS.md](EXTENSIONS.md) describes.
- **The fingerprint** never chooses a placement. The ledger records it with the artifact, and a changed fingerprint makes the artifact stale.

### Fingerprints

A fingerprint covers settings, and the dependency cache covers input files. Together they cover everything that changes an artifact.

| Kind | Fingerprint | Input files |
| --- | --- | --- |
| mock | `:cmock` configuration less `:verbosity`, the generator, `:treat_inlines`, the mock include folder, whether it mocks a Partial | the mocked header or its preprocessed file, and each `:cmock` ↳ `:unity_helper_path` file |
| preprocessed file | the tool, flags, defines, forced fallback and the run's search order digest | the origin and every user file its line markers name |
| Partial | `:partials` configuration, the directive's selection, preprocessing settings | the module's header and source and their preprocessed files |
| object | the tool, flags, defines and the run's search order digest | the source and every header its dependency file lists |
| runner | the runner and Unity configuration, and the test's mock and include lists | the test file or its preprocessed file |
| executable | the link tool, flags and libraries | its objects |

- **Per-test settings** enter through flags, defines and the search order digest. Those cover a test's own defines, `:use_test_definition` and its `TEST_INCLUDE_PATH()` directories.
- **Unity helper files** are inputs of every mock, so editing one regenerates the mocks that use it.

## Placeinator

`Placeinator` is a DIY service with one job: `place( identity )` returns the identity's `PathRef`. Every stage, generator and plugin takes its paths from the build plan, which records each placement once.

### Layout

Each artifact kind has one root, and each test has its own directory below it, ending `_t_`.

| Root | Holds |
| --- | --- |
| overlay root, `<:mock_path>/<test>/_t_/` | mocks, CMock's copies, isolation copies and reach directories |
| stand-in root, `<build root>/test/preprocess/standins/<test>/_t_/` | stand-ins and stage 4's routes header |
| Partials root, `<build root>/test/partials/<test>/_t_/` | Partials and the routes header |
| preprocess roots, below `<build root>/test/preprocess/` | preprocessed files, by kind |
| runners root, `<build root>/test/runners/` | runners, at the test's directories |
| out root, `<build root>/<context>/out/<test>/_t_/` | objects, list files, the executable and its map |
| dependencies root, `<build root>/<context>/dependencies/<test>/_t_/` | dependency files |
| results root, `<build root>/<context>/results/` | results, at the test's directories |

`:cmock` ↳ `:mock_path` may sit outside the build root. Containment never stands for "generated": `Matchinator.generated?( path, roots )` tests a path against the build plan's generated roots.

### Each kind's place

Below its root, each kind takes one rule. A build subpath is `PathRef`'s view of a directory, with markers for paths outside the project.

- **Mock.** The build subpath of its mocked header's directory, then its mock name. A mock of a generated header, such as a Partial's interface, sits beside that header.
- **CMock's copy** under `:treat_inlines` ↳ `:include`. Beside its mock, under the mocked header's name. It is a recorded output of its mock.
- **Isolation copy.** Its origin's build subpath, under the origin's name.
- **Stand-in.** The place its mock or Partial will take, below the stand-in root.
- **Partial.** As [PARTIALS.md](PARTIALS.md#placement) says.
- **Preprocessed file.** Its origin's build subpath below its kind's preprocess root.
- **Object.** Its source's build subpath. A generated source's object takes the source's subpath below its own root. Its dependency file takes the same subpath below the dependencies root, and its list file sits beside it.
- **Results.** The test's directories below the results root, with one exact file name per result.

### Names

`MockNaminator` gives each mock name. `Placeinator` gives every other generated name: Partial file names, CMock's copy, routes headers and results. A name is never parsed back.

### Reading placements

No code derives an identity, an owner or include text from a placement. The build plan maps each placement to its identity, so a stage that holds a generated path asks the plan what it is.

### Path length

`Placeinator` checks each placement against the Windows path limit when it forms it. That covers files a tool writes, such as a dependency file, a list file and CMock's mock source, before the tool runs.

### Release placement

A release places its objects at their sources' build subpaths below `<build root>/release/out/`. Two rules hold for its outputs.

- **The target.** A relative `:release_build` ↳ `:output` joins `<build root>/release/` and must stay below the build root. A climb out of it fails at load and names an absolute `:output` as the fix. An absolute or `~` output names the target as written.
- **Artifacts.** `:release_build` ↳ `:artifacts` copy flat into `<build root>/artifacts/release/`. Two entries with one basename fail at load and list both.

## Overlays

An overlay lets include text reach a generated file exactly where the compiler would have reached its origin. The overlay of a directory is that directory's build subpath below the test's overlay root.

- **Order.** In each compile that reads generated files through user text, each search path's overlay stands just ahead of that search path. Only an overlay that holds a generated file at or below it is listed.
- **Mocks.** A mock include's mocked header text resolves through some search path to its header. The mock include's own text then joins that search path's overlay first and reaches the header's mock. So `"mock_foo.h"` and `"drivers/mock_foo.h"`, with search paths `src` and `src/drivers`, reach the one mock of `src/drivers/foo.h`.
- **Substitutes.** CMock's copy and each isolation copy carry their origin's name. Any include text that would reach the origin through a search path reaches its substitute in that path's overlay first.
- **Quote-rule origins.** A mocked header that resolved by the quote rule, from a directory that is no search path, has its overlay at the end of the order. Its mock is found there, since no user file carries a mock name.
- **One mock per header.** A test that names one mocked header by two texts has one mock, named by the text with the most path. Both texts reach it.
- **The mock include folder.** The folder of that text names the mock's include guard and lifecycle functions, and FFF's identifiers, as `:mock_name_include_folder` documents. It is part of the mock's fingerprint.

### Reach directories

A climbing mock include can leave the overlay root, as `"../../ext/mock_sensor.h"` does from `test/` for a header outside the project. Its join then needs a reach directory, which `Placeinator` forms below the overlay root.

- **The rule.** The reach directory is the mock's directory less the text's trailing named segments, plus one `_r_` segment for each `..`. Joined with the text, it gives the mock's placement.
- **Its place.** It stands in the order where the search path that answered the mocked header stands.
- **Directories.** `Placeinator` creates every directory the join passes through, since the kernel resolves each `..` on disk.

### Stand-ins

Stage 4 runs before any mock or Partial exists, so it searches the stand-in root's overlays in place of the overlay root's. It never reads a mock, copy or Partial an earlier build wrote.

- **A mock's stand-in** pins its mocked header, so stage 4 sees the header's macros as the compile will through the mock.
- **A Partial's stand-in** is blank. Stage 4's routes header routes each Partial directive to it.
- **Rewrites.** A stand-in is rewritten only when its text changes.

## Pinned includes

Every `#include` Ceedling writes is a pinned include. It names its file by absolute spelling, so the compiler opens that file with no search and nothing can shadow it.

- **Its file.** A pinned include names its resolution record's hit. Where the test substitutes the hit, it names the substitute.
- **Where they appear.** Runners pin each header the test file's records hit. Partials pin their module's includes, remapped as [PARTIALS.md](PARTIALS.md#remapping) says. The mocked header file CMock reads pins its origin's includes. Isolation copies pin their origin's includes. Routes pin their Partials.
- **A mock's own include.** A mock pins its mocked header. Under `:treat_inlines` ↳ `:include` it pins CMock's copy beside it.
- **Computed includes.** An `#include` that a macro names has no text to pin, so it stays as written and resolves through the search order. In an isolation copy, Ceedling logs each one at COMPLAIN with a WARNING label.
- **Roots.** A project root or build root whose absolute spelling holds a double quote fails at load and names the directory, since a pinned include can't hold one.

Line markers and dependency files then name each pinned file by its absolute spelling. Intake makes it a `PathRef` like any other path.

## Isolation

Isolation makes every include in a test's build reach the test's substitutes, including includes the quote rule would send to the origin. `Isolator` plans it from the build plan's resolution records, and `Placeinator` places each copy.

- **Substitutes.** Under `:treat_inlines` ↳ `:include`, CMock's copy substitutes each mocked header. Overlays carry every search-order path to it.
- **The gap.** A file beside a substituted header that quote-includes it reaches the origin, since the quote rule tries the includer's directory before any search path.
- **The rule.** Every user file the test's build enters that reaches a substituted header by the quote rule, directly or through other such files, gets an isolation copy. Each copy sits at its origin's build subpath in the overlay, with pinned includes. Overlays reach the copy, and the copy reaches the substitutes.
- **Sources.** A source in that set compiles from its copy.
- **`#line`.** Each copy opens with a `#line 1` directive naming its origin, so compiler messages, `__FILE__` and line markers name the origin.
- **Rebuilds.** The dependency cache records a copy's origin, never the copy, as the dependency of every target that entered the copy.
- **Timing.** `Isolator` plans header copies at stage 5 and source copies at stage 14, once a test's sources are final. Both precede stage 15.
- **Stability.** A copy is an artifact like any other, owned in the ledger and rewritten only when its text changes. A compile database records the compile as it ran, so a replay compiles the same copy.

`Isolator` reads the include records of every header and source the test's compiles enter. The text scan reads each such file once per change to it.

## OwnershipLedger

`OwnershipLedger` records which tests own each artifact. A delta build removes leftovers by that record and never by inference.

- **An entry** maps a placement to its identity, its owners and the stage that writes it.
- **Recorded first.** Each stage records its planned artifacts before it writes them, and the ledger saves then. A run that stops partway leaves no artifact unrecorded.
- **Saved** with the dependency cache, one ledger per build context.
- **Several owners.** An entry may list several owners, and it stays while any owner remains.

### Leftovers

A leftover is an artifact that no identity in this build owns. The ledger removes it before any later stage can search it.

- **When.** Once a test's plan for a kind is complete, the ledger removes each artifact of that kind the test owned last build and no longer plans. Stand-ins complete at stage 4, mocks, Partials, runners and header copies at stage 5, and objects, source copies and results at stage 14.
- **Owners that leave.** When the ledger loads, an owner whose test file is no longer in the test collection leaves every entry. An entry with no owner left is removed.
- **Exact names.** A rerun removes a test's results by their placements, never by a glob.
- **Only its own.** The ledger removes only files it recorded. A file it never recorded stays until a clobber.
- **Clean.** `ceedling clean` removes every recorded artifact and empties the ledger. A clobber removes the build root.

Plugin mock hooks receive each mock's placement from the build plan, so they always see the current mocks.

## CMock settings

`Placeinator` alone decides where CMock writes. Configuration strips each `:cmock` setting that would move CMock's output, and logs each strip at COMPLAIN with a NOTICE label. The stripped setting is `:subdir`. `:cmock` ↳ `:mock_path` sets the base of every overlay root. Ceedling sets each mock's output directory and its pinned include itself.

## Code

- `lib/ceedling/paths/artifact_identity.rb` holds `ArtifactIdentity`, an immutable value.
- `lib/ceedling/paths/placeinator.rb` holds `Placeinator`, a DIY object. `place( identity )` returns a `PathRef`, `overlay( dir, owner )` gives a directory's overlay, and `roots` gives the generated roots for `Matchinator.generated?`.
- `lib/ceedling/paths/isolator.rb` holds `Isolator`, a DIY object. `plan( test )` returns the isolation copies for one test's part of the build plan.
- `lib/ceedling/paths/ownership_ledger.rb` holds `OwnershipLedger`, a record that saves through the dependency cache store. `record( identities, stage: )`, `remove_leftovers( owner, kind, planned )` and `leave( owners )` are its interface.
- Specs: `spec/units/paths/<file>_spec.rb` for each file. The contract rows of areas `GEN`, `ISO`, `DELTA` and `COV` build real projects.
