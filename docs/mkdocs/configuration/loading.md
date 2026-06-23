# Loading a Project Configuration

**You have options, my friend**

Ceedling needs a project configuration to accomplish anything for you.
Ceedling’s project configuration is a large in-memory data structure.
That data structure is loaded from a human-readable file format called
[YAML].

The [project file reference](reference/index.md) details all of Ceedling’s 
configuration options available as YAML in the content of project files.
This section explains all your options for loading and modifying the 
project configuration itself.

## Loading & Smooshing Overview

Ceedling has a certain pipeline for loading and manipulating the 
configuration it uses to build your projects. It goes something like
this:

1. Load the base project configuration from a YAML file.
1. Merge the base configuration with zero or more Mixins from YAML files.
1. Load zero or more plugins that provide default configuration values
   or alter the base project configuration.
1. Populate the configuration with default values if anything was left
   unset to ensure all configuration needed to run is present.

Ceedling provides reasonably verbose logging at startup telling you which
configuration file and Mixins were used and in what order they were merged.
Similarly, it provides fairly robust validation and warning messages to
help you catch a broken configuration and problematic combinations of
settings.

For nitty-gritty details on plugin configuration behavior, see the
_[Plugin Development Guide](../development/plugins/index.md)_

## Base Configuration Loading Options

You have three options for telling Ceedling what single base project 
configuration to load. These options are ordered below according to their
precedence. If an option higher in the list is present, it is used.

1. Command line option flags
1. Environment variable
1. Default file in working directory

### `--project` command line flags

Many of Ceedling’s [application commands](../getting-started/command-line.md) include an 
optional `--project` flag. When provided, Ceedling will load as its base 
configuration the YAML filepath provided.

Example: `ceedling --project=my/path/build.yml test:all`

!!! warning "Path relationships"
    Ceedling loads any relative paths within your configuration in
    relation to your working directory. This can cause a disconnect between
    configuration paths, working directory, and the path to your project 
    file.

If the filepath does not exist, Ceedling terminates with an error.

### Environment variable `CEEDLING_PROJECT_FILE`

If a `--project` flag is not used at the command line, but the 
environment variable `CEEDLING_PROJECT_FILE` is set, Ceedling will use
the path it contains to load your project configuration. The path can
be absolute or relative (to your working directory).

If the filepath does not exist, Ceedling terminates with an error.

### Default _project.yml_ in your working directory

If neither a `--project` command line flag nor the environment variable
`CEEDLING_PROJECT_FILE` are set, then Ceedling tries to load a file 
named _project.yml_ in your working directory.

If this file does not exist, Ceedling terminates with an error.

## Applying Mixins

Once your base configuration is loaded, [Mixins](mixins.md) provide a way
to merge additional YAML configuration into it — for build variants, local
overrides, CI settings, toolchain differences, and more. See the
[Mixins](mixins.md) page for merge rules, loading options, and examples.

[YAML]: http://en.wikipedia.org/wiki/Yaml

<br/><br/>
