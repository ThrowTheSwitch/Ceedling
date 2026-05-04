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
application code the `ceedling` command line handler launches.

!!! note "Ceedling development in `bin/`"
    Working on the code in Ceedling’s `bin/` and need to run it while a gem is 
    installed? You must take the additional step of specifying the path to the 
    `ceedling` launcher in your filesystem.

    In Unix-like systems:
    `> my/ceedling/changes/bin/ceedling <args>`.

    On Windows systems:
    `> ruby my\ceedling\changes\bin\ceedling <args>`.

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
    When running `ceedling new`, `ceedling examples`, or `ceedling example` 
    there is no project file to read. Similarly, `ceedling upgrade` does not 
    load a project file; it merely works with the directory structure and 
    contents of a project. In these cases, the environment variable is your
    only option to set which Ceedling to launch.

## Settings

The environment variable and configuration entry for _Which Ceedling_ can
contain two values:

1. The value `gem` indicates that the command line `ceedling` launcher 
   should run the application packaged alongside it in `lib/` (these 
   paths are typically found in the gem installation location).
1. A relative or absolute path in your file system. Such a path should 
   point to the top-level directory that contains Ceedling’s `bin/` and 
   `lib/` sub-directories.

<br/><br/>
