# `:release_build` Configuring a release build

!!! warning "Future configuration reorganization"
    In future versions of Ceedling, release-related settings presently
    organized beneath `:project` will be renamed and migrated to this section.

## `:output`

The name of your release build binary artifact to be found in <build
path>/artifacts/release. Ceedling sets the default artifact file
extension to that as is explicitly specified in the `:extension`
section or as is system specific otherwise.

**Default**: `project.exe` or `project.out`

## `:use_assembly`

This option causes Ceedling to enable an assembler tool and add any
assembly code present in the project to the release artifact's build.

The default assembler is the GNU tool `as`; it may be overridden
in the `:tools` section.

The assembly files must be visible to Ceedling by way of `:paths` and
`:extension` settings for assembly files.

**Default**: FALSE

## `:artifacts`

By default, Ceedling copies to the _<build path>/artifacts/release_
directory the output of the release linker and (optionally) a map
file. Many toolchains produce other important output files as well.
Adding a file path to this list will cause Ceedling to copy that file
to the artifacts directory.

The artifacts directory is helpful for organizing important build
output files and provides a central place for tools such as Continuous
Integration servers to point to build output. Selectively copying
files prevents incidental build cruft from needlessly appearing in the
artifacts directory.

Note that [inline Ruby string expansion][inline-ruby-string-expansion]
is available in artifact paths.

**Default**: `[]` (empty)

## Example `:release_build` YAML blurb

```yaml
:release_build:
  :output: top_secret.bin
  :use_assembly: TRUE
  :artifacts:
    - build/release/out/c/top_secret.s19
```

[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion