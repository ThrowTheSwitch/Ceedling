# Preprocessing

Ceedling runs the real C preprocessor in several different modes to answer different questions about a file. It then reconstructs a usable C file from what it learns.

A C preprocessor's job is to resolve conditionals, expand macros, and pull in the contents of every `#include`d file. Ceedling relies on a real preprocessor, typically the one built into the project's own compiler, to do this rather than reimplementing it. A real preprocessor already understands every conditional and macro trick a project might use. A hand-built approximation would not.

## Where This Fits in a Test Build

Ceedling's test pipeline calls into this subsystem at several points. It calls in to learn what a test file or header includes. It calls in again to produce a fully resolved version of a file's content, ready for further text extraction. Both the test-building and mock-generating stages of the pipeline rely on this subsystem this way, and this document explains the mechanics behind those calls rather than the pipeline's own stage order, which is documented separately alongside the pipeline itself.

Release builds do not use this subsystem at all. A release build only needs to know a file's true dependencies for staleness tracking, a simpler question answered by a lighter tool of its own.

## Reading a Line Marker

Running a C preprocessor over a file does not produce anything resembling the original file. Every `#include`d file's contents are pulled in and flattened into the same stream of text, and the whole tree of includes ends up concatenated together as one document.

To keep track of which piece of that flattened stream came from which original file, the preprocessor inserts special lines called line markers as it works. A line marker looks like this:

```
# 6 "src/module.c" 2
```

The number is a line count. The quoted text is a file name. The trailing numbers are flags describing what just happened. A flag of `1` means the preprocessor has just entered a new file, typically because of an `#include`. A flag of `2` means the preprocessor has just returned to the file it was in before. A flag of `3` means the file just entered is a system header, found through a system include path rather than a project path. These three flags are what let Ceedling walk through a flattened stream of preprocessor output and correctly attribute each line back to its real, original file.

## Finding Every Include, Accurately

Knowing exactly which headers a file includes, and whether each one is a user header or a system header, turns out to be harder than it sounds. A header protected by an include guard will not appear a second time if it happens to be reached again through a different path. This means a single pass over line markers cannot be fully trusted to report every include at the top level of a file.

Ceedling solves this with two separate preprocessor passes that are then reconciled together. The first pass runs the preprocessor in a mode meant only to report dependencies, deliberately pointed at no real project search paths at all. Because no real header can be found this way, none are ever opened, so no include guard can ever suppress anything. This pass is not troubled by nesting or guards, and it reliably reports the complete, accurate list of every include a file would pull in at its own top level, given its current macro definitions. What it cannot do is say whether any one of those includes is a user header or a system header.

The second pass runs the preprocessor with full search paths and reads the resulting line markers, exactly as described above, to learn which included files are user headers and which are system headers. This pass sees real nesting and real include guards, so its own list cannot be fully trusted as a top-level list on its own.

Reconciling the two lists together gives the best of both. The first pass supplies the authoritative list of what belongs at the top level. The second pass supplies the categorization for each entry that list already contains. Anything only the second pass reports, having been reached solely through some deeper, guarded path, is set aside. The reconciled list is also cleaned of any include referring to the file itself, and any include of a header superseded by a mock of that same header.

## Expanding a File in Full

A separate preprocessor pass, run with every macro fully expanded and every conditional fully resolved, exists for a narrower purpose. Sometimes a function's true signature is hidden behind a project's own macro, such as a macro standing in for the word `static`. A pass that merely preserves macro text intact cannot see through a substitution like that. A fully expanded pass can, because by the time it finishes running, the substitution has already happened.

This mode is used sparingly, specifically where a signature or a visibility keyword needs to be resolved with full confidence, since it is the most expensive of the preprocessor modes Ceedling relies on.

## Putting a File Back Together

Raw preprocessor output cannot be handed directly to anything expecting an ordinary, self-contained C file. It has already been described as an entire include tree flattened into one document, and none of a file's own `#include` lines survive that process, since a real preprocessor's whole purpose is to replace each one with the file's contents.

Ceedling reconstructs a usable file from this output. It walks the flattened stream watching line markers, keeping only the lines that belong to the file actually being reconstructed and discarding every line that arrived from somewhere else. It then places the file's own, original include directives back at the top, drawn from the reconciled include list described above, ahead of the recovered body text. The result reads as a complete, ordinary C file again, ready for compiling or for further text extraction, rather than as an undifferentiated stream of every header a file happens to depend on.

## Comments and Why They Go First

Several later steps read meaningful text directly out of preprocessor output. A step reading macro definitions, or reading a special marker macro placed by a test author, has to trust that whatever looks like a directive or a macro name really is one. A stray comment containing text that merely resembles a directive could otherwise be mistaken for a real one.

To avoid this, comments are found and removed from a file's preprocessed output before any of that later reading happens. The removal is careful about where a comment can legitimately begin. It never mistakes a `//` or a `/*` sitting inside a quoted string for the start of a real comment. When a multi-line comment is removed, it is replaced with the same number of blank lines it originally spanned, so the file's total line count stays exactly as it was, keeping every later line-number calculation correct.

## Finding Where a Snippet Came From

A separate, smaller capability exists for tracing a piece of already-preprocessed text back to the original line number it came from. Given a snippet of code and a body of preprocessor output containing it, this capability walks backward through the nearest line markers to work out which original file and line the snippet actually belongs to.

Ceedling's Partials feature relies on this directly. A function copied out into a generated Partial file still needs to point back at its true, original location, and this is how that original location is found.

## Caching and the Fallback Path

Running a real preprocessor is genuinely expensive, and a project's files do not change on every single build. Ceedling caches the include lists it works out for a file, and reuses a cached list rather than repeating a preprocessor pass when nothing relevant about that file has changed since the last run.

Sometimes running a real preprocessor is not possible at all, whether because a project's toolchain does not support the mode Ceedling needs, or because a particular invocation simply fails for some other reason. When this happens, Ceedling falls back to a plain text scan of the original file instead. This fallback cannot resolve a conditional the way a real preprocessor can, so its results are necessarily less certain. It exists to keep a build moving forward far enough for a test author to see what is actually going wrong, rather than leaving a build unable to proceed at all.
