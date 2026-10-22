# `:test_build`

**Configuring a test build**

!!! warning "Future configuration reorganization"
    In future versions of Ceedling, test-related settings presently
    organized beneath `:project` will be renamed and migrated to this section.

## Example `:test_build` YAML

```yaml
:test_build:
  :use_assembly: TRUE
  :preprocess_force_fallback: TRUE
```

## `:use_assembly`

This option causes Ceedling to enable an assembler tool and collect a
list of assembly file sources for use in a test suite build.

The default assembler is the GNU tool `as`; like all other tools, it
may be overridden in the `:tools` section.

After enabling this feature, two conditions must be true in order to
inject assembly code into the build of a test executable:

1. The assembly files must be visible to Ceedling by way of `:paths` and
   `:extension` settings for assembly files. Here, assembly files would be
   equivalent to C code files handled in the same ways.
1. Ceedling must be told into which test executable build to insert a
   given assembly file. The easiest way to do so is with the
   [`TEST_SOURCE_FILE()` build directive macro](../../testing-guide/build-directives.md).

**Default**: FALSE

## `:preprocess_force_fallback`

!!! tip
    See [test preprocessing conventions](../../testing-guide/conventions.md#test-preprocessing)
    to fully understand how this setting relates to your Ceedling 
    feature selection and overall test build.

This setting forces Ceedling to use best-effort fallback preprocessing 
regardless of your toolchain’s preprocessor capabilities.

Forcing fallback preprocessing is useful in a handful of scenarios:

1. As a faster alternative to full preprocessing in test projects
   with relatively simple conditional compilation preprocessing needs
   (e.g. `#ifdef`). Ceedling’s advanced features require preprocessing;
   forcing fallback preprocessing can be a shortcut for faster test
   builds for some projects.
2. Overriding Ceedling’s probe of your toolchain’s preprocessor 
   features in the event of a false positive.
3. Forcing the fallback mode for self-tests of the fallback mode.

At startup, if test preprocessing is enabled, Ceedling probes the 
your toolchain’s C preprocessor tool for indications that it supports
directives-only mode. Some toolchains, particularly older variations, 
may not support this mode. If directives-only mode is not available,
Ceedling uses less capable fallback preprocessing instead, attempting 
to accomplish as much as possible for a given test build.

Fallback preprocessing is a best effort with no guarantees. Its handling of 
conditional compilation is limited. Ceedling may not choose the same 
active code your compiler would, especially where conditions depend on 
values from other files. Macro expansion is not supported at all. Code 
that relies on macros to name files, shape function signatures, or 
define test cases may not be recognized.

!!! warning "When fallback preprocessing falls short in your test build"
    Fallback preprocessing may allow mocks of something you did not 
    intend, miss a mock or source file a test build needs, or fail with 
    compilation or linking errors that are hard to trace back to 
    preprocessing. Ceedling reports problems it can detect.
    
    If a test build behaves unexpectedly, try it without forced fallback 
    preprocessing or with a toolchain that supports full preprocessing.

When `:preprocess_force_fallback` is enabled, the start up probe of 
your toolchain’s preprocessor is entirely skipped, and Ceedling 
uses fallback preprocessing instead.

**Default**: FALSE

<br/><br/>
