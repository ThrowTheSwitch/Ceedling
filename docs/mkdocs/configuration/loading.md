# How to Load a Project Configuration

**You have options, my friend**

Ceedling needs a project configuration to accomplish anything for you.
Ceedling’s project configuration is a large in-memory data structure.
That data structure is loaded from a human-readable file format called
[YAML].

The next section details Ceedling’s project configuration options in 
available through YAML. This section explains all your options for 
loading and modifying the project configuration itself.

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

## Applying Mixins to Base Configuration

Once you have a base configuation loaded, you may want to modify it for
any number of reasons. Some example scenarios:

* A single project actually contains mutiple build variations. You would
  like to maintain a common configuration that is shared among build
  variations with each build variation’s differences maintained separately.
* Your repository contains the configuration needed by your Continuous
  Integration server setup, but this is not fun to run locally. You would
  like to modify the configuration locally with configuration details 
  maintained by you external to your locally cloned repository.
* Ceedling’s default `gcc` tools do not work for your project needs. You
  would like the complex tooling configurations you most often need to
  be maintained separately and shared among projects.

Mixins allow you to merge configuration with your project configuration
just after the base project file is loaded. The merge is so low-level
and generic that you can, in fact, load an empty base configuration 
and merge in entire project configurations through mixins.

## Designing for Mixins merge rules

Merging of any sort tends to be hard to do well. It’s tricky at a 
code-level, yes, but, just as importantly, merging can be hard to grasp in
your head.

The brief sections that follow provide an overview of our recommended
design approach and the merge rules at play.

!!! tip "Use `dumpconfig` to debug mixins"
    `ceedling dumpconfig` can be invaluable in developing and troubleshooting
    your mixins. The `dumpconfig` application command will load your mixins
    just as a build would but produce the resulting merged configuration for
    inspection in a YAML file you specify.

### Additive Mixin merges

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
   many within containing configuration entries. Add paths, plugins, and 
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
follows a few basic rules.

#### New key/value pair

If a configuration key/value pair does not already exist at the time
of merging, the mixin key/value pair is added to the configuration.

#### Existing container (list or hash)

If a container — e.g. list or hash — already exists at the time of a
merge, the contents are _combined_.

##### Hash merge

A hash (key/value pairs) merge is straightforward. The key/value pairs
are intermingled at the same level.

##### List merge

A list merge is a bit more complex:

* When two lists are merged, the mixin’s entries are placed _before_ the
  existing list entries. This means higher-priority mixin content appears
  first in the combined list. For example, if a command line mixin and
  the base project configuration both add header search paths, the
  command line mixin paths come first in the resulting merged list. As
  such, ultimately, the mixin’s paths are searched first.
* If the existing configuration contains a list but the mixin value is a 
  different type, the mixin is treated as a one-element list and placed 
  before the existing list. The typical case is a list of strings growing 
  with an additional single string.

!!! note "An exception to the preceding — tool argument lists"
    In the case of tool argument lists (`:tools` ↳ `<tool name>` ↳ `:arguments`),
    mixin entries are placed _after_ the existing argument list entries 
    rather than before. Command line tools tend to process arguments 
    left-to-right such that a later occurrence of a flag takes precedence 
    (e.g. `-O0` after `-O2` overrides `-02`). Appending ensures that a 
    higher-priority mixin’s tool arguments override lower-priority 
    arguments by conforming to the typical CLI convention.

#### Existing simple value (boolean, string, numeric)

If a simple value already exists in the configuration at the time of
merging, that value is replaced by the mixin value being merged. Because
higher-priority mixins are merged last, the last write wins.

