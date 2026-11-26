# Lookup

`FileLookupinator` finds a user file in a collection from text a user wrote. It does one job, by Ceedling's rules, on collections built once per build. It never looks up a generated file, since the build plan records every generated file's placement.

## Contents

- [Collections](#collections) says what a lookup can return.
- [CollectionIndex](#collectionindex) makes each lookup a hash probe.
- [Kinds of lookup](#kinds-of-lookup) covers exact, root-relative and trailing-match lookups, and who calls each.
- [Ties and misses](#ties-and-misses) covers what a lookup does with several answers or none.
- [What a lookup never answers](#what-a-lookup-never-answers) sends a build's questions about its own files to the build plan.
- [Task arguments](#task-arguments) covers task names and path tasks.
- [Code](#code) lists the files and the interface.

## Collections

A collection holds the user files of one kind. The kinds are tests, sources, headers, support files and assembly files, plus the test and release build inputs.

- **Built once per build.** `Collectinator` builds each collection at its build's collection point, from `:paths`, `:files` and every plugin's entries, and then freezes it, as [EDGES.md](EDGES.md#the-collection-point) says.
- **Order.** A collection follows `:paths` order, each glob in its expansion order, then `:files` additions in order.
- **User files only.** Framework files and generated files belong to no collection. The build plan places them.
- **Test files** are in the test collection alone, so no lookup of a source returns one, as [EDGES.md](EDGES.md#the-collection-point) says.
- **Configuration only.** A test's `TEST_INCLUDE_PATH()` directories add search paths to that test alone. They add nothing to any collection.

## CollectionIndex

Each collection has one `CollectionIndex`, built with it. No lookup scans a collection.

| Map | Key | Value |
| --- | --- | --- |
| `by_key` | a file's key | its `PathRef` |
| `by_basename` | a basename's key | the files with that basename, in collection order, each with its segments reversed |

- **An exact lookup** is one probe of `by_key`.
- **A trailing match** is one probe of `by_basename`, then a segment comparison over the files that share the basename. That is usually one or two files.
- **A root-relative lookup** is one probe of `by_key` per root.

## Kinds of lookup

A lookup takes its text as written, after the normalization a task argument gets, as [Task arguments](#task-arguments) says. It swaps no extension, and it collapses `..` by the `..` rule before anything else.

| Kind | Answer | Callers |
| --- | --- | --- |
| exact | The collected file whose key the text's path has | Absolute `TEST_SOURCE_FILE()` entries, absolute task arguments |
| root-relative | For each root of one kind, in order, the collected file the text joins to | `TEST_SOURCE_FILE()` entries, pairing's mirror tier, a bare Partial module's source |
| trailing match | Every collected file whose last segments equal the text | An `_AT` Partial module's header and source, pairing's stem tier, task arguments |

The source roots for a root-relative lookup are the configured ones in order, each glob in its expansion order, then the implicit roots in `:files` order.

## Ties and misses

A lookup ends with one answer, several or none. Only a configured order may choose among several.

- **Root-relative** lookups settle a tie by root order. The first root's answer wins, and Ceedling logs the others at COMPLAIN with a NOTICE label.
- **Trailing matches** have no order to settle a tie. Two or more candidates fail, listed in collection order.
- **A miss** fails wherever the caller needs a file. The message names the text and the kind of file looked for, such as a source file. On a root whose file system keeps case, it also names a collected file whose name differs only in case.

## What a lookup never answers

A lookup answers only from text a user wrote. Every question a build asks of its own files goes to the build plan.

- **An object's source.** The build plan records the source of each object it places, so a compile reads it there. A test's own file, its runner, a mock and a Partial are never found by name.
- **A framework file.** The build plan places Unity, CMock and CException files, so a user source named `unity.c` never meets them in a lookup.
- **A generated file.** No collection holds one.

## Task arguments

Every task that takes a file name normalizes it as its task form always has, then looks it up the same way, strictly. That covers `test:<name>`, `release:compile:<name>`, `release:assemble:<name>`, `cppcheck:<name>` and each plugin's test task.

- **Test tasks.** `test:<name>` and each plugin's test task drop one source extension from the argument, and its last segment gains the test file prefix unless it already starts with it. So `uart`, `uart.c` and `test_uart` all name `test_uart.c`, and `a/uart` names `a/test_uart.c`.
- **Extensions.** A name without one of its kind's extensions takes each in turn, and every one that matches a file is a candidate. So two test files that differ only in extension fail and list both. `release:compile:` and `release:assemble:` names end with a source or assembly extension, as their task forms require.
- **Absolute arguments** are exact lookups.
- **Other arguments** are trailing matches, so an ambiguous name fails and lists its candidates.
- **Path tasks.** `test:path[<dir>]` and each plugin's path task select a test when `Matchinator.segment_run?` finds the argument's segments, as one unbroken run, in the project-relative spelling of the test's directory. `unit`, `test/unit`, `./test/unit` and `test/unit/` all select `test/unit/test_a.c`, and none selects `test/unit_extra/test_b.c`. An absolute or climbing argument enters by `PathRef.of` and selects each test below it, by containment.

## Code

- `lib/ceedling/paths/file_lookupinator.rb` holds `FileLookupinator`, a DIY object. It depends on the frozen collections and the logger.
- `lib/ceedling/paths/collection_index.rb` holds `CollectionIndex`, an immutable value built from one collection.
- `exact( text, collection )` and `below_roots( text, roots, collection )` return their answer, or nil on a miss, and `trailing( text, collection )` returns every candidate. `below_roots` returns the answer and the further answers, so the caller can log them. Each caller raises its own message, so pairing's tiers read a miss as "try the next tier", and each task raises the messages above.
- Specs: `spec/units/paths/file_lookupinator_spec.rb` and `collection_index_spec.rb`. The index's specs check that every kind of lookup gives the same answer a full scan would.
