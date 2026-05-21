# Configuring Partials

!!! note "Documentation convention"
    `*` is a stand-in or wildcard to refer to all variations of a particular macro type.

## Enabling Partials

Enable Partials in your project YAML under the `:project:` block:

```yaml
:project:
  :use_partials: true
```

See the [:project: configuration reference](../../configuration/reference/project.md#use_partials)
for the full setting description.

Enabling `:use_partials:` automatically:

- Enables `:use_mocks` as Partials depend on CMock’s mocking infrastructure.
- Supersedes CMock’s `:treat_inlines` setting. With Partials, Ceedling manages 
  inline function exposure directly.

## `#include "ceedling.h"`

Every test file that uses Partials must include `ceedling.h` before any Partial
directive macros:

```c
#include "unity.h"
#include "ceedling.h" // Required -- defines all Partial directive macros
```

`ceedling.h` defines the `TEST_PARTIAL_*`, `MOCK_PARTIAL_*`, `*_CONFIG`, and
`PARTIAL_LOCAL_VAR()` macros. Without this include, the macros are undefined.

## Partials macro categories

See the [Partials Macros Reference](../../reference/partials-macros.md) for the complete listing.

### [Module selection](../../reference/partials-macros.md#module-selection-macros)

`TEST_PARTIAL_*_MODULE(module)` / `MOCK_PARTIAL_*_MODULE(module)`

Used as the argument to an `#include` directive to select which functions from a module 
are gathered into a Test Partial or Mock Partial and establish the base function set.
These macros also expand into the unique names of the generated Partials header files.

### [Function list configuration](../../reference/partials-macros.md#function-list-configuration-macros)

`TEST_PARTIAL_CONFIG(module, func...)` / `MOCK_PARTIAL_CONFIG(module, func...)`

Statements (not `#include` arguments) that add or subtract individual functions
from the base set established by the module selection macro.

### [Static variable access](../../reference/partials-macros.md#promoted-static-variable-access)

!!! note
    Module-scope static variables are automatically `extern`ed in a generated Partial
    and can be accessed directly in your test cases.

`PARTIAL_LOCAL_VAR(function_name, variable_name)`

Accesses a function-scoped `static` variable that Ceedling has promoted to
module scope in a generated Partial.

<br/><br/>
