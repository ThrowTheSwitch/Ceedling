# Advanced & Troubleshooting

## Advanced usage

Details of interest for this plugin to be modified or made use of using 
Ceedling’s advanced features are primarily contained in 
[defaults_gcov.rb](../../snapshot/plugins/gcov/config/defaults_gcov.rb) and [defaults.yml](../../snapshot/plugins/gcov/config/defaults.yml).

## "gcovr not found"

`gcovr` is a Python-based application. Depending on the particulars of its 
installation and your platform, you may encounter a "gcovr not found" error. 
This is usually related to complications of running a Python script as an 
executable.

### Check your `PATH`

The problem may be as simple to solve as ensuring your user or system path 
include the path to `python` and/or the `gcovr` script. `gcovr` may be 
successfully installed and findable by Python; this does not necessarily 
mean that shell commands Ceedling spawns can find these tools.

Options:

1. Modify your user or system path to include your Python installation, `gcovr`
   location, or both.
1. Use Ceedling’s `:environment` project configuration with its special 
   handling of `PATH` to modify the search path Ceedling accesses when it 
   executes shell commands. xample below.

```yaml
:environment:
  - :path:               # Concatenates the following with OS-specific path separator             
     - <path to add>     # Add Python and/or `gcovr` path
     - "#{ENV['PATH']}"  # Fetch existing path entries
```

### Redefine `gcovr` to call Python directly

Another solution is simple in concept. Instead of calling `gcovr` directly, call
`python` with the `gcovr` script as a command line argument (followed by all of
the configured `gcovr` arguments).

`gcovr`'s tool definition, like every Ceedling tool definition, can be
overridden directly in your project configuration. Overriding `:tools` merges
into the plugin's own default tool definition key by key, so redefining
`:executable` alone would leave the default `:arguments` — meant for calling
`gcovr` directly — in place. Instead, provide the whole tool definition,
inserting the path to the `gcovr` script as `python`'s first argument ahead
of the plugin's own `${1}`/`${2}`/`${3}` placeholders (`--root`, `--exclude`,
and the plugin's remaining built options, respectively):

```yaml
:tools:
  :gcov_gcovr_report:
    :executable: python
    :arguments:
      - <path>/gcovr
      - "--root \"${1}\""
      - "--exclude \"${2}\""
      - "${3}"
```

See [Tool Definitions](../../configuration/reference/tools.md) for the full
set of tool customization options.

A variation of this concept relies on Python’s knowledge of its runtime
environment and packages:

```yaml
:environment:
  - :gcovr: python -m gcovr # Call the gcovr module
```

<br/><br/>
