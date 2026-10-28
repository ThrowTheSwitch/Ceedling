# Which Ceedling

In certain scenarios you may need to run a different version of Ceedling.
Typically, Ceedling developers need this ability. But, it could come in
handy in certain advanced Continuous Integration build scenarios or some
sort of version behavior comparison.

It’s not uncommon in Ceedling development work to have the last production 
gem installed while modifying the application code in a locally cloned 
repository. Or, you may be bouncing between local versions of Ceedling to
troubleshoot changes.

Which Ceedling handling gives you options on what gets run.

## Background

Ceedling is usually packaged and installed as a Ruby Gem. This gem ends
up installed in an appropriate place by the `gem` package installer.
Inside the gem installation is the entire Ceedling project. The `ceedling`
command line launcher lives in `bin/` while the Ceedling application lives
in `lib/`. The code in `/bin` manages lots of startup details and base
configuration. Ultimately, it then launches the main application code from
`lib/`.

The features and conventions controlling _which ceedling_ dictate which
installation of Ceedling runs your command. When they select an
installation other than the one whose `ceedling` command you ran, the launcher
hands your command off to that installation’s own launcher. See
[Hand-off](#hand-off).

!!! note "Ceedling development"
    _Which ceedling_ lets the `ceedling` command you have installed run your local
    Ceedling repository. See [Ceedling development](#ceedling-development).

## Options and precedence

When Ceedling starts up, it evaluates a handful of conditions to determine
which Ceedling location to launch.

The following are evaluated in order:

1. Environment variable `WHICH_CEEDLING`. If this environment variable is
   set, its value is used.
1. Configuration entry `:project` ↳ `:which_ceedling`. If this is set,
   its value is used.
1. The path `vendor/ceedling`. If this path exists in your working 
   directory — typically because of a `--local` vendored installation at
   project creation — its contents are used to launch Ceedling.
1. If none of the above exist, the `ceedling` launcher defaults to using
   the `lib/` directory next to the `bin/` directory from which the 
   `ceedling` launcher is running. In the typical case this is the default 
   gem installation.

!!! note "Configuration entry (2) does not make sense in some scenarios"
    `ceedling new`, `ceedling examples`, `ceedling example`, `ceedling docs`,
    and `ceedling help` outside a project have no project file to read. They
    use the environment variable or a `vendor/ceedling` path in your working
    directory.

    `ceedling upgrade` re-vendors a project from the Ceedling you run, or from
    the installation the environment variable names. It never selects a
    `vendor/ceedling` path, which inside a project is the copy being replaced.

    `ceedling version` reads your project file when one is available. See
    [Hand-off](#hand-off).

## Settings

The environment variable and configuration entry for _Which Ceedling_ can
contain two values:

1. The value `gem`, in any case, indicates that the command line `ceedling`
   launcher should run the application packaged alongside it in `lib/` (these
   paths are typically found in the gem installation location).
1. A relative or absolute path in your file system. Such a path should 
   point to the top-level directory that contains Ceedling’s `bin/` and 
   `lib/` sub-directories. A relative path is relative to your working
   directory, not to your project file.

## Hand-off

When _which ceedling_ selects an installation other than the one whose
`ceedling` command you ran, every command except `version` runs in the selected
installation. Its own launcher replaces the one you ran, in a new process,
and receives your original command line. Your command then runs wholly on the
selected installation’s code, whatever its version.

One command falls back. A `--local` copy carries no documentation bundle, so
`ceedling docs` with such a copy selected exports the documentation of the
`ceedling` command you ran instead, with a notice naming both installations.

Both sides log a notice, naming each installation and its version where
it can be read:

```
NOTICE: Ceedling launcher 1.2.2 at /var/lib/gems/3.3.0/gems/ceedling-1.2.2/ is handing off to Ceedling 1.2.0 at /home/me/project/vendor/ceedling/, which runs in its own process.
```

```
NOTICE: Ceedling 1.2.3 at /home/me/project/vendor/ceedling/ is now running, launched from Ceedling 1.2.2 at /var/lib/gems/3.3.0/gems/ceedling-1.2.2/.
```

The second notice comes only from Ceedling 1.2.2 or later. Commands that
quiet logging, such as `help` and `dumpconfig`, show neither.

A hand-off adds about 0.2 seconds to a command.

### Hand-off by condition

The table names one of five mechanisms per condition:

- **In-process:** the `ceedling` command you run does the work itself.
- **Hand-off:** the selected installation’s own launcher runs the command, in a new process.
- **Restart:** an application loaded by an older launcher restarts in its own process.
- **Report:** the `ceedling` command you run reports on both installations without running the selected one.
- **Stop:** the `ceedling` command you run stops with advice.

| Condition | Example | Mechanism | Behavior in 1.2.2+ |
|---|---|---|---|
| The selection is the installation you run | `ceedling test:all` with the gem and `:which_ceedling: gem` | In-process | Runs as before 1.2.2, with no notice |
| The selection is the same installation by another path | `:which_ceedling` names a symlink to the gem’s directory | In-process | Paths are compared after resolving links, so nothing is handed off |
| The selection is another installation | The gem’s `ceedling test:all` in a `--local` project | Hand-off | The vendored copy runs the build whole, whatever its version. Both sides log a notice. |
| A command without a project selects another installation | `ceedling new` with `WHICH_CEEDLING` set | Hand-off | The selected installation creates the project with its own code and files |
| The selection is a development checkout | The gem’s `ceedling test:all` with `:which_ceedling: /home/me/dev/ceedling` | Hand-off | The checkout’s own `bin/` and `lib/` run the command, so every change takes effect |
| `docs` selects a `--local` copy | `ceedling docs out/` in a `--local` project | In-process | Exports the documentation of the `ceedling` command you run, with a notice |
| `version` with a selection | `ceedling version` in a `--local` project | Report | Lists `Ceedling Launcher =>` and `Ceedling App =>`, each with its own version |
| `upgrade` inside a `--local` project | `ceedling upgrade .` | Stop | Refuses to upgrade the vendored copy from itself |
| The selection is a copy vendored by 1.1.0 through 1.2.1 | The gem’s `ceedling test:all` in a project vendored by 1.2.0 | Stop | Advises re-vendoring with `ceedling upgrade` |
| A launcher before 1.2.2 selects a 1.2.2+ application | A 1.2.1 gem `ceedling test:all` in a project vendoring 1.2.2 | Restart | Logs a warning, then the application runs whole. If it can’t restart, it warns and continues in the older launcher’s process. |
| A launcher before 1.2.2 runs a command without a project | A 1.2.1 gem `ceedling new` with `WHICH_CEEDLING` naming 1.2.2 | In-process | The older launcher’s own code runs the command. Upgrade the `ceedling` command you run. |

#### Example scenarios

These show when the conditions above come into play, and which goal each
serves.

**Pin a team’s project to one Ceedling version.** Create the project with
`ceedling new --local`, and commit `vendor/ceedling/`. Each teammate can then
run the project with whatever 1.2.2+ gem they have installed. The gem hands
each command off to the vendored copy, so everyone builds with the same
version. `ceedling version` confirms it under `Ceedling App =>`.

**Keep an older project on its version while you upgrade the gem.** A
project vendoring 1.2.0 still builds with 1.2.0 after you install the 1.2.2
gem, because the gem hands off to the vendored copy. If the copy was vendored
by 1.1.0 through 1.2.1, the gem stops instead. Re-vendor it as below, or
copy Unity’s `test/targets/` into the copy to keep its version.

**Upgrade a vendored project.** Run `upgrade` with the Ceedling you want,
from outside the project:

```shell
 > ceedling upgrade my_project
```

To re-vendor with an installation other than the one you run, name it in
`WHICH_CEEDLING`. Run from inside the project, `upgrade` stops, because the
vendored copy would be both source and destination.

**Create a project with a version you haven’t installed as a gem.** Point
`WHICH_CEEDLING` at an unpacked copy or a checkout of that version. `new`
hands off to it, so the project, its vendored files, and its recorded
`:ceedling_version:` all come from that version:

```shell
 > WHICH_CEEDLING=~/ceedlings/1.2.0 ceedling new --local my_project
```

**Compare versions, or find where a behavior changed.** Set `WHICH_CEEDLING`
for each run instead of editing the project file. It overrides
`:which_ceedling` and a `vendor/ceedling/` copy, so a CI job can build one
project with several versions:

```shell
 > WHICH_CEEDLING=~/ceedlings/1.2.0 ceedling test:all
 > WHICH_CEEDLING=~/ceedlings/1.2.2 ceedling test:all
```

**Run a 1.2.2 project in a CI image with an older gem.** A Docker image
shipping a 1.2.1 gem loads the vendored 1.2.2 application into its own
process. The application restarts itself, with a warning. To avoid the
restart, run the project’s `./ceedling` launch script, or upgrade the image.

**Develop Ceedling itself.** Point `:which_ceedling` at your local
repository and keep running the installed gem. See
[Ceedling development](#ceedling-development).

!!! note "The launcher you run still parses your command line"
    The `ceedling` command you run reads your command line before it hands off, so it
    rejects an option that only the selected installation knows. Run the
    selected installation’s own launcher instead, such as `./ceedling` in a
    `--local` project.

### `version`

`ceedling version` reports on both installations rather than hand off. It
reads your project file when one is available, or the one `--project` names,
along with any `--mixin`s. When the project selects another installation, it
lists `Ceedling Launcher =>` and `Ceedling App =>` separately, each with its
own version.

### Older launchers

A launcher before 1.2.2 loads the selected installation’s application into
its own process instead of handing off. A 1.2.2 or later application detects
this, logs a warning, and restarts in its own process with your original
command line. `new`, `example`, `examples`, `upgrade`, `docs`, and `help`
without a project never load the application, so these still run the older
launcher’s own code. Upgrade the `ceedling` command you run to avoid this.

### Projects vendored by 1.1.0 through 1.2.1

`ceedling new --local` in Ceedling 1.1.0 through 1.2.1 left Unity’s built-in
mixins out of the vendored copy, so that copy cannot run on its own. The
`ceedling` command you run stops with advice instead of handing off to it. Re-vendor
the project with `ceedling upgrade <project path>`.

## Ceedling development

_Which ceedling_ lets you run your local Ceedling repository on a project
from the `ceedling` command you already have installed. Set `:project` ↳
`:which_ceedling` in the project file, or `WHICH_CEEDLING`, to the path of
your repository:

```yaml
:project:
  :which_ceedling: /home/me/dev/ceedling
```

The installed `ceedling` command hands every command off to your repository’s own
`bin/ceedling`. Your command runs wholly on your repository’s `bin/` and
`lib/`, so changes in either take effect. `ceedling version` lists both
installations, your repository with its `.dev` tag.

Before 1.2.2, the installed `ceedling` command loaded your repository’s application
into its own process. Any `lib/` file it had already loaded stayed the
installed copy, so changes to those files were silently ignored.

Keep in mind:

1. **Your repository’s `bin/` runs as well as its `lib/`.** The installed
   launcher never runs your repository’s application. To exercise a
   particular launcher, run its `bin/ceedling` directly.
1. **The installed `ceedling` command parses your command line first.** It rejects a
   command or option that exists only in your repository. Run your
   repository’s launcher directly for those.
1. **Your repository must run on its own.** It needs `bin/ceedling` and its
   checked-out Git submodules, including Unity’s `test/targets/`. Otherwise
   the installed `ceedling` command stops with advice.
1. **A debugger or profiler loses the command at the hand-off.** It attaches
   to the installed `ceedling` command, whose process the hand-off replaces. Attach
   it to your repository’s launcher directly instead.
1. **A hand-off adds about 0.2 seconds** to each command.
1. **`ceedling docs` exports the installed `ceedling` command’s documentation** when
   your repository has no built `site-local/` bundle.
1. **A path that resolves to the installation you run is not handed off.**
   The plugin test suites’ `:which_ceedling: ../../../..` names the
   repository running them, so they run in-process.

To run your repository’s launcher directly:

- In Unix-like systems: `> ~/dev/ceedling/bin/ceedling <args>`.
- On Windows systems: `> ruby %USERPROFILE%\dev\ceedling\bin\ceedling <args>`.

<br/><br/>
