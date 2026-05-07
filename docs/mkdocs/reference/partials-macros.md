# Partials Macros Reference

## Partial Directive Macros

For detailed usage guidance, conventions, and examples, see
[Partial Directive Macros](../testing-guide/partials/directives.md).

### Module selection macros

These macros expand to a **string literal** that names a generated header
file. Use them as the argument to `#include`. Requires `#include "ceedling.h"`
above their use.

`TEST_PARTIAL_*` macros expand to an implementation header filename.
`MOCK_PARTIAL_*` macros expand to a mockable interface header filename.

- **`TEST_PARTIAL_ALL_MODULE(module)`** — Select all functions in the module
  for the test Partial.

- **`TEST_PARTIAL_PUBLIC_MODULE(module)`** — Select all public
  (non-`static`, non-`inline`) functions in the module for the test Partial.

- **`TEST_PARTIAL_PRIVATE_MODULE(module)`** — Select all private (`static`
  and `inline`) functions in the module for the test Partial.

- **`TEST_PARTIAL_MODULE(module)`** — Start with an empty function set for the
  test Partial; functions must be added explicitly via `TEST_PARTIAL_CONFIG`.

- **`MOCK_PARTIAL_ALL_MODULE(module)`** — Same as `TEST_PARTIAL_ALL_MODULE`,
  but generates a mock Partial instead.

- **`MOCK_PARTIAL_PUBLIC_MODULE(module)`** — Same as `TEST_PARTIAL_PUBLIC_MODULE`,
  but generates a mock Partial instead.

- **`MOCK_PARTIAL_PRIVATE_MODULE(module)`** — Same as `TEST_PARTIAL_PRIVATE_MODULE`,
  but generates a mock Partial instead.

- **`MOCK_PARTIAL_MODULE(module)`** — Same as `TEST_PARTIAL_MODULE`, but
  generates a mock Partial instead; functions must be added explicitly via
  `MOCK_PARTIAL_CONFIG`.

### Function list configuration macros

These macros are statements (not `#include` arguments) that refine the set of
functions selected by the corresponding `*_MODULE` macro above.

- **`TEST_PARTIAL_CONFIG(module, func...)`** — Add or subtract functions from
  the test Partial's function set.

- **`MOCK_PARTIAL_CONFIG(module, func...)`** — Add or subtract functions from
  the mock Partial's function set.

Prefix a function name with `-` to exclude it from the Partial; use no prefix
or `+` to include it. A function explicitly added to one side is automatically
removed from the complementary Partial to prevent duplicate symbol linker
errors.

For the full rules on which additions and subtractions are valid with each
`*_MODULE` variant, see
[Partial Directive Macros](../testing-guide/partials/directives.md#partials-function-list-configuration-macros).

---

## Promoted Static Variable Access

For the full explanation of how Ceedling promotes function-scoped `static`
variables to module scope and when to use this macro, see
[Accessing Static Variables](../testing-guide/partials/variables.md).

### `PARTIAL_LOCAL_VAR(function_name, variable_name)`

Access a function-scoped `static` variable that Ceedling has promoted to
module scope in a generated Partial. The macro expands to the promoted
identifier `partial_<function_name>_<variable_name>`.

- Defined in `ceedling.h`; requires `#include "ceedling.h"` above its use
- Both arguments must be literal C identifiers — not strings or runtime values
- Can appear anywhere a variable name is legal: expressions, assertions,
  assignments

<br/><br/>
