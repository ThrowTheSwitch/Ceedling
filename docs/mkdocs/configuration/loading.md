# How to Load a Project Configuration

** You have options, my friend **

Ceedling needs a project configuration to accomplish anything for you.
Ceedling's project configuration is a large in-memory data structure.
That data structure is loaded from a human-readable file format called
[YAML].

The next section details Ceedling's project configuration options in 
available through YAML. This section explains all your options for 
loading and modifying the project configuration itself.

## Overview of Project Configuration Loading & Smooshing

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
_[Plugin Development Guide](../development/plugin-development-guide.md)_

## Options for Loading Your Base Project Configuration

You have three options for telling Ceedling what single base project 
configuration to load. These options are ordered below according to their
precedence. If an option higher in the list is present, it is used.

1. Command line option flags
1. Environment variable
1. Default file in working directory

### `--project` command line flags

Many of Ceedling's [application commands](../getting-started/command-line.md) include an 
optional `--project` flag. When provided, Ceedling will load as its base 
configuration the YAML filepath provided.

Example: `ceedling --project=my/path/build.yml test:all`

_NOTE:_ Ceedling loads any relative paths within your configuration in
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

## Applying Mixins to Your Base Project Configuration

Once you have a base configuation loaded, you may want to modify it for
any number of reasons. Some example scenarios:

* A single project actually contains mutiple build variations. You would
  like to maintain a common configuration that is shared among build
  variations with each build variation's differences maintained separately.
* Your repository contains the configuration needed by your Continuous
  Integration server setup, but this is not fun to run locally. You would
  like to modify the configuration locally with configuration details 
  maintained by you external to your locally cloned repository.
* Ceedling's default `gcc` tools do not work for your project needs. You
  would like the complex tooling configurations you most often need to
  be maintained separately and shared among projects.

Mixins allow you to merge configuration with your project configuration
just after the base project file is loaded. The merge is so low-level
and generic that you can, in fact, load an empty base configuration 
and merge in entire project configurations through mixins.

## Desgning for Mixins Plus Merging Rules

Merging of any sort tends to be hard to do well. It's tricky at a 
code-level, yes, but, just as importantly, merging can be hard to grasp in
your head.

The brief sections that follow provide an overview of our recommended
design approach and the merge rules at play.

_**Note:**_ `ceedling dumpconfig` can be invaluable in developing and 
troubleshooting your mixins. The `dumpconfig` application command will 
load your mixins just as a build would but produce the resulting merged
configuration for inspection in a YAML file you specify.

### Design for additive Mixin merges

Generally speaking, the simplest way to conceive of managing your project
configuration with mixins is to design for an additive merge. This means
each mixin is successively adding something to your base configuration. 
In certain scenarios it is possible to overwrite configuration values with 
mixin values (see the rules that follow), but an additive merge is 
probably easier to understand and create.

At a high level, additive merges can be constructed like this:

1. Plan to add to lists with mixins. Path collections, plugins, and 
   tool flags & compilation symbols are all examples of lists that
   can be added to. Other lists exist in a project configuration too —
   many within containing configuration entires. Add paths, plugins, and 
   flags & symbols to your base configuration that are in common to all 
   your buid variations and then customize the lists by adding to them 
   with mixins.
1. Leave entire sections in your base configuration blank and fill them 
   out by merging mixins. With this strategy, you might configure all
   the basics in a base project configuration but merge into it the 
   path collections, tool configurations, and compilation symbols you need
   for a specific project.

### Mixins deep merge rules

Mixins are merged in a specific order. See the documentation sections 
following the examples for details.

Smooshing of mixin configurations into the base project configuration
follows a few basic rules:

* If a configuration key/value pair does not already exist at the time
  of merging, the mixin key/value pair is added to the configuration.
* If a container — e.g. list or hash — already exists at the time of a
  merge, the contents are _combined_.
   * In the case of lists, merged list values are added to the end of 
     the existing list.
   * If the configuration contains a list but the mixin value is a 
     different type, it is added to the list. The typical case is a 
     list of strings growing with an additional single string. Note 
     that the reverse case is not true. A configuration containing a
     single value and a mixin containing a list, will trigger the
     following rule.
* If a simple value — e.g. boolean, string, numeric — already exists 
  in the configuration at the time of merging, that value is replaced 
  by the mixin value being merged. That merge is accompanied with a 
  warning log entry to highlight what has happened.

