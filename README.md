Using Ceedling inside of a project
==================================

Ceedling can deploy all of its guts into a folder. This allows it
to be used without having to worry about external dependencies.

    ceedling new [your new project name]

Using Ceedling outside of a project as a gem
============================================

(Note: This is still somewhat experimental.)

Ceedling can also be used as a gem. The following Rakefile is the
bare minimum required in order to use Ceedling this way:

    require 'ceedling'

Additionally, a project.yml is required. Here is one to get you
started:

    ---
    :project:
      :use_exceptions: FALSE
      :use_test_preprocessor: TRUE
      :use_auxiliary_dependencies: TRUE
      :build_root: build
    #  :release_build: TRUE
      :test_file_prefix: test_

    #:release_build:
    #  :output: MyApp.out
    #  :use_assembly: FALSE

    :environment:

    :extension:
      :executable: .out

    :paths:
      :test:
        - +:test/**
        - -:test/support
      :source:
        - src/**
      :support:
        - test/support

    :defines:
      # in order to add common defines:
      #  1) remove the trailing [] from the :common: section
      #  2) add entries to the :common: section (e.g. :test: has TEST defined)
      :commmon: &common_defines []
      :test:
        - *common_defines
        - TEST
      :test_preprocess:
        - *common_defines
        - TEST

    :cmock:
      :when_no_prototypes: :warn
      :enforce_strict_ordering: TRUE
      :plugins:
        - :ignore
      :treat_as:
        uint8:    HEX8
        uint16:   HEX16
        uint32:   UINT32
        int8:     INT8
        bool:     UINT8

    #:tools:
    # Ceedling defaults to using gcc for compiling, linking, etc.
    # As [:tools] is blank, gcc will be used (so long as it's in your system path)
    # See documentation to configure a given toolchain for use

    :plugins:
      :load_paths:
        # This is required to use builtin ceedling plugins
        - "#{Ceedling.load_path}"
        # Uncomment this and create the directory in order to use your own
        # custom ceedling plugins
        # - ceedling_plugins
      :enabled:
        # These two plugins ship with Ceedling.
        - stdout_pretty_tests_report
        - module_generator
    ...

Finally, you'll need to create something like the following directory structure. This one matches the project.yml
defined above:

    ./test
    ./test/support
    ./src
    ./project.yml
    ./Rakefile
    ./build
