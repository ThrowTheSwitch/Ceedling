# Configuration

!!! tip "Annotated Sample Configuration"
    See the [annotated sample project configuration file](../snapshot/assets/project.yml)
    for a commented example of available settings.

## Project File

<div class="grid cards" markdown>

-   :material-file-cog: **[Project File Basics][project-file]**

    ---

    YAML conventions, project file structure, and special Ceedling-specific YAML
    handling.

-   :material-book-open-variant: **[Configuration Reference][configuration-reference]**

    ---

    Exhaustive documentation for all project configuration options —
    organized by section.

-   :material-file-import: **[Loading a Project Configuration][configuration-loading]**

    ---

    Load your base configuration via command line flag, environment variable,
    or default filename in your working directory.

-   :material-layers-plus: **[Mixins][mixins]**

    ---

    Merge additional configuration into your project configuration on demand
    for build variants, local overrides, CI settings, toolchain differences, etc.

</div>

## Advanced Topics

<div class="grid cards" markdown>

-   :material-clipboard-play-multiple-outline: **[Parallel Builds][parallel-builds]**

    ---

    Configure Ceedling to take advantage of multiple CPU cores for faster build
    steps and test suite execution.

-   :material-directions-fork: **[Which Ceedling?][which-ceedling]**

    ---

    Sometimes you may need to point to a different Ceedling to run.

-   :material-database: **[Global Collections][global-collections]**

    ---

    Globally available Ruby lists of paths, files, and more — useful for advanced
    project customization and plugin development.

</div>

[configuration-loading]:   loading.md
[project-file]:            project-file.md
[configuration-reference]: reference/index.md
[which-ceedling]:          which-ceedling.md
[global-collections]:      global-collections.md
[parallel-builds]:         parallel-builds.md
[mixins]:                  mixins.md

<br/><br/>
