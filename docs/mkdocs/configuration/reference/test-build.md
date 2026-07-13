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

This option is primarily used to enable certain Ceedling self-tests,
but it may be valuable is a tool chain’s preprocessor somehow falsely
indicates that directives-only preprocessing is available.

At startup, if test preprocessing is enabled, Ceedling probes the 
C preprocessor tool for indications that it support directives-only
mode. If it does not, Ceedling uses less capable text-only scanning
of C files when directives-only C preprocessing is preferred. Some 
toolchains, particularly older variations, may not support this mode.

This flag forces Ceedling to use text-scanning fallback mechanisms
regardless of preprocessor capabilities (the start up probe is 
entirely skipped.)

**Default**: FALSE

<br/><br/>
