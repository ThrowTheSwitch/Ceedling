# ReportGenerator Configuration

The `ReportGenerator` utility may be configured with the following configuration items.

All generated reports are found in `<build root>/artifacts/gcov/ReportGenerator/`.

```yaml
:gcov:
  :report_generator:
    # Optional directory for storing persistent coverage information.
    # Can be used in future reports to show coverage evolution.
    :history_directory: <path>

    # Optional plugin files for custom reports or custom history storage (separated by semicolon).
    :plugins: <plugin.dll>;<*.dll>

    # Optional list of assemblies that should be included or excluded in the report (separated by semicolon).
    # Exclusion filters take precedence over inclusion filters.
    # Wildcards are allowed, but not regular expressions.
    :assembly_filters: +<included>;-<excluded>

    # Optional list of classes that should be included or excluded in the report (separated by semicolon).
    # Exclusion filters take precedence over inclusion filters.
    # Wildcards are allowed, but not regular expressions.
    :class_filters: +<included>;-<excluded>

    # Optional list of files that should be included or excluded in the report (separated by semicolon).
    # Exclusion filters take precedence over inclusion filters.
    # Wildcards are allowed, but not regular expressions.
    # Example: "-./vendor/*;-./build/*;-./test/*;-./lib/*;+./src/*"
    :file_filters: +<included>;-<excluded>

    # The verbosity level of the log messages.
    # Values: Verbose, Info, Warning, Error, Off (defaults to Warning)
    :verbosity: <level>

    # Optional tag or build version.
    :tag: <tag>

    # Optional list of one or more regular expressions to exclude gcov notes files that match these filters.
    :gcov_exclude:
      - <regex>
      - ...

    # Optionally set the number of threads to use in parallel. Defaults to 1.
    :threads: <count>

    # Optional list of one or more command line arguments to pass to Report Generator.
    # Useful for configuring Risk Hotspots and Other Settings.
    # https://github.com/danielpalme/ReportGenerator/wiki/Settings
    # Note: This can be accomplished with Ceedling's tool configuration options outside of plugin 
    #       configuration but is supported here to collect configuration options in one place.
    :custom_args:
      - <argument>
      - ...
```

<br/><br/>