!!! info "Mixin merge order and list content order"
    Because mixin entries are placed _before_ existing list entries,
    higher-priority mixin content appears first in combined lists. For
    example, include search paths added by a command line mixin will be
    searched before those in an environment variable mixin, which will be
    searched before those in the project configuration file. See the
    section [Search Paths for Test Builds](../testing-guide/conventions.md#search-paths-for-test-builds)
    for more.

## Mixins Example
### Our Example Scenario
Let’s start with an example that helps explain how mixins are merged.
Then, the documentation sections that follow will discuss everything
in detail.

In this example, we will load a base project configuration and then
apply three mixin files using each of the available means — command line,
envionment variable, and `:mixins` section in the base project 
configuration file.

### Example environment variable

`CEEDLING_MIXIN_1` = `./env.yml`

### Example command line

An environment variable as the preceding inserts a mixin outside of the 
command line shown below. The _base.yml_ file (documented below) merges
the mixin file _enabled.yml_ (documented below).

`ceedling --project=base.yml --mixin=support/mixins/cmdline.yml <tasks>`

!!! info "The `--mixin` flag supports more than filepaths"
    The [`--mixin` flag](#-mixin-command-line-flags) can be used multiple times 
    in the same command line to smoosh together multiple mixins. 

The example command line above with the precending environment variable 
will produce the following logging output if verbosity is set above NORMAL:

```
🚧 Loaded project configuration from command line argument using base.yml
 + Merging project configuration mixin using ./enabled.yml
 + Merging CEEDLING_MIXIN_1 mixin using ./env.yml
 + Merging command line mixin using support/mixins/cmdline.yml
```

_Notes:_

* The logging output above referencing _enabled.yml_ comes from the 
  `:mixins` section within the base project configuration file (_base.yml_)
  provided below.
* The resulting configuration in this annotated example is missing settings 
  required by Ceedling. If these examples were to be used in their stripped 
  down form, they would cause a validation build error.

### Example Configuration files

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

### Example resulting configuration

Behold the project configuration following mixin merges:

```yaml
:project:
  :build_root: build/           # From base.yml
  :use_test_preprocessor: :all  # Value in support/mixins/cmdline.yml overwrote value from support/mixins/enabled.yml (cmdline merged last)
  :test_file_prefix: Test       # Added to :project from support/mixins/cmdline.yml

:plugins:
  :enabled:                       # :plugins ↳ :enabled from two mixins merged with original list in base.yml
    - compile_commands_json_db    # From env.yml (prepended before base.yml entry — env.yml is higher priority)
    - gcov                        # From support/mixins/enabled.yml (prepended before base.yml entry)
    - report_tests_pretty_stdout  # From base.yml
```
!!! note "Original `:mixins` section is removed from resulting config"

## Options for loading Mixins

You have three options for telling Ceedling what mixins to load. These
options are ordered below according to their precedence. A Mixin higher
in the list is merged **later** and therefore its content takes priority 
over lower-listed options in two ways:

- **Single values** (a path string, a number, true/false): The higher-priority
  mixin’s value replaces any lower-priority mixin’s value for the same setting.
- **Lists** (e.g. search paths, plugin names): The higher-priority mixin’s
  entries appear **before** lower-priority entries in the combined list.
  For example, if a command line mixin adds the search path `vendor/include`
  and the project configuration mixin adds `src/include`, the merged include
  path list will be `[vendor/include, src/include]` — the command line path
  is searched first.

In addition, options higher in the list force duplicate mixin filepaths in
lower-listed options to be ignored (i.e. deduplicated).

Unlike project file loading that resolves to a single filepath
to load your base configuration, multiple mixins can be specified using 
any or all of these options.

1. Command line option flags
1. Environment variables
1. Base project configuration file entries

### `--mixin` command line flags

As already discussed above, many of Ceedling’s application commands 
include an optional `--project` flag. Most of these same commands 
also recognize optional `--mixin` flags. Note that `--mixin` can be 
used multiple times in a single command line and is processed 
strictly left-to-right.

When provided, Ceedling merges the specified mixin into the base 
project configuration. A `--mixin` value accepts three forms 
distinguished by an optional sigil prefix:

#### File or named mixin (no sigil or `@` sigil)

The value is treated as a file path or named mixin lookup. Two 
equivalent syntaxes are accepted:

```sh
--mixin my_compiler           # simple name lookup (no sigil)
--mixin bar/mixin.yaml        # filepath (no sigil)
--mixin @bar/mixin.yaml       # filepath (explicit @ sigil — same result)
```

- A **simple name** (no extension, no path separator) is looked up 
  among Ceedling’s mixin load paths.
- A **filename or filepath** (with extension or path separator) loads 
  the specified YAML file directly.
- The `@` sigil is optional and makes the file/name intent explicit; 
  it is otherwise identical to providing the value without a sigil.

#### Inline YAML (`=` sigil)

The value is treated as a YAML string merged directly into 
configuration — no file needed. Prefix the value with `=` and quote 
the argument to protect YAML special characters (colons, brackets, 
spaces) from shell interpretation:

```sh
--mixin "=:defines: {release: [MY_SYMBOL]}"
```

The YAML content must evaluate to a Hash at the top level (matching 
the structure of a project configuration file). Arrays, scalars, and 
empty strings are rejected with an error.

#### Combining forms

All three forms can be mixed freely in a single command line and are 
processed in the order they appear, left-to-right:

```sh
ceedling release \
  --mixin @base_compiler.yml \
  --mixin "=:defines: {release: [CIPHER_ROT13]}" \
  --mixin @ci_overrides.yml
```

In this example: `base_compiler.yml` is merged first, then the 
inline YAML, then `ci_overrides.yml`. Later entries win on scalar 
conflicts, so `ci_overrides.yml` has the highest priority.

#### Error behavior

Simple mixin names require mixin load paths to search. A default 
mixin load path always points to within Ceedling itself (for 
built-in mixins). User-specified load paths must be added through 
the `:mixins` section of the base project file. See the
[documentation for the `:mixins` section of your project 
configuration][mixins-config-section] for more details.

Filepaths may be relative (to the working directory) or absolute.

If the `--mixin` filename or filepath does not exist, Ceedling 
terminates with an error. If Ceedling cannot find a mixin name in 
any load paths, it terminates with an error. If an inline YAML 
string cannot be parsed or does not evaluate to a Hash, Ceedling 
terminates with an error.

[mixins-config-section]: #base-configuration-file-mixins-entries

### Mixin environment variables

Mixins can also be loaded through environment variables. Ceedling
recognizes environment variables with a naming scheme of 
`CEEDLING_MIXIN_#`, where `#` is any number greater than 0.

Precedence among the environment variables follows a simple ascending
sort of the trailing numeric value in the environment variable name.
Lower-numbered variables are merged first (lower priority); higher-numbered
variables are merged last (higher priority). For example,
`CEEDLING_MIXIN_5` is merged before `CEEDLING_MIXIN_99`, so
`CEEDLING_MIXIN_99` takes priority.

Mixin environment variables only hold filepaths. Filepaths may be 
relative (in relation to the working directory) or absolute.

If the filepath specified by an environment variable does not exist,
Ceedling terminates with an error.

### Base configuration file `:mixins` entries

!!! note
    Ceedling only recognizes a `:mixins` section in your base project
    configuration file. A `:mixins` section nested in a mixin is ignored.

The `:mixins` section of a base project configuration file is filtered
out of the resulting merged configuration and will be absent in 
`ceedling dumpconfig` output.

The `:mixins` configuration section can contain up to two subsections.
Each subsection is optional.

* `:enabled`

    An optional array comprising (A) mixin filenames/filepaths and/or 
    (B) simple mixin names.

    1. A filename contains a file extension. A filepath includes a 
       directory path. The file content is YAML.
    1. A simple name (no file extension and no path) is used
       as a file lookup among any configured load paths (see next
       section) and as a lookup name among Ceedling’s built-in mixins
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
  entries in `:mixins` ↳ `:enabled`, they are merged **last** and therefore
  have the highest priority. The `:enabled` list is merged **first** (because
  it resides in the base configuration and has the lowest priority).

[YAML]: http://en.wikipedia.org/wiki/Yaml
[inline-ruby-string-expansion]: project-file.md#inline-ruby-string-expansion

<br/><br/>
