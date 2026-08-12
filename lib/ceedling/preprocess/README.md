# Preprocessing

Ceedling runs the real C preprocessor in several different modes to answer different questions about a file. It then reconstructs a usable C file from what it learns.

A C preprocessor's job is to resolve conditionals, expand macros, and pull in the contents of every `#include`d file. Ceedling relies on a real preprocessor to do this rather than reimplementing it. A real preprocessor already understands every conditional and macro trick a project might use. A hand-built approximation would not.

Ceedling asks the preprocessor four different kinds of questions, and each one gets its own mode of invocation.

- **Bare-includes mode** finds every header a file depends on, without opening a single one of them. It exists to produce a trustworthy, top-level include list.
- **Directives-only mode** resolves conditionals and follows real includes, but leaves macro directives and comments in the output untouched. It exists to categorize includes as user or system headers, and to produce a version of a file with its macros still intact for later text extraction.
- **Full-expansion mode** resolves everything a preprocessor can resolve, including every macro use in the body of a file. It exists for the case where a macro is hiding something a later step needs to see plainly, such as a function's true signature or visibility.
- **Text-scan fallback** does not invoke a preprocessor at all. It exists for the times a real preprocessor pass is unavailable or fails, scanning the original file's text directly as a less certain but always-available substitute.

Each of these is explained in its own section below, with an example of the kind of output it produces.

## Where This Fits in a Test Build

Ceedling's test pipeline reaches this subsystem through one class, `Preprocessinator`. The test pipeline calls in to learn what a test file or header includes. It calls in again to produce a fully resolved version of a file's content, ready for further text extraction. Both the test-building and mock-generating stages of the pipeline call `Preprocessinator` this way, and this document explains the mechanics behind those calls rather than the pipeline's own stage order (separately documented alongside the pipeline itself).

`Preprocessinator` does not do this work alone. It hands each piece of the job to one of several smaller classes living alongside it in this directory. Each of those classes is named where its own particular job is explained below.

Release builds do not use this subsystem at all. A release build only needs to know a file's true dependencies for staleness tracking, a simpler question answered by a lighter tool of its own.

## Reading a Line Marker

Running a C preprocessor over a file does not produce anything resembling the original file. Every `#include`d file's contents are pulled in and flattened into the same stream of text, and the whole tree of includes ends up concatenated together as one document.

To keep track of which piece of that flattened stream came from which original file, the preprocessor inserts special lines called line markers as it works. A line marker looks like this:

```
# 6 "src/module.c" 2
```

The number is a line count. The quoted text is a file name. The trailing numbers are flags describing what just happened. A flag of `1` means the preprocessor has just entered a new file, typically because of an `#include`. A flag of `2` means the preprocessor has just returned to the file it was in before. A flag of `3` means the file just entered is a system header, found through a system include path rather than a project path. These three flags are what let Ceedling walk through a flattened stream of preprocessor output and correctly attribute each line back to its real, original file. A class called `PreprocessinatorLineMarkerIncludesExtractor` is the one that actually does this walking.

## Finding Every Include, Accurately

Knowing exactly which headers a file includes, and whether each one is a user header or a system header, turns out to be harder than it sounds. A header protected by an include guard will not appear a second time if it happens to be reached again through a different path. This means a single pass over line markers cannot be fully trusted to report every include at the top level of a file.

Ceedling solves this with two separate preprocessor passes that are then reconciled together. A class called `PreprocessinatorIncludesHandler` runs both passes and hands each one's raw output to a small parser built just for it. `PreprocessinatorBareIncludesExtractor` reads the first pass's output. `PreprocessinatorLineMarkerIncludesExtractor`, already named above, reads the second.

The first pass runs the preprocessor in bare-includes mode, a mode meant only to report dependencies, deliberately pointed at no real project search paths at all. Because no real header can be found this way, none are ever opened, so no include guard can ever suppress anything. This pass is not troubled by nesting or guards, and it reliably reports the complete, accurate list of every file referenced in an `#include` directive within the preprocessed file, given its current macro definitions. What it cannot do is say whether any one of those includes is a user header or a system header.

Bare-includes mode is invoked roughly like this, with only Ceedling's own vendor path available to search:

```
gcc -E -M -MG -MP -I"build/vendor/ceedling" -D"UNIT_TEST" -nostdinc -x c "test_module.c"
```

Its output is not C code at all. It is a make-style dependency rule, listing the file itself and everything it depends on:

```
test_module.o: test_module.c unity.h module.h \
  mock_dependency.h
```

The second pass runs the preprocessor in directives-only mode, with full search paths, and reads the resulting line markers, exactly as described above, to learn which included files are user headers and which are system headers. This pass sees real nesting and real include guards, so its own list cannot be fully trusted as a top-level list on its own.

Directives-only mode is invoked with full project search paths:

```
gcc -E -I"src" -D"UNIT_TEST" -x c -fdirectives-only "test_module.c" -o "out.c"
```

Its output still looks recognizably like source. Conditionals are already resolved and includes already followed, but macro directives and comments are left exactly as written, and line markers show where each piece of text actually came from:

```
# 1 "test_module.c"
# 1 "unity.h" 1
# 1 "module.h" 1
#define MODULE_LIMIT 10 // upper bound for calculations
void module_calculate(int value);
# 2 "test_module.c" 2

void test_should_calculate_within_limit(void)
{
  TEST_ASSERT_EQUAL(20, module_calculate(2));
}
```

