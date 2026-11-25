# Writing log messages

Ceedling's log messages speak to developers who know C but not Ceedling's inner workings. Each one says in plain words what went wrong, names everything involved, and gives the fix when it knows one. These rules apply to every message a contribution or plugin adds or changes.

## Who reads them

Ceedling's users are capable software developers, and they understand C. Most have only a loose grasp of how Ceedling, CMock and test runners work. Esoteric issues in preprocessing, C macros and header shadowing are likely beyond many of them as well.

So a message gives enough to diagnose the C problem or to find the topic in the docs, and no more. It never explains how Ceedling works inside, and it never prints a Ruby class name.

## What every message says

A message opens with what went wrong. It adds why, and how to fix it, when the code that logs it knows them.

It names every specific it has:

- each file, by its path relative to the project root
- the line, when it is known
- function and symbol names
- an `#include` exactly as written, delimiters and all
- each setting by its key path, as in `:paths` ↳ `:include`, and a tool argument with ➡️, as in `:tools` ↳ `:test_linker` ↳ `:arguments` ➡️ `` `${1}` ``
- a configured entry as written
- the test it applies to

A reader can then search their project and the docs for exactly what the message names.

## Words

A plain sentence carries the meaning. Precise C words serve as its nouns, such as include text, search path, preprocessor and linker, because a C developer reads them reliably.

A term of Ceedling's own needs more. When a message uses one, such as a Partial or a paired source, a clause beside it says what it means. The reader gets the meaning and the word to search the docs for.

```
For each header a test includes, Ceedling links the source file that implements it, its paired source.
```

An `#include` is quoted as written, so its delimiters show its form. Where the form changes the outcome, the message says how, as in "an `#include` with angle brackets skips the including file's directory". Don't call an include "user" or "system". Either form can reach a project's own header.

## Two forms

A message takes one of two forms, by what the reader needs.

### Compact

The compact form serves one cause with one fix that needs no new knowledge. It is a lead line, an optional line saying why, and a `Fix:` line. Most of Ceedling's messages use it.

```
ERROR: :tools ↳ :test_compiler ↳ :executable ➡️ `gcc-14` does not exist in system search paths.
Fix: put the directory that holds gcc-14 on your PATH.
```

### Guidance

The guidance layout serves a fix that only makes sense after a short explanation of C or of Ceedling, and any message with two or more fixes. `Reportinator.generate_guidance()` builds it, so every guidance message shares one layout.

```ruby
message = Reportinator.generate_guidance(
  lead:     '#include "uart.h" in test/test_comm.c reaches no header through this test\'s search paths.',
  causes:   'A compiler joins quoted include text to the including file\'s directory, then to each search path in order.',
  notes:    ['src/hal/uart.h', 'vendor/uart/uart.h'],
  options:  ['Add the directory of the header you mean to :paths ↳ :include.',
             'Add it to this test alone with TEST_INCLUDE_PATH().'],
  closing:  'See the Ceedling docs on search paths.',
  headings: { notes: 'HEADERS NAMED uart.h' }
)
```

```
#include "uart.h" in test/test_comm.c reaches no header through this test's search paths.

HOW THIS HAPPENS: A compiler joins quoted include text to the including file's directory, then to each search path in order.

HEADERS NAMED uart.h:
• src/hal/uart.h
• vendor/uart/uart.h

OPTIONS:
1. Add the directory of the header you mean to :paths ↳ :include.
2. Add it to this test alone with TEST_INCLUDE_PATH().

See the Ceedling docs on search paths.
```

- **Sections.** The lead comes first, then causes as bullets under HOW THIS HAPPENS, notes as bullets under NOTES, numbered OPTIONS and a closing line. `headings:` renames a section, as above.
- **One item.** A lone cause or note keeps its heading on the same line, as the cause above does. A lone option drops its heading and reads as a plain sentence.
- **Conditional items.** A `nil` item drops out, so write a conditional item as `(text if condition)`. An empty section is left out.
- **Lines.** Every line starts at the left margin, and the formatter never wraps an item. Terminals wrap long lines, and indented continuations wrap badly.

## Help toward a fix

Wherever Ceedling can help a user resolve a problem, it should. The help comes from one of two places.

- **Problems Ceedling finds itself.** A configuration check, a scan of a file's text or Ceedling's own logic each knows its cause directly. The code that finds the problem builds the message, with `Reportinator.generate_guidance()` when the guidance form fits, and raises or logs it.
- **Toolchain failures.** A failed compilation, link or preprocessor run reports only in the toolchain's own words. The Build Step Doctor reads that output and its specialists add guidance on known causes. Since a specialist infers its cause, its lead hedges: "The compiler output appears to report… If so, …". `lib/ceedling/diagnostics/DOCTOR.md` explains how to add a diagnosis.

## Pointing to the docs

A message names a topic that a search of the documentation site finds easily:

```
See the Ceedling docs on TEST_SOURCE_FILE().
```

A message gives no URL. Pages move, and a reference to a topic outlasts them. Name the topic with words that appear in the docs' own headings, such as a macro name, a setting or a page title.

## Levels and labels

The verbosity level sets who sees a message. The label tells the reader what kind of message it is.

| Message | Level | Label |
| --- | --- | --- |
| A failure | raised as an exception, or logged at `Verbosity::ERRORS` | automatic, `ERROR:` |
| A problem that may give wrong results | `Verbosity::COMPLAIN` | automatic, `WARNING:` |
| Something the user should know, such as a choice Ceedling made for them | `Verbosity::COMPLAIN` | `LogLabels::NOTICE` |
| Detail for a closer look | `Verbosity::OBNOXIOUS` | as needed |

```ruby
@loginator.log( message, Verbosity::COMPLAIN, LogLabels::NOTICE )
```

At `Verbosity::COMPLAIN` the label `WARNING:` is automatic, so pass a label only when it differs, as `LogLabels::NOTICE` does.

## Repeats

A warning or notice logs once per cause in a run, at its cause's first occurrence. A cause is the same text with the same specifics. Many tests can meet one cause, and one fix serves them all. So the first message names its test, and later occurrences log only at `Verbosity::OBNOXIOUS`. Tests build in parallel, so keep the record of logged causes thread-safe.

A failure logs each time, since it names the test it stops.
