# Reporting

Unlike Ceedling's `gcov` plugin, there's no `:reports:` list to configure or
choice of reporting utility — Bullseye is a single, self-contained toolchain,
so this plugin's reporting options are simpler: console summaries (on by
default), one HTML report format, and shared report exclusions applied to
both.

## Console Summaries

After a `bullseye:` task runs, two kinds of console output are printed
(unless disabled with `:summaries: FALSE`, see [Set Up & Configuration](setup.md#disabling-console-summaries)):

1. **Per-function detail**, one block per source file exercised by the
   tests that ran, listing each function's invocation status and
   condition/decision coverage.
1. **Whole-file totals**, a single `FUNCTIONS:`/`BRANCHES:` banner
   summarizing every function and branch recorded in the project's coverage
   data file to that point — not just what the current `bullseye:` task
   invocation touched.

## HTML Reports

This plugin generates a full interactive HTML coverage report to
`build/artifacts/bullseye/covhtml/` (open `index.html` in a browser). See
[Set Up & Configuration](setup.md#automatic-and-manual-html-report-generation)
for automatic vs. on-demand generation.

## Report Exclusions

Framework and test sources — Unity, CMock, CException, and files matching
your project's test file prefix — are excluded from both the whole-file
console totals and the HTML report, so aggregate percentages reflect your
production code. This plugin applies these exclusions automatically after
each `bullseye:` task run.

Bullseye calls the underlying concept a "region" — an inclusion or exclusion
rule that can match by filename, directory, function, or C++
class/namespace, with wildcard support. This plugin only makes use of
filename-pattern exclusions for the framework/test noise described above,
but the full region syntax is far more capable if you want to adjust
scope yourself using Bullseye's own tools directly. See
[Bullseye's region reference][bullseye-regions] for the complete syntax.

[bullseye-regions]: https://www.bullseye.com/help/ref-regions.html

<br/><br/>
