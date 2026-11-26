# Conventions

Ceedling layers four conventions on resolution's answer. Each convention has one implementation here. Core stages and plugins call it and never repeat its rule.

## Contents

- [Mock names: MockNaminator](#mock-names-mocknaminator) maps a mock name and its mocked header's include text, and classifies mock includes.
- [Pairing: SourcePairinator](#pairing-sourcepairinator) finds the source that implements a header.
- [Partial modules: PartialModuleMatchinator](#partial-modules-partialmodulematchinator) finds a Partial directive's module header and source.
- [TEST_SOURCE_FILE() entries](#test_source_file-entries) covers the root-relative lookup of a build directive's source.
- [Messages](#messages) gives the shape every settled tie and failure shares.
- [Code](#code) lists the files.

## Mock names: MockNaminator

A mock name is the mocked header's name with the mock prefix before its stem and the mock suffix after it. With prefix `mock_` and suffix `_sfx`, `drivers/foo.h` gives `drivers/mock_foo_sfx.h`. `MockNaminator` maps both ways, by literal text.

- **`mock_name( header_text )`** adds the prefix and suffix to the basename and keeps every directory segment.
- **`mocked_header_text( include_text )`** removes them, or returns nil when the basename doesn't carry both.
- **Configuration.** A mock prefix and a mock suffix that are both empty fail at load, naming `:cmock` ↳ `:mock_prefix` and `:mock_suffix`, since every name would then be a mock name. Either one alone may be empty. Both are literal text, so no character in them is special.
- **Callers.** Every core stage calls it, and so do the gcov, Bullseye and FFF plugins.

### Classification

An include is a mock include only when resolution says so. Classification follows three steps.

1. **The include text resolves to a user file.** Then it is a plain include, whatever its name. A real `MockupDisplay.h` under the prefix `Mock` is a header, not a mock.
2. **Otherwise its basename carries the prefix and suffix.** Then `mocked_header_text` gives the mocked header's include text. That text resolves from the same includer through the same search order, with generated directories left out.
3. **The mocked header resolves.** Then the include is a mock include, and the mocked header is the mock's origin. If it doesn't resolve, the build fails, naming both include texts.

## Pairing: SourcePairinator

Pairing finds the source that implements a resolved header, so a test that includes `uart.h` links `uart.c`. A test's `TEST_SOURCE_FILE()` entry decides first. Otherwise three tiers run in order, and the first hit ends the search.

1. **Beside.** A source in the header's own directory, with the header's stem and a source extension.
2. **Mirror.** The header's path below its nearest base, with a source extension, found by root-relative lookup over the source roots. `include/drv/gpio.h`, below base `include`, pairs `src/drv/gpio.c`, below root `src`. A header below no base, such as one only `:files` supplies, skips this tier.
3. **Stem.** A single source anywhere with the header's stem. It pairs, and Ceedling logs a COMPLAIN NOTICE naming the header and the source. Two or more such sources fail. The error lists them and suggests naming one with `TEST_SOURCE_FILE()`.

A header no tier answers pairs no source, as a header of types or macros needs none.

- **An entry first.** A header whose stem a `TEST_SOURCE_FILE()` entry's source shares pairs that source, and no tier decides it. The stem tier never runs for that header, so a tie there never fails it.
- **Timing.** Pairing is final once the test's entries are: at stage 5 without test preprocessing, and at stage 14 with it, since the entries then arrive at stage 11. A stem-tier tie fails, and the stem tier's NOTICE logs, only then.

### Rules on the paired source

- **Mocks.** A mock removes its mocked header's paired source from the link set, by key.
- **`TEST_SOURCE_FILE()`.** A directive's source replaces the paired source of every header with its stem. A COMPLAIN NOTICE names both: the directive's source, and the source the beside or mirror tier finds. Where neither tier finds one, the NOTICE names the header and the directive's source. This lets a test link an alternate implementation.
- **Support sources.** A paired source that is also a support source links once.
- **Every mode.** Pairing runs on the resolved header, so it follows the header the compiler takes, with or without test preprocessing.

## Partial modules: PartialModuleMatchinator

A Partial directive names a module, and an `_AT` directive also names its module directory. `PartialModuleMatchinator` gives the module's header and source, which become the Partial's origin.

1. **Header by resolution.** The text `<module directory>/<module>` with each header extension, or `<module>` with each for a bare directive, resolves as a quoted include from the test file. It searches the test's own search order with generated directories left out, so another test's search paths never count. Extensions are tried in `:extension` order, and the first hit wins.
2. **Header by trailing match.** For an `_AT` directive, a trailing match of the same text over the header collection follows a miss. One candidate is the header. Two or more fail, listing them and asking for more of the module directory.
3. **Source by pairing.** `SourcePairinator` pairs the header.
4. **A module with no header.** A module has no header only when its header text, with each header extension, matches no file in the header collection: `<module directory>/<module>` by trailing match for an `_AT` directive, and `<module>` by basename for a bare one. An `_AT` directive's source is then a trailing match of `<module directory>/<module>`, with each source extension, over the source collection. A bare directive's source is a root-relative lookup of `<module>` over the source roots. A bare directive whose header the search order misses, while the header collection holds one, fails instead. The error lists those headers, and asks for a search path or an `_AT` directive.
5. **Nothing found.** No header and no source fails, naming the directive and each text tried.

- **Case.** Names compare under the key rule, so nothing folds case on its own.
- **Arguments.** The module directory and the module name are the directive's arguments as text, as the Partials directive reader gives them.
- **Recording.** The header and source are recorded in the build plan. The Partial stages and the link read them there.

## TEST_SOURCE_FILE() entries

A `TEST_SOURCE_FILE()` entry names a source relative to the source roots, as include text names a header relative to the search paths. `FileLookupinator`'s root-relative lookup answers it, and no class of its own exists.

- **Roots, in order.** The configured source roots come first, each glob in its expansion order. Implicit roots follow, in `:files` order.
- **Joins.** The entry joins each root in turn. A climbing entry collapses by the `..` rule.
- **Absolute entries** name their file directly.
- **Only collected sources answer.** A test, a support file or a framework file never does.
- **First answer wins.** Further answers log a COMPLAIN NOTICE that names the roots.
- **No answer** fails, naming the entry and every root tried.

The entry's source also replaces the paired source of every header with its stem, as [Rules on the paired source](#rules-on-the-paired-source) says. Each test checks its own entries once.

## Messages

Every settled tie and every failure in these conventions has one shape, so users meet one vocabulary. Each keeps rule 15 of [README.md](README.md#rules-every-component-keeps).

- **A settled tie** logs at COMPLAIN with a NOTICE label, at its first occurrence in a run. In plain words, it names the text as written, the file and line that hold it, the answer, the order that chose it and the other candidates.
- **A failure** names the text, the file that holds it, every candidate in the configured order, and the fix. A failure with two or more fixes, or one whose fix needs a short explanation first, takes the guidance layout.
- **Terms.** Messages use glossary terms only, such as include text, search order, root and paired source. A term of Ceedling's own, such as paired source, appears beside a clause that says what it means.

## Code

- `lib/ceedling/paths/mock_naminator.rb` holds `MockNaminator`. Its functions take the prefix and suffix and depend on no DIY object, so plugins require the file directly.
- `lib/ceedling/paths/source_pairinator.rb` and `partial_module_matchinator.rb` hold DIY objects. Each depends on `Resolvinator`, `FileLookupinator` and the logger.
- Specs: `spec/units/paths/<file>_spec.rb` for each file. The contract rows of areas `MOCK`, `LINK` and `PART` build real projects.
