# Partials Macros Reference

!!! note "Documentation convention"
    `*` is a stand-in or wildcard to refer to all variations of a particular macro type.

---

## Partial directive macros

!!! tip
    For detailed usage guidance, conventions, and examples, see [Partial Directive Macros](../testing-guide/partials/directives.md).

### Module selection macros

#### Test Partials macros

These macros expand to a string literal that names a generated header
file to be used with `#include`. `#include "ceedling.h"` must precede
their use.

* **`TEST_PARTIAL_ALL_MODULE(module)`**<br/>Select all functions in the module to be testable by Partial.
* **`TEST_PARTIAL_PUBLIC_MODULE(module)`**<br/>Select all public (non-`static`, non-`inline`) functions in the module to be testable by Partial.
* **`TEST_PARTIAL_PRIVATE_MODULE(module)`**<br/>Select all private (`static` and `inline`) functions in the module to be testable by Partial.
* **`TEST_PARTIAL_MODULE(module)`**<br/>Begin with an empty function set to be testable by Partial; functions must be added explicitly via `TEST_PARTIAL_CONFIG`.

`TEST_PARTIAL_*` macros expand to an implementation header filename.

#### Mock Partials macros

* **`MOCK_PARTIAL_ALL_MODULE(module)`**<br/>Select all functions in the module to be mockable by Partial.
* **`MOCK_PARTIAL_PUBLIC_MODULE(module)`**<br/>Select all public (non-`static`, non-`inline`) functions in the module to be mockable by Partial.
* **`MOCK_PARTIAL_PRIVATE_MODULE(module)`**<br/>Select all private (`static` and `inline`) functions in the module to be mockable by Partial.
* **`MOCK_PARTIAL_MODULE(module)`**<br/>Begin with an empty function set to be mockable by Partial; functions must be added explicitly via `MOCK_PARTIAL_CONFIG`.

`MOCK_PARTIAL_*` macros expand to a mockable interface header filename.

### Function list configuration macros

These macros are statements (not to be used with `#include` directives) 
that refine the set of functions selected by the use of any module selection 
macro above.

* **`TEST_PARTIAL_CONFIG(module, func...)`**<br/>Add or subtract functions from the test Partial’s function set.
* **`MOCK_PARTIAL_CONFIG(module, func...)`**<br/>Add or subtract functions from the mock Partial’s function set.

### Function list addition and subtraction

!!! tip
    For the full rules on which additions and subtractions are valid with 
    each `*_MODULE` variant, see
    [Partial directive macros](../testing-guide/partials/directives.md#partials-function-list-configuration-macros).

* Prefix a function name with `-` (`-func`) to exclude it from the Partial.
* Use no prefix or `+` (`+func`) to include it.

A function explicitly added to one side is automatically removed from the 
complementary Partial to prevent duplicate symbol linker errors.

---

## Promoted static variable access

!!! tip
    For the full explanation of how Ceedling promotes function-scoped `static` 
    variables to module scope and when to use this macro, see
    [Accessing Static Variables](../testing-guide/partials/variables.md).

**`PARTIAL_LOCAL_VAR(function_name, variable_name)`**

Access a function-scoped `static` variable that Ceedling has promoted to
module scope in a generated Partial. The macro expands to the promoted
identifier `partial_<function_name>_<variable_name>`.

- Defined in `ceedling.h`; requires `#include "ceedling.h"` above its use
- Both arguments must be literal C identifiers — not strings or runtime values
- Can appear anywhere a variable name is legal: expressions, assertions,
  assignments

<br/><br/>
