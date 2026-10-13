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
    See [test preprocessing conventions](../../testing-guide/conventions.md#test-file-preprocessing)
    to fully understand how this setting relates to your Ceedling 
    feature selection and overall test build.

This setting forces Ceedling to use text-scanning fallback preprocessing 
mechanisms regardless of your toolchain’s preprocessor capabilities.

Forcing fallback preprocessing is useful in a handful of scenarios:

1. As a much faster alternative to full preprocessing in test projects
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
Ceedling uses less capable text-only scanning of C files instead 
attempting to accomplish as much as possible for a given test build.

When `:preprocess_force_fallback` is enabled, the start up probe of 
your toolchain’s preprocessor is entirely skipped, and Ceedling 
uses its internal text-scanning preprocessing instead.

**Default**: FALSE

<br/><br/>
