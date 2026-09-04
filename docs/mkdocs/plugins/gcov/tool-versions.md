# Supported tool versions

_**Last updated:**_ May 17, 2026

At the time of the last major updates to the Gcov plugin, the following notes
on version compatibility were known to be accurate.

Keep in mind that for proper functioning, you do not necessarily need to
install all the tooks the Gcov plugin works with. Depending on configuration
options documented in later sections, any of the following tool combinations
may be sufficient for your needs:

1. `gcov`
1. `gcov` + `gcovr`
1. `gcov` + `reportgenerator`
1. `gcov` + `gcovr` + `reportgenerator`

## `gcov`

The Gcov plugin is known to work with `gcov` packaged with GNU Compiler
Collection 12 through at least 15.

The maintainers of `gcov` introduced significant behavioral changes for
version 12. Previous versions of `gcov` had a simple exit code scheme with only a
single non-zero exit code upon fatal errors. Since version 12 `gcov` emits a
variety of exit codes even if the noted issue is a non-fatal error. The Gcov
plugin's logic assumes version 12 behavior and processes failure messages and
exit codes appropriately, taking into account plugin configuration options.

The Gcov plugin should be compatible with versions of `gcov` before version 12.
That is, its improved `gcov` exit handling should not be broken by the prior
simpler behavior. The Gcov plugin dependes on the `gcov` command line and has
been compatible with it as far back as `gcov` version 7.

Because long file paths are quite common in software development scenarios, by
default, the Gcov plugin depends on the `gcov` `-x` flag. This flag hashes long
file paths to ensure they are not a problem for certain platforms' file
systems. This flag became available with `gcov` version 7. We do not recommend 
using `gcov` version 6 and earlier. And, in fact, because of the Gcov plugin's 
dependence on the `gcov` `-x` flag, attempting to use it will fail.

GNU Compiler Collection 14 introduced support for Modified Condition/Decision
Coverage (MC/DC). For this reason, the Gcov plugin's own `:mcdc` option (see
[Setup](setup.md)) explicitly checks for GCC 14+. The plugin raises a clear 
error if running against an older GCC with `:mcdc` enabled. This GCC-version 
dependency is specific to `:mcdc`; it does not otherwise affect how the 
plugin processes coverage.

## `gcovr`

The Gcov plugin is known to work with `gcovr` 5.2 through `gcovr` 8.x. The
Gcov plugin supports `gcovr` command line conventions since version 4.2 and
attempts to support `gcovr` command lines before version 4.2. We recommend 
using `gcovr` 5 and later.

Several `:gcovr` options depend on a minimum `gcovr` version, checked and
enforced by this plugin (see [GCovr Configuration](gcovr.md) for each
option's own details):

| Option | Minimum `gcovr` version |
|---|---|
| `:decisions` | 5.1 |
| `:merge_mode_function` | 6.0 (ignored for earlier versions) |
| `:fail_under_decision` | 7.0 |
| `:mcdc` | 8.0 |

`gcovr` 7.0 also deprecated `:branches`, `:sort_uncovered`, and
`:sort_percentage`'s underlying flags in favor of renamed equivalents; the
plugin automatically uses whichever form of arguments your installed `gcovr` 
expects but each is enabled with the [keys documented](gcovr.md).

## `reportgenerator`

The Gcov plugin is known to work with `reportgenerator` 5.2.4. The command line
for executing `reportgenerator` that the Gcov plugin relies on has largely been
stable since version 4. We recommend using `reportgenerator` 5.0 and later.

Unlike `gcovr`, the plugin does not detect the installed `reportgenerator`
version or gate any option on it.

<br/><br/>
