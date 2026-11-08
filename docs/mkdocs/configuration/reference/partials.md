# `:partials`

**Configuring C feature extraction for Partials**

## Example `:partials` YAML

```yaml
:partials:
  # Ceiling of 1000 character blocks for buffer growth
  # 8000 = a max buffer growth to 8,000,000 characters
  :max_extraction_length: 8000

  # Write carried prototypes without GCC diagnostic pragmas
  :suppress_redundant_decls: FALSE

  # Tests define the extern variables their modules only declare
  :extern_variables: :test
```

## `:max_extraction_length`

**_Note:_** The default should be sufficient for nearly all test builds. Modification should only be necessary on error.

Building a Partial requires Ceedling to extract each C construct — a
variable declaration, a function, a macro, and so on — from your source
files one at a time. Extraction reads a construct into a growing buffer
until it finds that construct’s natural end (a terminating `;`, a closing
`}`, etc.). This setting bounds how large that buffer may grow before
extraction fails outright.

The value is a multiplier of 1000 characters, not a raw character count. For example,
`8000` means 8,000,000 characters (approx. 7.6MB). It must be a whole number no smaller
than `10` (10,000 characters).

Raise this value if Ceedling reports an extraction failure for a
legitimately large single construct in your codebase (e.g. a sizable
lookup table). Ordinarily, there’s no reason to lower it.

**Default**: 5000 (5,000,000 characters)

## `:suppress_redundant_decls`

A Partial's implementation source carries prototypes that your module's code
relies on, as described in
[What a Partial carries from your module](../../testing-guide/partials/conventions.md#what-a-partial-carries-from-your-module).
A carried prototype may repeat a declaration that one of your headers already
makes. That is valid C, but GCC reports it under `-Wredundant-decls`, and
`-Werror` turns the report into a failed build.

With this setting enabled, Ceedling wraps each run of carried prototypes in
GCC diagnostic pragmas. The pragmas quiet `-Wredundant-decls` for those lines
alone, and they sit behind `#if defined(__GNUC__)`, so other compilers never
see them. Disable the setting to write carried prototypes bare.

**Default**: `TRUE`

## `:extern_variables`

A module may declare a variable `extern` that another module defines. A test
built from a Partial may or may not link that other module, so the Partial's
implementation source decides what to write for the variable.

* `:weak` writes a weak definition. A real definition, from a linked module or
  from the test file, takes precedence over it. When nothing else defines the
  variable, the weak definition stands in, so the test links either way. The
  weak attribute sits behind `#if defined(__GNUC__)`. Other compilers get a
  plain definition, which collides with a real one. A test built with such a
  compiler that links the defining module needs `:test`.
* `:test` writes no definition. The test file, or a module the test links,
  must define the variable.

A variable your module defines itself is written where your module defines
it, whatever this setting says. A variable whose struct or union type your
module never completes gets no definition under either setting, since no
definition of an incomplete type compiles. The module that completes the type
must define the variable.

**Default**: `:weak`

<br/><br/>
