# Placement

`Placeinator` turns every artifact's identity into its location, and no other code forms a path below the build root. An identity is an artifact's kind, origin, fingerprint and owner. Generated files that user text reaches sit in each test's overlays, just ahead of the search paths they repeat, so the compiler's own search finds them. Every `#include` Ceedling writes is pinned to its file. [ISOLATION.md](ISOLATION.md) covers the copies that carry the quote rule to a substitute, and [OWNERSHIP.md](OWNERSHIP.md) covers the records a delta build removes leftovers by.

## Contents

- [Artifact identity](#artifact-identity) defines the value every placement starts from, and its fingerprints.
- [Placeinator](#placeinator) covers the layout, the rule for each artifact kind, shortened bases, names, path length and release placement.
- [Overlays](#overlays) covers how include text reaches mocks and substitutes, reach directories and stand-ins.
- [Pinned includes](#pinned-includes) covers the text of every `#include` Ceedling writes.
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

A fingerprint covers settings, supplemented where needed by build details derived from them, such as an order's digest. The dependency cache covers input files. Together they cover everything that changes an artifact.

| Kind | Fingerprint | Input files |
| --- | --- | --- |
| mock | `:cmock` configuration less `:verbosity`, the generator, `:treat_inlines`, the mock include folder, whether it mocks a Partial, and under `:treat_inlines` ↳ `:include` the files CMock's copy pins | the mocked header or its preprocessed file, and each `:cmock` ↳ `:unity_helper_path` file |
| preprocessed file | the tool, flags, defines, forced fallback, the run's search order digest, and the files its pinned includes name | the origin and every user file its line markers name |
| Partial | `:partials` configuration, the directive's selection, preprocessing settings, and the files its pinned includes name | the module's header and source and their preprocessed files |
| object | the tool, flags, defines, the run's search order digest, and the files pinned by each isolation copy its compile enters | the source and every header its dependency file lists |
| runner | the runner and Unity configuration, the test's mock list, and the files its pinned includes name | the test file or its preprocessed file |
| executable | the link tool, flags and libraries | its objects |

- **Per-test settings** enter through flags, defines and the search order digest. Those cover a test's own defines, `:use_test_definition` and its `TEST_INCLUDE_PATH()` directories.
- **Pins.** An artifact whose text holds pinned includes holds the files they name in its fingerprint. A pin names the test's substitute for a hit, or another Partial module's Partial header. So when a test gains or loses a substitute or a Partial, the pins of every artifact that includes its header change, and those artifacts regenerate.
- **Pins in CMock's copy.** Under `:treat_inlines` ↳ `:include`, the file CMock reads pins the test's substitute for each hit, and CMock's copy keeps those pins. So the files a copy pins are in the fingerprints of its mock and of its preprocessed file.
- **Pins in isolation copies.** An object holds the pins of every isolation copy its compile enters, its source's own copy included. A mock that joins or leaves a test then recompiles each object whose compile enters a copy, or stops entering one.
- **Records.** A target that writes pinned includes also holds the resolution records whose hits it pins, as [RESOLUTION.md](RESOLUTION.md#resolution-records) says. A new shadowing header then makes it stale, as it does the objects that searched.
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

Below its root, each kind takes one rule. A build subpath is `PathRef`'s view of a directory, with markers for paths outside the project and for shortened bases.

- **Mock.** The build subpath of its mocked header's directory, then its mock name. A mock of a generated header, such as a Partial's interface, sits beside that header.
- **CMock's copy** under `:treat_inlines` ↳ `:include`. Beside its mock, under the mocked header's name. It is a recorded output of its mock.
- **Isolation copy.** Its origin's build subpath, under the origin's name, as [ISOLATION.md](ISOLATION.md#copies) says.
- **Stand-in.** The place its mock or Partial will take, below the stand-in root.
- **Partial.** As [PARTIALS.md](PARTIALS.md#placement) says.
- **Preprocessed file.** Its origin's build subpath below its kind's preprocess root.
- **Object.** Its source's build subpath. A generated source's object takes the source's subpath below its own root. Its dependency file takes the same subpath below the dependencies root, and its list file sits beside it.
- **Results.** The test's directories below the results root, with one exact file name per result.

### Shortened bases

A long base gives way to a short base marker in every build subpath below it. A build path then spells the marker and the mirror below the base, never the base's own path. For a vendor's include directory far outside the project, that saves most of every path below it.

- **The bases** are those of the `:paths` ↳ `:source`, `:include`, `:test` and `:support` entries, as `Collectinator` gives them at the collection point. `TEST_INCLUDE_PATH()` directories, `:files` entries and implicit roots are not bases. Only the outermost of nested bases counts, so a whole tree shares one marker and keeps its mirror below it.
- **Shorter only.** A base shortens only when its marker is shorter than its build subpath. So `src` and `test` never shorten, and a base far outside the project or deep inside it does.
- **The marker** is `_<name>_<hash>`. The name is the base's own directory name less any leading `_`, or `root` when none is left. The hash is 8 upper-case hexadecimal digits of SHA-256 of the base's release build subpath, folded as the base's key folds. So two spellings of one base give one marker, and `../../../Keil_v5/ARM/CMSIS/Include` gives a marker such as `_Include_3F2A91C0`.
- **One table.** `Placeinator` forms the table once, at the collection point, and every placement uses it. Test and release builds share it, so a base has one marker in both. The table depends only on the bases' spellings, so it holds from run to run. When a base changes, the files below it take new placements, and the ledger removes the old ones as leftovers.
- **Collisions.** Two bases whose markers would match both keep their whole build subpaths, and the pair logs once at DEBUG. So no two bases share a marker, and the build goes on.
- **Escapes.** A user directory named like a base marker gains a leading `_`, as one named like any other marker does. So no user directory's build subpath begins with a base marker.
- **Ceedling's own files.** A base inside the running Ceedling installation's own directories, by containment, already sits below the short `_ceedling_` marker and never shortens.
- **Test names.** A test's directories take its name, which never shortens. Progress output, results and plugin artifacts name the test by it.
- **Joins.** The compiler reaches a generated file in an overlay by joining include text to the overlay. A join that climbs out of a shortened base takes a reach directory, and one that enters a base from outside it follows a link, as [Overlays](#overlays) says. Every other build subpath below a base is read only by Ceedling.
- **Traceability.** `<build root>/build_bases.yml` lists each marker and its base, and `Placeinator` removes the file when no base shortens. Each marker and its base log at DEBUG.
- **User patterns.** A pattern a user writes against build paths matches each path with every marker written back as its base's build subpath. ReportGenerator's `:gcov_exclude` patterns match this way, as [EDGES.md](EDGES.md#coverage-scope) says.

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

- **Order.** In each compile that reads generated files through user text, each search path's overlay stands just ahead of that search path. An overlay is listed when a recorded include text joined to it reaches a generated file. Climbing text counts, so `"../common/mock_defs.h"` through search path `src/app` lists `src/app`'s overlay, though the mock sits in `src/common`'s. `Placeinator` creates every overlay an order lists, since the kernel climbs only out of a directory that exists.
- **Mocks.** A mock include's mocked header text resolves through some search path to its header. The mock include's own text then joins that search path's overlay first and reaches the header's mock. So `"mock_foo.h"` and `"drivers/mock_foo.h"`, with search paths `src` and `src/drivers`, reach the one mock of `src/drivers/foo.h`.
- **Substitutes.** CMock's copy and each isolation copy carry their origin's name. Any include text that would reach the origin through a search path reaches its substitute in that path's overlay first.
- **Quote-rule origins.** A mocked header that resolved by the quote rule, from a directory that is no search path, has its includer directory's overlay at the end of the order, listed and created by the same rule. Its mock is found there, since no user file carries a mock name.
- **Symlinks.** A generated file sits once, at its origin's build subpath, which follows the real spelling. Where a recorded join passes through a symlink below its search path, `Placeinator` recreates that link in each listed overlay, pointed at the overlay of the link's target. With `src/hal` → `../vendor/hal` and search path `src`, `"hal/mock_gpio.h"` joins `src`'s overlay, follows the recreated `hal` and reaches the mock in `vendor/hal`'s overlay. A linked header file gets one link for each generated file that takes its place: its substitute under the header's name, and its mock under the mock name. So one header keeps one place and one mock.
- **Shortened bases.** A join that enters a shortened base from outside it reaches the base by its own name, below its parent's build subpath. `Placeinator` makes that place a link to the base's overlay, as it recreates a symlink. With base `vendor/CMSIS/Include` shortened and search path `vendor` from a `TEST_INCLUDE_PATH()`, `"CMSIS/Include/mock_os.h"` joins `vendor`'s overlay, follows the link at `CMSIS/Include` and reaches the mock below the base's marker.
- **Links on Windows.** A directory link, whether a recreated symlink or a shortened base's, is a junction, and a recreated file link is a hard link. The build stops and names the link only when neither can be made.
- **One mock per header.** A test that names one mocked header by two texts has one mock, named by the text with the most path. Both texts reach it.
- **The mock include folder.** The folder of that text names the mock's include guard and lifecycle functions, and FFF's identifiers, as `:mock_name_include_folder` documents. It is part of the mock's fingerprint.

### Reach directories

A build subpath's leading markers stand for one directory: the project root when it has none, a shortened base, the directory a run of `_up_` climbs to, a drive or share, or the Ceedling installation. Below that directory, the build subpath repeats the real path segment for segment. So a join stays true only while it stays below the directory its search path's markers stand for. `"../../ext/mock_sensor.h"` from `test/` climbs out of the project, and `"../Source/mock_os.h"` from a shortened base's top directory climbs out of the base. Either join then needs a reach directory, which `Placeinator` forms below the overlay root.

- **Which includes.** Every climbing include text whose join climbs above the directory its search path's markers stand for, whether it is a mock include or an include that reaches a substitute. A join that leaves the overlay root is one of them.
- **The rule.** The reach directory is the generated file's directory less the text's trailing named segments, plus one `_r_` segment for each level the text climbs in all. So `"../inc/../../ext/mock_sensor.h"` takes two. Joined with the text, the reach directory gives the generated file's placement. Where the trailing segments enter a shortened base, the generated file's directory is spelled through the base's link, as [Overlays](#overlays) says, before they come off.
- **Its place.** It stands in the order where the overlay of the search path that answered stands. A reach directory for a header the quote rule answered stands with the quote-rule overlays.
- **Directories.** `Placeinator` creates every directory the join passes through, since the kernel resolves each `..` on disk.
- **Escapes.** In a test build, a user directory named like `_r_`, in any case and led by any number of `_`, gains a leading `_`, as one named like `_t_` does. So `src/_r_` has the overlay `src/__r_`, no user directory's overlay is a reach directory, and no reach directory answers an include meant for a user directory.

### Stand-ins

Stage 4 runs before any mock or Partial exists, so it searches the stand-in root's overlays in place of the overlay root's. It never reads a mock, copy or Partial an earlier build wrote.

- **Overlays below the stand-in root** follow the rules of [Overlays](#overlays): the same listing, links and reach directories, formed below the stand-in root.
- **A mock's stand-in** pins its mocked header, so stage 4 sees the header's macros as the compile will through the mock.
- **A Partial's stand-in** is blank. Stage 4's routes header routes each Partial directive to it.
- **Rewrites.** Within one build, a stand-in is rewritten only when its text changes. Stage 4 starts each run with none of the test's stand-ins from its last build, as [OWNERSHIP.md](OWNERSHIP.md#leftovers) says.

## Pinned includes

Every `#include` Ceedling writes is a pinned include, apart from the case of `#include_next` below. It names its file by absolute spelling, so the compiler opens that file with no search and nothing can shadow it.

- **Its file.** A pinned include names its resolution record's hit. Where the test substitutes the hit, it names the substitute.
- **`#include_next` headers.** No pinned include names a header whose text holds `#include_next`. A header opened by absolute spelling searches its `#include_next` as an `#include`, which can enter the header itself again. So Ceedling writes that include as written, and checks that the generated file's own stage search order reaches the same hit. Where it doesn't, the build stops and names the header and the file the generated file would reach instead.
- **Where they appear.** Runners pin each header the test file's records hit. Partials pin their module's includes, remapped as [PARTIALS.md](PARTIALS.md#remapping) says. The mocked header file CMock reads pins its origin's includes. Isolation copies pin their origin's includes. Routes pin their Partials.
- **A mock's own include.** A mock pins its mocked header. Under `:treat_inlines` ↳ `:include` it pins CMock's copy beside it.
- **Computed includes.** An `#include` that a macro names has no text to pin, so it stays as written and resolves through the search order. In an isolation copy, Ceedling logs each one at COMPLAIN with a WARNING label.
- **Roots.** A project root or build root whose absolute spelling holds a double quote fails at load and names the directory, since a pinned include can't hold one.

Line markers and dependency files then name each pinned file by its absolute spelling. Intake makes it a `PathRef` like any other path.

## CMock settings

`Placeinator` alone decides where CMock writes. Configuration strips each `:cmock` setting that would move CMock's output, and logs each strip at COMPLAIN with a NOTICE label. The stripped setting is `:subdir`. `:cmock` ↳ `:mock_path` sets the base of every overlay root. Ceedling sets each mock's output directory and its pinned include itself.

## Code

- `lib/ceedling/paths/artifact_identity.rb` holds `ArtifactIdentity`, an immutable value.
- `lib/ceedling/paths/placeinator.rb` holds `Placeinator`, a DIY object. `place( identity )` returns a `PathRef`, `overlay( dir, owner )` gives a directory's overlay, and `roots` gives the generated roots for `Matchinator.generated?`. `shortened_bases` gives the table of bases and markers, and `unshortened( path )` gives a build path with every marker written back.
- Specs: `spec/units/paths/<file>_spec.rb` for each file. The contract rows of areas `GEN` and `COV` build real projects.
