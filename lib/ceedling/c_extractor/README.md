# The C Extractor

This subsystem turns raw C source text into structured data. It finds every function, variable, type, and directive a file contains. It does this without a real C compiler.

## Where This Leads

Ceedling's Partials feature is the one consumer of this subsystem. Partials pulls selected functions out of a module's real source and header. To do that safely, it needs to know exactly where each function begins and ends. It needs the same precision for variables and type definitions. This subsystem supplies that precision.

## Scanning Text with StringScanner

Most of this subsystem is built on Ruby's `StringScanner`. A reader who has never used `StringScanner` should think of it as a cursor sitting inside a string. The cursor starts at position zero. Each call asks the cursor a question about the text right in front of it, and most calls also move the cursor forward.

The main call is `scan(pattern)`. It tries to match a pattern starting exactly at the cursor. If the pattern matches, the cursor moves past the match and the matched text is returned. If the pattern does not match at that exact spot, nothing happens and the cursor stays put. This is very different from an ordinary regex search, which looks anywhere in a string for a match. `StringScanner` only ever looks right where the cursor already is.

A few other calls round out the toolkit. `check(pattern)` asks whether a pattern would match at the cursor, without moving it. This is a peek. `peek(n)` looks at the next `n` characters without consuming them. `getch` consumes exactly one character and returns it. `skip(pattern)` behaves like `scan`, but throws away the matched text and just reports how many characters it covered.

Together these calls let the c_extractor classes behave like a small hand-written parser. Some of the work happens one character at a time. Some of it happens in regex-sized bites. Both styles share the same cursor, so they compose naturally.

## A Shared Toolkit for Common Maneuvers

`CExtractorCodeText` holds the scanning moves every other class in this subsystem needs. None of these methods own a scanner. Each one is handed a scanner already sitting at the right spot, and each one moves that scanner forward.

The most important method is `collect_balanced`. It is given an open character and a matching close character, such as `{` and `}`. The scanner must already be sitting on the open character. `collect_balanced` walks forward, counting how deep it is inside nested pairs. It stops the moment the count returns to zero, at the matching close character. Along the way it treats anything inside a string or character literal as inert text, so a stray `}` inside a quoted string can never be mistaken for the end of the group. It also replaces any comment it passes through with a single space, so a brace hiding inside a comment cannot confuse the count either. This one method is what lets the subsystem find the true end of a function body, no matter how deeply that body nests loops, conditionals, or braced initializers.

Other methods in this toolkit skip a string or character literal safely, honoring backslash escapes so an escaped quote does not end the literal early. Others skip whitespace and comments, skip runs of stray semicolons, and strip away compiler-specific syntax such as `__attribute__((...))` or `__declspec(...)`. These extensions are stripped because they can otherwise be mistaken for part of a function's parameter list or a variable's declaration. Type keywords and specifiers, such as `_Atomic` and `typeof(...)`, stay.

## Recognizing Functions

`CExtractorFunctions` finds function declarations and function definitions. A declaration is a bare prototype ending in a semicolon. A definition carries a full body in braces.

The extractor walks forward from a candidate starting point, tracking how deep it is inside parentheses. It also watches for a few signs that what it is looking at is not actually a function. A name inside parentheses, as in `int (*hook)(int)`, declares a function only when a parameter list follows it, as in `int (*get(void))(int)`. Otherwise it signals a variable, such as a function pointer. A pointer inside the parameter list only declares a parameter. A `[` appearing before any `(` signals an array variable. An `=` appearing outside any parentheses signals a variable with an initializer. An asm label, as in `int g asm("sym");`, ends a declaration with a `)` of its own, so the extractor passes over it. Unexpanded macros may sit around a label, so a labeled declaration is a function's when it holds a group that opens like a parameter list. A parameter list is empty or opens with a word, and a macro's argument such as `(4)` doesn't. Once these possibilities are ruled out, the extractor knows it has found a genuine function signature.

For a definition, the extractor calls on `collect_balanced` to pull the complete function body, including every nested brace inside it. For a declaration, it confirms the signature is immediately followed by a semicolon. Either way, the function's name is pulled out with a small regex. A specifier that takes parentheses, as in `typeof(int) f(void)`, names no function, so it is passed over with its argument. Any storage-class or inline keyword before the name, such as `static`, `extern` or `inline`, is split off separately, so a caller can ask about visibility without re-parsing the signature. Every other word keeps its place, `const` and `_Noreturn` included.

## Recognizing Variables

`CExtractorDeclarations` finds variable declarations. This is a harder problem than it first appears, because a single C statement can declare more than one variable at once, as in `int a, b;`.

The extractor tracks three independent counts at the same time: parentheses, square brackets, and braces. Parentheses matter for function-pointer variables. Square brackets matter for arrays. Braces matter for initializer lists, such as `int values[] = {1, 2, 3};`. The extractor only considers the declaration finished when all three counts return to zero at a semicolon.

Fallback preprocessing leaves comments in the text. Before a declaration is checked, split, and read, each comment in it becomes a single space. String and character literals stay whole, so `"//"` survives. A record's `original` text keeps its comments, because promotion finds the statement in a function body by that text.

Once the declaration text is captured, it is split at every top-level comma into one record per variable. A comma inside parentheses, brackets, braces, or a literal separates nothing. The first declarator gives the base type, which is its text ahead of its first star, or else ahead of its name, without its initializer. Each later declarator takes that base type. Each variable's name, base type, array suffix, and any decorating keywords are then pulled out of the now-isolated text. A name may hold `$`, as GCC and Clang allow.

Compiler extensions such as attributes are stripped before a name and type are read. Type keywords such as `_Atomic`, `_Bool`, and `_Thread_local` stay, as does a type a specifier spells, such as `typeof(int)`. A generated extern repeats the type, and it must agree with the definition.

An asm label, as in `int g __asm__("sym") = 1;`, names the variable's symbol. A compiler applies it to the declarations it sees, so a test's own extern must carry it too. `CExtractorDeclarator::AsmLabel` finds a label outside brackets and ahead of any initializer. The record keeps it in `asm_label`, and its name, type, and declarator are read without it.

A function pointer or a pointer to an array names its variable inside parentheses, past any stars and qualifiers. `CExtractorDeclarator` reads that group for the function and variable extractors alike. A variable keeps the group as its `declarator`, so generated code can declare it whole, as in `extern int (*hook)(int);`.

## Recognizing Types and Directives

`CExtractorDefinitions` finds two kinds of type-level content. The first is a `typedef` statement, tracked from the `typedef` keyword through to its closing semicolon, watching only for balanced braces since a struct or union body can sit inside it. The second is a standalone `struct`, `enum`, or `union` definition, such as `struct Foo { ... };`. The same keywords lead variables and functions too, and each of those can have a braced body. The extractor reads two places to tell them apart. Ahead of the brace, it rules out what no type's head holds. A top-level `=` makes an initialized variable. A top-level `*`, or a head ending in `(void)` or a pointer group, makes a function. An attribute's own parentheses don't count. After the closing brace, it passes over attributes such as `__attribute__((packed))` and looks for a semicolon. If a variable name appears instead, as in `struct Foo { ... } var;`, the extractor backs off entirely and lets the variable extractor handle it.

`CExtractorPreprocessing` finds preprocessor directives such as `#define`, correctly following a backslash-newline so a directive spanning several physical lines is still read as one logical line. It also finds C11 and C23 `static_assert` statements and bare macro invocations at the top level. A bare invocation, such as an x-macro call, ends without a semicolon. An attribute or a specifier such as `typeof` has the same shape where it leads a declaration, so the detector leaves those for the other recognizers. Separately, and outside the main scanning loop described below, it offers the ability to find every call to a specific named macro anywhere in a body of text and to parse out that call's arguments. This capability is used directly by Ceedling's Partials feature to read its own configuration macros (documented in `partials/`).

## Assembling One Module's Worth of Content

`CExtractor` is the class other code actually calls. It reads a file, or an in-memory string, and produces one combined result describing everything of interest inside it.

Internally it works through the source from beginning to end. At each position, it tries each of the recognizers described above, in a fixed order: preprocessor directives, typedefs, static assertions, aggregate type definitions, bare macro invocations, function definitions, function declarations, and finally plain variable declarations. The first recognizer that succeeds wins, and the recognizers are ordered by the uniqueness of the features they extract. This helps ensure that features that could be confused for one another are kept distinct. Scanning for the next feature resumes at the position immediately following the previous one. If nothing recognizes the text at a given position, scanning stops there, and whatever has been gathered so far is returned.

Rather than reading an entire file into memory at once, `CExtractor` reads in modest chunks, growing its working buffer only as needed until a recognizer succeeds or the end of the file is reached. This keeps memory use reasonable even for a very large source file. A safety ceiling on how large that buffer is allowed to grow guards against a genuinely malformed or unbounded input.

## What Comes Back

Every extraction produces a `CModule`. A `CModule` groups its findings by kind: function definitions, function declarations, variable declarations, macro definitions, type definitions, and aggregate definitions. Each of these is itself a small data record. A function definition, for instance, carries its name, its signature, its body, the combined text of signature and body together, and the line number where it began in the original source.

A `CModule` also keeps one further list, called its element sequence. This list holds every item found, of every kind, in the exact order they appeared in the source file. The grouped lists are convenient when a caller wants only functions or only variables. The element sequence exists for the times a caller needs to know the true original ordering across every kind of content at once, such as when reconstructing a file that mixes types, functions, and variables together in a meaningful sequence. Two `CModule`s, such as the results of extracting a header and its matching source file, can also be merged into one `CModule`, with the first module's items placed ahead of the second's.
