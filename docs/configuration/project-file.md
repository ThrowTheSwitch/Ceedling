# The Almighty Ceedling Project Configuration File (in Glorious YAML)

See this [commented project file][example-config-file] for a nice 
example of a complete project configuration.

## Some YAML Learnin'

Please consult YAML documentation for the finer points of format
and to understand details of our YAML-based configuration file.

We recommend [Wikipedia's entry on YAML](http://en.wikipedia.org/wiki/Yaml)
for this. A few highlights from that reference page:

* YAML streams are encoded using the set of printable Unicode
  characters, either in UTF-8 or UTF-16.

* White space indentation is used to denote structure; however,
  tab characters are never allowed as indentation.

* Comments begin with the number sign (`#`), can start anywhere
  on a line, and continue until the end of the line unless enclosed
  by quotes.

* List members are denoted by a leading hyphen (`-`) with one member
  per line, or enclosed in square brackets (`[...]`) and separated
  by comma space (`, `).

* Hashes are represented using colon space (`: `) in the form
  `key: value`, either one per line or enclosed in curly braces
  (`{...}`) and separated by comma space (`, `).

* Strings (scalars) are ordinarily unquoted, but may be enclosed
  in double-quotes (`"`), or single-quotes (`'`).

* YAML requires that colons and commas used as list separators
  be followed by a space so that scalar values containing embedded
  punctuation can generally be represented without needing
  to be enclosed in quotes.

* Repeated nodes are initially denoted by an ampersand (`&`) and
  thereafter referenced with an asterisk (`*`). These are known as
  anchors and aliases in YAML speak.

## Notes on Project File Structure and Documentation That Follows

* Each of the following sections represent top-level entries
  in the YAML configuration file. Top-level means the named entries
  are furthest to the left in the hierarchical configuration file 
  (not at the literal top of the file).

* Unless explicitly specified in the configuration file by you, 
  Ceedling uses default values for settings.

* At minimum, these settings must be specified for a test suite:
  * `:project` ↳ `:build_root`
  * `:paths` ↳ `:source`
  * `:paths` ↳ `:test`
  * `:paths` ↳ `:include` and/or use of `TEST_INCLUDE_PATH(...)` 
    build directive macro within your test files

* At minimum, these settings must be specified for a release build:
  * `:project` ↳ `:build_root`
  * `:paths` ↳ `:source`

* As much as is possible, Ceedling validates your settings in
  properly formed YAML.

* Improperly formed YAML will cause a Ruby error when the YAML
  is parsed. This is usually accompanied by a complaint with
  line and column number pointing into the project file.

* Certain advanced features rely on `gcc` and `cpp` as preprocessing
  tools. In most Linux systems, these tools are already available.
  For Windows environments, we recommend the [MinGW] project
  (Minimalist GNU for Windows).

* Ceedling is primarily meant as a build tool to support automated
  unit testing. All the heavy lifting is involved there. Creating
  a simple binary release build artifact is quite trivial in
  comparison. Consequently, most default options and the construction
  of Ceedling itself is skewed towards supporting testing, though
  Ceedling can, of course, build your binary release artifact
  as well. Note that some complex binary release builds are beyond
  Ceedling's abilities. See the Ceedling plugin [subprojects](../plugins/subprojects.md) for
  extending release build abilities.

[MinGW]: http://www.mingw.org/

## Ceedling-specific YAML Handling & Conventions

### Inline Ruby string expansion

Ceedling is able to execute inline Ruby string substitution code within the
entries of certain project file configuration elements.

In some cases, this evaluation may occurs when elements of the project 
configuration are loaded and processed into a data structure for use by the 
Ceedling application (e.g. path handling). In other cases, this evaluation
occurs each time a project configuration element is referenced (e.g. tools).

_Notes:_
* One good option for validating and troubleshooting inline Ruby string 
  exapnsion is use of `ceedling dumpconfig` at the command line. This application
  command causes your project configuration to be processed and written to a 
  YAML file with any inline Ruby string expansions, well, expanded along with 
  defaults set, plugin actions applied, etc.
* A commonly needed expansion is that of referencing an environment variable.
  Inline Ruby string expansion supports this. See the example below.

#### Ruby string expansion syntax

To exapnd the string result of Ruby code within a configuration value string, 
wrap the Ruby code in the substitution pattern `#{…}`.

Inline Ruby string expansion may constitute the entirety of a configuration 
value string, may be embedded within a string, or may be used multiple times
within a string.

Because of the `#` it's a good idea to wrap any string values in your YAML that
rely on this feature with quotation marks. Quotation marks for YAML strings are
optional. However, the `#` can cause a YAML parser to see a comment. As such,
explicitly indicating a string to the YAML parser with enclosing quotation 
marks alleviates this problem.

#### Ruby string expansion example

```yaml
:some_config_section:
  :some_key:
    - "My env string #{ENV['VAR1']}"
    - "My utility result string #{`util --arg`.strip()}"
```

In the example above, the two YAML strings will include the strings returned by
the Ruby code within `#{…}`:

1. The first string uses Ruby's environment variable lookup `ENV[…]` to fetch 
the value assigned to variable `VAR1`.
1. The second string uses Ruby's backtick shell execution ``…`` to insert the 
string generated by a command line utility.

#### Project file sections that offer inline Ruby string expansion

* `:mixins`
* `:environment`
* `:paths` plus any second tier configuration key name ending in `_path` or
  `_paths`
* `:flags`
* `:defines`
* `:tools`
* `:release_build` ↳ `:artifacts`

See each section's documentation for details.

[inline-ruby-string-expansion]: #inline-ruby-string-expansion

### Path handling

Any second tier setting keys anywhere in YAML whose names end in `_path` or
`_paths` are automagically processed like all Ceedling-specific paths in the
YAML to have consistent directory separators (i.e. `/`) and to take advantage
of inline Ruby string expansion (see preceding section for details).

## Let's Be Careful Out There

Ceedling performs validation of the values you set in your 
configuration file (this assumes your YAML is correct and will 
not fail format parsing, of course).

That said, validation is limited to only those settings Ceedling
uses and those that can be reasonably validated. Ceedling does
not limit what can exist within your configuration file. In this
way, you can take full advantage of YAML as well as add sections
and values for use in your own custom plugins (documented later).

The consequence of this is simple but important. A misspelled
configuration section or value name is unlikely to cause Ceedling 
any trouble. Ceedling will happily process that section
or value and simply use the properly spelled default maintained
internally — thus leading to unexpected behavior without warning.

[example-config-file]: ../snapshot/assets/project.yml
