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

The maintainers of `gcov` introduced significant behavioral changes for version
12. Previous versions of `gcov` had a simple exit code scheme with only a
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

GNU Compiler Collection 14 introduced changes in how coverage is instrumented.
The `gcov` plugin implemented a revised means of processing coverage that is
forward compatible with GCC 14+ and backwards compatible to the earliest
versions of the collection.

## `gcovr`

The Gcov plugin is known to work with `gcovr` 5.2 through `gcovr` 8.x. The
Gcov plugin supports `gcovr` command line conventions since version 4.2 and
attempts to support `gcovr` command lines before version 4.2. We recommend 
using `gcovr` 5 and later.

## `reportgenerator`

The Gcov plugin is known to work with `reportgenerator` 5.2.4. The command line
for executing `reportgenerator` that the Gcov plugin relies on has largely been
stable since version 4. We recommend using `reportgenerator` 5.0 and later.

<br/><br/>
