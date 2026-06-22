# Example projects

Ceedling comes with entire example projects you can export. These include
reasonable approximations of real world code for learning and reference.

## How to export projects

1. Execute `ceedling examples` in your terminal to list available example 
   projects.
1. Execute `ceedling example <project> [destination]` to extract the 
   named example project to an optional destination directory (defaults
   to current working directory).

## Available projects

Once you’ve exported a project you can inspect the _project.yml_ file and 
source & test code. Run `ceedling help` from the root of an example project
to see what you can do, or just go nuts with `ceedling test:all`.

<div class="grid cards" markdown>

-   :material-memory: **[`temp_sensor`](temp-sensor.md)**

    ---

    An imagined temperature sensor project containing assertions, 
    mocks, and code techniques representative of testing in embedded 
    development. Test suite only.

-   :material-forest-outline: **[`wondrous_forest`](wondrous-forest.md)**

    ---

    An imagined forest monitoring system project illustrating the
    use of [Partials](../../testing-guide/partials/index.md) in a test suite.
    Test suite only.

-   :material-incognito: **[`cipher_quest`](cipher-quest.md)**

    ---

    An imagined spy’s command line string manipulation toolkit. This
    project can be run both as a test suite and as a release build. It
    demonstrates build options around conditional compilation (`ifdef`) 
    and defining symbols with Ceedling including with Mixins.

</div>

<br/><br/>
