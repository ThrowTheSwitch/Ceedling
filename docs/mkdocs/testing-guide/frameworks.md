# Using Unity, CMock & CException

If you jumped ahead to this section but do not follow some of the 
lingo here, please jump back to an [earlier section for definitions
and helpful links](../overview/tools-and-frameworks.md#so-many-tools-and-acronyms).

## How Ceedling supports, well, its supporting frameworks

If you are using Ceedling for unit testing, this means you are using Unity,
the C testing framework. Unity is fully built-in and enabled for test builds.
It cannot be disabled.

If you want to use mocks in your test cases, you'll need to enable mocking 
and configure CMock with `:project` ↳ `:use_mocks` and the `:cmock` section 
of your project configuration respectively. CMock is fully supported by 
Ceedling but generally requires some set up for your project’s needs.

If you are incorporating CException into your release artifact, you'll need 
to enable exceptions and configure CException with `:project` ↳ 
`:use_exceptions` and the `:cexception` section of your project 
configuration respectively. Enabling CException makes it available in both 
release builds and test builds.

This section provides a high-level view of how the various tools become
part of your builds and fit into Ceedling’s configuration file. Ceedling’s 
configuration file is discussed in detail in the next section.

See [Unity], [CMock], and [CException]’s project documentation for all 
your configuration options. Ceedling offers facilities for providing these
frameworks their compilation and configuration settings. Discussing 
these tools and all their options in detail is beyond the scope of Ceedling 
documentation.

## Unity Configuration

Unity is wholly compiled C code. As such, its configuration is entirely 
controlled by a variety of compilation symbols. These can be configured
in Ceedling’s `:unity` project settings.

### Example Unity configurations

#### Itty bitty processor & toolchain with limited test execution options

```yaml
:unity:
  :defines:
    - UNITY_INT_WIDTH=16   # 16 bit processor without support for 32 bit instructions
    - UNITY_EXCLUDE_FLOAT  # No floating point unit
```

#### Great big gorilla processor that grunts and scratches

```yaml
:unity:
  :defines:
    - UNITY_SUPPORT_64                    # Big memory, big counters, big registers
    - UNITY_LINE_TYPE=\"unsigned int\"    # Apparently, we're writing lengthy test files,
    - UNITY_COUNTER_TYPE=\"unsigned int\" # and we've got a ton of test cases in those test files
    - UNITY_FLOAT_TYPE=\"double\"         # You betcha
```

#### Example Unity configuration header file

Sometimes, you may want to funnel all Unity configuration options into a 
header file rather than organize a lengthy `:unity` ↳ `:defines` list. Perhaps your
symbol definitions include characters needing escape sequences in YAML that are 
driving you bonkers.

```yaml
:unity:
  :defines:
    - UNITY_INCLUDE_CONFIG_H
```

```c
// unity_config.h
#ifndef UNITY_CONFIG_H
#define UNITY_CONFIG_H

#include "uart_output.h" // Helper library for your custom environment

#define UNITY_INT_WIDTH 16
#define UNITY_OUTPUT_START() uart_init(F_CPU, BAUD) // Helper function to init UART
#define UNITY_OUTPUT_CHAR(a) uart_putchar(a)        // Helper function to forward char via UART
#define UNITY_OUTPUT_COMPLETE() uart_complete()     // Helper function to inform that test has ended

#endif
```

### Routing Unity’s report output

Unity defaults to using `putchar()` from C’s standard library to 
display test results.

For more exotic environments than a desktop with a terminal — e.g. 
running tests directly on a non-PC target — you have options.

For instance, you could create a routine that transmits a character via 
RS232 or USB. Once you have that routine, you can replace `putchar()` 
calls in Unity by overriding the function-like macro `UNITY_OUTPUT_CHAR`. 

Even though this override can also be defined in Ceedling YAML, most 
shell environments do not handle parentheses as command line arguments
very well. Consult your toolchain and shell documentation.

If redefining the function and macros breaks your command line 
compilation, all necessary options and functionality can be defined in 
`unity_config.h`. Unity will need the `UNITY_INCLUDE_CONFIG_H` symbol in the
`:unity` ↳ `:defines` list of your Ceedling project file (see example above).

## CMock Configuration

CMock is enabled in Ceedling by default. However, no part of it enters a
test build unless mock generation is triggered in your test files. 
Triggering mock generation is done by an `#include` convention. See the
section on [Ceedling conventions and behaviors](conventions.md) for more.

You are welcome to disable CMock in the `:project` block of your Ceedling
configuration file. This is typically only useful in special debugging
scenarios or for Ceedling development itself.

CMock is a mixture of Ruby and C code. CMock’s Ruby components generate
C code for your unit tests. CMock’s base C code is compiled and linked into 
a test executable in the same way that any C file is — including Unity, 
CException, and generated mock C code, for that matter. 

CMock’s code generation can be configured using YAML similar to Ceedling 
itself. Ceedling’s project file is something of a container for CMock’s 
YAML configuration (Ceedling also uses CMock’s configuration, though).

See the documentation for the top-level [`:cmock`][cmock-yaml-config] 
section within Ceedling’s project file.

[cmock-yaml-config]: ../configuration/reference/cmock.md

Like Unity and CException, CMock’s C components are configured at 
compilation with symbols managed in your Ceedling project file’s 
`:cmock` ↳ `:defines` section.

### Example CMock configurations

```yaml
:project:
  # Shown for completeness -- CMock enabled by default in Ceedling
  :use_mocks: TRUE

:cmock:
  :when_no_prototypes: :warn
  :enforce_strict_ordering: TRUE
  :defines:
    # Memory alignment (packing) on 16 bit boundaries
    - CMOCK_MEM_ALIGN=1
  :plugins:
    - :ignore
  :treat_as:
    uint8:    HEX8
    uint16:   HEX16
    uint32:   UINT32
    int8:     INT8
    bool:     UINT8
```

## CException Configuration

Like Unity, CException is wholly compiled C code. As such, its 
configuration is entirely controlled by a variety of `#define` symbols. 
These can be configured in Ceedling’s `:cexception` ↳ `:defines` project 
settings.

Unlike Unity which is always available in test builds and CMock that 
defaults to available in test builds, CException must be enabled
if you wish to use it in your project.

### Example CException configurations

```yaml
:project:
  # Enable CException for both test and release builds
  :use_exceptions: TRUE

:cexception:
  :defines:
    # Possible exception codes of -127 to +127 
    - CEXCEPTION_T='signed char'

```

[Unity]: http://github.com/ThrowTheSwitch/Unity
[CMock]: http://github.com/ThrowTheSwitch/CMock
[CException]: http://github.com/ThrowTheSwitch/CException

<br/>