_**Note:**_ That second bullet can have a significant impact on how your
various project configuration paths — including those used for header 
search paths — are ordered. In brief, the contents of your `:paths` 
from your base configuration will come first followed by any additions
from your mixins. See the section [Search Paths for Test Builds](../testing-guide/conventions.md#search-paths-for-test-builds)
for more.

## Mixins Example: Our Example Scenario

Let's start with an example that helps explain how mixins are merged.
Then, the documentation sections that follow will discuss everything
in detail.

In this example, we will load a base project configuration and then
apply three mixins using each of the available means — command line,
envionment variable, and `:mixins` section in the base project 
configuration file.

### Example environment variable

`CEEDLING_MIXIN_1` = `./env.yml`

### Example command line

`ceedling --project=base.yml --mixin=support/mixins/cmdline.yml <tasks>`

_NOTE:_ The `--mixin` flag supports more than filepaths and can be used 
multiple times in the same command line for multiple mixins (see later 
documentation section). 

The example command line above will produce the following logging output
when verbosity is increased beyond the default.

```
🚧 Loaded project configuration from command line argument using base.yml
 + Merging command line mixin using support/mixins/cmdline.yml
 + Merging CEEDLING_MIXIN_1 mixin using ./env.yml
 + Merging project configuration mixin using ./enabled.yml
```

_Notes_

* The logging output above referencing _enabled.yml_ comes from the 
  `:mixins` section within the base project configuration file provided below.
* The resulting configuration in this example is missing settings required
  by Ceedling. This will cause a validation build error that is not shown
  here.

### Mixins Example: Configuration files

#### _base.yml_ — Our base project configuration file

Our base project configuration file:

1. Sets up a configuration file-based mixin. Ceedling will look for a mixin
   named _enabled_ in the specified load paths. In this simple configuration
   that means Ceedling looks for and merges _support/mixins/enabled.yml_.
1. Creates a `:project` section in our configuration.
1. Creates a `:plugins` section in our configuration and enables the standard 
   console test report output plugin.

```yaml
:mixins:              # `:mixins` section only recognized in base project configuration
  :enabled:           # `:enabled` list supports names and filepaths
    - enabled         # Ceedling looks for name as enabled.yml in load paths and merges if found
  :load_paths:
    - support/mixins

:project:
  :build_root: build/

:plugins:
  :enabled:
    - report_tests_pretty_stdout
```

#### _support/mixins/cmdline.yml_ — Mixin via command line filepath flag

This mixin will merge a `:project` section with the existing `:project`
section from the base project file per the deep merge rules above.

```yaml
:project:
  :use_test_preprocessor: :all
  :test_file_prefix: Test
```

#### _env.yml_ — Mixin via environment variable filepath

This mixin will merge a `:plugins` section with the existing `:plugins`
section from the base project file per the deep merge rules (noted 
after the examples).

```yaml
:plugins:
  :enabled:
    - compile_commands_json_db
```

#### _support/mixins/enabled.yml_ — Mixin via base project configuration file `:mixins` section

This mixin listed in the base configuration project file will merge
`:project` and `:plugins` sections with those that already exist from
the base configuration plus earlier mixin merges per the deep merge 
rules (noted after the examples).

```yaml
:project:
  :use_test_preprocessor: :none

:plugins:
  :enabled:
    - gcov
```

### Mixins Example: Resulting project configuration

Behold the project configuration following mixin merges:

```yaml
:project:
  :build_root: build/           # From base.yml
  :use_test_preprocessor: :all  # Value in support/mixins/cmdline.yml overwrote value from support/mixins/enabled.yml
  :test_file_prefix: Test       # Added to :project from support/mixins/cmdline.yml

:plugins:
  :enabled:                       # :plugins ↳ :enabled from two mixins merged with oringal list in base.yml
    - report_tests_pretty_stdout  # From base.yml
    - compile_commands_json_db    # From env.yml
    - gcov                        # From support/mixins/enabled.yml

# NOTE: Original :mixins section is removed from resulting config
```

## Options for Loading Mixins

You have three options for telling Ceedling what mixins to load. These 
options are ordered below according to their precedence. A Mixin higher
in the list is merged earlier. In addition, options higher in the list
force duplicate mixin filepaths to be ignored lower in the list.

Unlike base project file loading that resolves to a single filepath, 
multiple mixins can be specified using any or all of these options.

1. Command line option flags
1. Environment variables
1. Base project configuration file entries

### `--mixin` command line flags

As already discussed above, many of Ceedling's application commands 
include an optional `--project` flag. Most of these same commands 
also recognize optional `--mixin` flags. Note that `--mixin` can be 
used multiple times in a single command line.

When provided, Ceedling will load the specified YAML file and merge
it with the base project configuration.

A Mixin flag can contain one of two types of values:

1. A filename or filepath to a mixin yaml file. A filename contains
   a file extension. A filepath includes a leading directory path.
1. A simple name (no file extension and no path). This name is used
   as a lookup in Ceedling's mixin load paths.

Example: `ceedling --project=build.yml --mixin=foo --mixin=bar/mixin.yaml test:all`

Simple mixin names (#2 above) require mixin load paths to search.
A default mixin load path is always in the list and points to within
Ceedling itself (in order to host eventual built-in mixins like 
built-in plugins). User-specified load paths must be added through 
the `:mixins` section of the base configuration project file. See 
the [documentation for the `:mixins` section of your project 
configuration][mixins-config-section] for more details.

Order of precedence is set by the command line mixin order 
left-to-right.

Filepaths may be relative (in relation to the working directory) or
absolute.

If the `--mixin` filename or filepath does not exist, Ceedling 
terminates with an error. If Ceedling cannot find a mixin name in 
any load paths, it terminates with an error.

[mixins-config-section]: #base-project-configuration-file-mixins-section-entries

### Mixin environment variables

Mixins can also be loaded through environment variables. Ceedling
recognizes environment variables with a naming scheme of 
`CEEDLING_MIXIN_#`, where `#` is any number greater than 0.

Precedence among the environment variables is a simple ascending
sort of the trailing numeric value in the environment variable name.
For example, `CEEDLING_MIXIN_5` will be merged before 
`CEEDLING_MIXIN_99`.

Mixin environment variables only hold filepaths. Filepaths may be 
relative (in relation to the working directory) or absolute.

If the filepath specified by an environment variable does not exist,
Ceedling terminates with an error.

### Base project configuration file `:mixins` section entries

Ceedling only recognizes a `:mixins` section in your base project
configuration file. A `:mixins` section in a mixin is ignored. In addition,
the `:mixins` section of a base project configuration file is filtered
out of the resulting configuration.

The `:mixins` configuration section can contain up to two subsections.
Each subsection is optional.

* `:enabled`

  An optional array comprising (A) mixin filenames/filepaths and/or 
  (B) simple mixin names.

  1. A filename contains a file extension. A filepath includes a 
     directory path. The file content is YAML.
  1. A simple name (no file extension and no path) is used
     as a file lookup among any configured load paths (see next
     section) and as a lookup name among Ceedling's built-in mixins
     (currently none).

  Enabled entries support [inline Ruby string expansion][inline-ruby-string-expansion].

  **Default**: `[]`

* `:load_paths`

  Paths containing mixin files to be searched via mixin names. A mixin
  filename in a load path has the form _<name>.yml_ by default. If
  an alternate filename extension has been specified in your project
  configuration (`:extension` ↳ `:yaml`) it will be used for file
  lookups in the mixin load paths instead of _.yml_.

  Searches start in the path at the top of the list.

  Both mixin names in the `:enabled` list (above) and on the command
  line via `--mixin` flag use this list of load paths for searches.

  Load paths entries support [inline Ruby string expansion][inline-ruby-string-expansion].
  
  **Default**: `[]`

Example `:mixins` YAML blurb:

```yaml
:mixins:
  :enabled:
    - foo            # Search for foo.yml in proj/mixins & support/ and 'foo' among built-in mixins
    - path/bar.yaml  # Merge this file with base project conig
  :load_paths:
    - proj/mixins
    - support
```

Relating the above example to command line `--mixin` flag handling:

* A command line flag of `--mixin=foo` is equivalent to the `foo` 
  entry in the `:enabled` mixin configuration.
* A command line flag of `--mixin=path/bar.yaml` is equivalent to the 
  `path/bar.yaml` entry in the `:enabled` mixin configuration.
* Note that while command line `--mixin` flags work identically to 
  entries in `:mixins` ↳ `:enabled`, they are merged first instead of 
  last in the mixin precedence.

[YAML]: http://en.wikipedia.org/wiki/Yaml
[inline-ruby-string-expansion]: project-file.md#inline-ruby-string-expansion

<br/>
