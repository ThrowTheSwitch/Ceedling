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

To implement the solution, we make use of two features:

* `gcovr`’s tool `:executable` definition that looks up an environment variable.
* Ceedling’s `:environment` settings to redefine `gcovr`.

Gcovr’s tool defintion, like many of Ceedling’s tool defintions, defaults to an
environment variable (`GCOVR`) if it is defined. If we set that environment
variable to call Python with the path to the `gcovr` script, Ceedling will call
that instead of only `gcovr`. Ceedling enables you to set environment variables
that only exist while it runs.

In your project file:

```yaml
:environment:
  # Fill in / omit paths on your system as appropritate to your circumstances
  - :gcovr: <path>/python <path>/gcovr
```

Alternatively, a slightly more elegant approach may work in some cases:

```yaml
:environment:
  - ":gcovr: python #{`which gcovr`}" # Shell out to look up the path to gcovr
```

A variation of this concept relies on Python’s knowledge of its runtime
environment and packages:

```yaml
:environment:
  - :gcovr: python -m gcovr # Call the gcovr module
```

<br/><br/>