Reconciling the two lists together gives the best of both. The first pass supplies the authoritative list `#include` directives in the preprocessed file. The second pass supplies the categorization for each entry, user or system include, that list already contains. Anything only the second pass reports, having been reached solely through some deeper, guarded path, is set aside. The reconciled list is also cleaned of any include referring to the file itself, and any include of a header superseded by a mock of that same header.

## Expanding a File in Full

A separate preprocessor pass, run with every macro fully expanded and every conditional fully resolved, exists for a narrower purpose. Sometimes a function's true signature is hidden behind a project's own macro, such as a macro standing in for the word `static`. A pass that merely preserves macro text intact cannot see through a substitution like that. A fully expanded pass can, because by the time it finishes running, the substitution has already happened.

Full-expansion mode is invoked without the directives-only flag:

```
gcc -E -I"src" -D"UNIT_TEST" -x c "test_module.c" -o "out.c"
```

Given a project that defines `#define PRIVATE static` and a function written as `PRIVATE void module_calculate(void)`, directives-only output still shows the macro use exactly as written:

```
#define PRIVATE static
PRIVATE void module_calculate(void)
{
```

Full-expansion output shows the substitution already carried out, with the `#define` itself gone and `static` sitting plainly in its place:

```
# 3 "test_module.c"
static void module_calculate(void)
{
```

This mode is used sparingly, specifically where a signature or a visibility keyword needs to be resolved with full confidence, since it is the most expensive of the preprocessor modes Ceedling relies on.

## Putting a File Back Together

Raw preprocessor output cannot be handed directly to anything expecting an ordinary, self-contained C file.

A class called `PreprocessinatorFileAssembler` is what actually runs the preprocessor invocations shown above, and what stitches their output back into a real file afterward. For the second half of that job it leans on another class, `PreprocessinatorReconstructor`, which walks the flattened stream watching line markers, keeping only the lines that belong to the file actually being reconstructed and discarding every line that arrived from somewhere else.

Given flattened output like the following:

```
# 1 "some/file/we/do/not/want.c" 5
some_text_we_do_not_want();
# 11 "path/do/want.c" 99999
some_text_we_do_want();

some_awesome_text_we_want_so_hard();
holy_crepes_more_awesome_text();
# 3 "some/other/file/we/ignore.c" 5
ignored_text();
```

only the lines belonging to `path/do/want.c` survive the walk:

```
some_text_we_do_want();

some_awesome_text_we_want_so_hard();
holy_crepes_more_awesome_text();
```

`PreprocessinatorFileAssembler` then places the file's own, original `#include` directives back at the top, drawn from the reconciled include list described above, ahead of this recovered body text. The result reads as a complete, ordinary C file again, ready for compiling or for further text extraction.

## Comments and Why They Go First

Several later steps read meaningful text directly out of preprocessor output. A step reading macro definitions, or reading a special marker macro placed by a test author, has to trust that whatever looks like a directive or a macro name really is one. A stray comment containing text that merely resembles a directive could otherwise be mistaken for a real one.

To avoid this, a class called `PreprocessinatorCommentStripper` finds and removes comments from a file's preprocessed output before any of that later reading happens. It leans on a lower-level class, `CCommentScanner`, to do the actual finding. `CCommentScanner` is built on the same `StringScanner` approach explained in this codebase's c_extractor documentation, walking the text one position at a time rather than searching it as a whole. This approach is careful to never mistake a `//` or a `/*` sitting inside a quoted string for the start of a real comment.

Directives-only output carrying a comment like this:

```
# 1 "module.c"
#define FOO 1 // enable feature
```

has that comment blanked out, while the line marker and the directive itself are left completely untouched:

```
# 1 "module.c"
#define FOO 1
```

When a multi-line comment is removed, it is replaced with the same number of blank lines it originally spanned, so the file's total line count stays exactly as it was, keeping every later line-number calculation correct.

## Finding Where a Snippet Came From

A separate, smaller class, `PreprocessinatorCodeFinder`, exists for tracing a piece of already-preprocessed text back to the original line number it came from. Given a snippet of code and a body of preprocessor output containing it, it walks backward through the nearest line markers to work out which original file and line the snippet actually belongs to.

Ceedling's Partials feature relies on this directly. A function copied out into a generated Partial file still needs to point back at its true, original location, and this is how that original location is found.

## Caching and the Fallback Path

Running a real preprocessor is genuinely expensive, and a project's files do not change on every single build. `PreprocessinatorIncludesHandler`, already named above, also owns a small cache of the include lists it works out for a file, and reuses a cached list rather than repeating a preprocessor pass when nothing relevant about that file has changed since the last run.

Sometimes running a real preprocessor is not possible at all, whether because a project's toolchain does not support the mode Ceedling needs, or because a particular invocation simply fails for some other reason. When this happens, Ceedling falls back to a plain text scan of the original file instead, guided by a small class called `CPreprocessorConditionals`, which tracks `#ifdef`, `#ifndef`, `#if`, `#elif`, `#else`, and `#endif` state well enough to skip text that real conditional compilation would have excluded. This fallback cannot resolve a conditional with the same certainty a real preprocessor can, so its results are necessarily less certain. It exists to keep a build moving forward far enough for a test author to see what is actually going wrong, rather than leaving a build unable to proceed at all.
