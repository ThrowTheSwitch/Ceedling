# `:environment:` Insert environment variables into shells running tools

Ceedling creates environment variables from any key / value pairs in the 
environment section. Keys become an environment variable name in uppercase. The
values are strings assigned to those environment variables. These value strings 
are either simple string values in YAML or the concatenation of a YAML array
of strings.

`:environment` is a list of single key / value pair entries processed in the 
configured list order.

`:environment` variable value strings can include 
[inline Ruby string expansion][inline-ruby-string-expansion]. Thus, later 
entries can reference earlier entries.

## Special case: `PATH` handling

In the specific case of specifying an environment key named `:path`, an array 
of string values will be concatenated with the appropriate platform-specific 
path separation character (i.e. `:` on Unix-variants, `;` on Windows).

All other instances of environment keys assigned a value of a YAML array use 
simple concatenation.

## Example `:environment` YAML blurb

Note that `:environment` is a list of key / value pairs. Only one key per entry
is allowed, and that key must be a `:`_<symbol>_.

```yaml
:environment:
  - :license_server: gizmo.intranet        # LICENSE_SERVER set with value "gizmo.intranet"
  - :license: "#{`license.exe`}"           # LICENSE set to string generated from shelling out to
                                           # execute license.exe; note use of enclosing quotes to
                                           # prevent a YAML comment.

  - :logfile: system/logs/thingamabob.log  # LOGFILE set with path for a log file

  - :path:                                 # Concatenated with path separator (see special case above)
     - Tools/gizmo/bin                     # Prepend existing PATH with gizmo path
     - "#{ENV['PATH']}"                    # Pattern #{…} triggers ruby evaluation string expansion
                                           # NOTE: value string must be quoted because of '#' to 
                                           # prevent a YAML comment.
```

[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion
