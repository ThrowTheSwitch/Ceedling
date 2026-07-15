# Advanced & Troubleshooting

## Advanced usage

Details of interest for this plugin to be modified or made use of using
Ceedling's advanced features are primarily contained in
[defaults_bullseye.rb](../../snapshot/plugins/bullseye/config/defaults_bullseye.rb)
and [defaults.yml](../../snapshot/plugins/bullseye/config/defaults.yml).

## Tool wrapping and custom flags

This plugin's compiler and linker tools work by wrapping `gcc` with
Bullseye's `covc` (`covc [options] compiler args...` — anything before the
wrapped compiler's name is parsed as a `covc` option, not passed through).
Because of this, the wrapped compiler name is folded directly into each
tool's `:executable` setting (`covc -q gcc`, for example) rather than left
as a leading argument. If you override `:bullseye_compiler` or
`:bullseye_linker` in your own project configuration, keep this ordering in
mind — any flags in your own `:arguments:` list, and any flags Ceedling
injects per file or per test via `:defines`/`:flags` matchers, need to land
after the wrapped compiler's name to avoid `covc` rejecting them as
unrecognized options of its own.

## "unknown option" errors from `covc`

If `covc` reports an "unknown option" error for a flag that looks like it
should belong to `gcc` (a `-D`, `-I`, or similar), the flag likely landed
before the wrapped compiler's name in the assembled command line — see
[Tool wrapping and custom flags](#tool-wrapping-and-custom-flags) above.

## `utils:bullseye` fails to launch `CoverageBrowser`

Bullseye's `CoverageBrowser` is a GUI application with its own runtime
dependencies (GTK on Linux, for example). If it fails to launch with a
missing shared library error, install that platform's GUI toolkit
dependencies alongside Bullseye itself — this is a `CoverageBrowser`
environment requirement, independent of Ceedling or this plugin. Headless
environments (minimal Docker containers, most CI runners) are unlikely to
have these libraries and are not a typical place to run `utils:bullseye`
anyway; console summaries and the HTML report are available with no GUI
dependencies at all.

## Where source paths in the coverage data file come from

Bullseye records each source's path in its coverage data file relative to
that file's own location, and its region-based include/exclude matching
(used both directly and by this plugin's automatic report exclusions)
operates on that stored path. This plugin's coverage data file
intentionally lives at your project's root directory rather than nested
under `build/`, so that it is a common ancestor of every possible source
location (`src/`, `test/`, vendored framework sources under `build/vendor/`,
generated test runners under `build/test/`, etc.) — this is also
[Bullseye's own recommendation][bullseye-coverage-file] for where to locate
this file. If you relocate it via your own `:tools:` overrides, keep this
in mind, or region-based exclusions may stop matching as expected.

[bullseye-coverage-file]: https://www.bullseye.com/help/build-coverageFile.html

<br/><br/>
