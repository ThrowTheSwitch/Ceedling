# GCov

The `gcov` plugin integrates the code coverage abilities of the GNU compiler 
collection with test builds. It provides simple coverage metrics by default and
can optionally produce sophisticated coverage reports.

!!! note
    The Gcov plugin creates a duplicate test build with `gcov:` command line
    plugin tasks. [This is intentional and needed](../index.md#understanding-plugin-build-duplication).

---

<div class="grid cards" markdown>

-   :material-information-outline: **[Overview][overview]**

    ---

    How the plugin works, task types, summaries vs. reports.

-   :material-tag-outline: **[Tool Versions][tool-versions]**

    ---

    Compatibility notes for `gcov`, `gcovr`, and `ReportGenerator`.

-   :material-cog-outline: **[Set Up & Configuration][setup]**

    ---

    Toolchain requirements, enabling the plugin, and report generation setup.

-   :material-lightning-bolt: **[Example Usage][examples]**

    ---

    Examples for automatic and manual report generation.

-   :material-file-chart-outline: **[Reporting Configuration][reporting]**

    ---

    Available report types and the `:reports` YAML option.

-   :material-wrench-outline: **[GCovr Configuration][gcovr]**

    ---

    All `:gcovr` YAML options for HTML, XML, JSON, text, and common settings.

-   :material-file-cog-outline: **[ReportGenerator Configuration][reportgenerator]**

    ---

    All `:report_generator` YAML options.

-   :material-lifebuoy: **[Advanced & Troubleshooting][troubleshooting]**

    ---

    Advanced configuration and troubleshooting solutions.

</div>

[overview]:          overview.md
[tool-versions]:     tool-versions.md
[setup]:             setup.md
[examples]:          examples.md
[reporting]:         reporting.md
[gcovr]:             gcovr.md
[reportgenerator]:   reportgenerator.md
[troubleshooting]:   troubleshooting.md

<br/><br/>
