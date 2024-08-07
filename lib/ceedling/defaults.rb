# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/system_wrapper'
require 'ceedling/file_path_utils'

# Assign a default value for system testing where CEEDLING_APPCFG may not be present
# TODO: Create code config & test structure that does not internalize a test path like this
CEEDLING_VENDOR = defined?( CEEDLING_APPCFG ) ? CEEDLING_APPCFG[:ceedling_vendor_path] : File.expand_path( File.dirname(__FILE__) + '/../../vendor' )

CEEDLING_PLUGINS = [] unless defined? CEEDLING_PLUGINS

DEFAULT_TEST_COMPILER_TOOL = {
  :executable => ENV['TEST_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['TEST_CC'],
  :name => 'default_test_compiler'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
    "-I\"${5}\"".freeze, # Per-test executable search paths
    "-D\"${6}\"".freeze, # Per-test executable defines
    "-DGNU_COMPILER".freeze, # OSX clang
    "-g".freeze,
    ENV['CFLAGS'].nil? ? "" : ENV['CFLAGS'].split,
    "-c \"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    # gcc's list file output options are complex; no use of ${3} parameter in default config
    "-MMD".freeze,
    "-MF \"${4}\"".freeze,
    ].freeze
  }

DEFAULT_TEST_ASSEMBLER_TOOL = {
  :executable => ENV['TEST_AS'].nil? ? FilePathUtils.os_executable_ext('as').freeze : ENV['TEST_AS'],
  :name => 'default_test_assembler'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['TEST_ASFLAGS'].nil? ? "" : ENV['TEST_ASFLAGS'].split,
    "-I\"${3}\"".freeze, # Search paths
    # Any defines (${4}) are not included since GNU assembler ignores them
    "\"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    ].freeze
  }

DEFAULT_TEST_LINKER_TOOL = {
  :executable => ENV['TEST_CCLD'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['TEST_CCLD'],
  :name => 'default_test_linker'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['TEST_CFLAGS'].nil? ? "" : ENV['TEST_CFLAGS'].split,
    ENV['TEST_LDFLAGS'].nil? ? "" : ENV['TEST_LDFLAGS'].split,
    "${1}".freeze,
    "${5}".freeze,
    "-o \"${2}\"".freeze,
    "".freeze,
    "${4}".freeze,
    ENV['TEST_LDLIBS'].nil? ? "" : ENV['TEST_LDLIBS'].split
    ].freeze
  }

DEFAULT_TEST_FIXTURE_TOOL = {
  :executable => '${1}'.freeze, # Unity test runner executable
  :name => 'default_test_fixture'.freeze,
  :optional => false.freeze,
  :arguments => [].freeze
  }

DEFAULT_TEST_FIXTURE_SIMPLE_BACKTRACE_TOOL = {
  :executable => '${1}'.freeze, # Unity test runner executable
  :name => 'default_test_fixture_simple_backtrace'.freeze,
  :optional => false.freeze,
  :arguments => [
    '-n ${2}'.freeze # Exact test case name matching flag
    ].freeze
  }

DEFAULT_TEST_SHALLOW_INCLUDES_PREPROCESSOR_TOOL = {
  :executable => ENV['TEST_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['TEST_CC'],
  :name => 'default_test_shallow_includes_preprocessor'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['TEST_CPPFLAGS'].nil? ? "" : ENV['TEST_CPPFLAGS'].split,
    '-E'.freeze,             # Run only through preprocessor stage with its output
    '-MM'.freeze,            # Output make rule + suppress header files found in system header directories
    '-MG'.freeze,            # Assume missing header files are generated files (do not discard)
    '-MP'.freeze,            # Create make "phony" rules for each include dependency
    "-D\"${2}\"".freeze,     # Per-test executable defines
    "-DGNU_COMPILER".freeze, # OSX clang
    '-nostdinc'.freeze,      # Ignore standard include paths
    "-x c".freeze,           # Force C language
    "\"${1}\"".freeze
    ].freeze
  }

DEFAULT_TEST_NESTED_INCLUDES_PREPROCESSOR_TOOL = {
  :executable => ENV['TEST_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['TEST_CC'],
  :name => 'default_test_nested_includes_preprocessor'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['TEST_CPPFLAGS'].nil? ? "" : ENV['TEST_CPPFLAGS'].split,
    '-E'.freeze,             # Run only through preprocessor stage with its output
    '-MM'.freeze,            # Output make rule + suppress header files found in system header directories
    '-MG'.freeze,            # Assume missing header files are generated files (do not discard)
    '-H'.freeze,             # Also output #include list with depth
    "-I\"${2}\"".freeze,     # Per-test executable search paths
    "-D\"${3}\"".freeze,     # Per-test executable defines
    "-DGNU_COMPILER".freeze, # OSX clang
    '-nostdinc'.freeze,      # Ignore standard include paths
    "-x c".freeze,           # Force C language
    "\"${1}\"".freeze
    ].freeze
  }

DEFAULT_TEST_FILE_PREPROCESSOR_TOOL = {
  :executable => ENV['TEST_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['TEST_CC'],
  :name => 'default_test_file_preprocessor'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['TEST_CPPFLAGS'].nil? ? "" : ENV['TEST_CPPFLAGS'].split,
    '-E'.freeze,
    "-I\"${4}\"".freeze, # Per-test executable search paths
    "-D\"${3}\"".freeze, # Per-test executable defines
    "-DGNU_COMPILER".freeze, # OSX clang
    # '-nostdinc'.freeze, # disabled temporarily due to stdio access violations on OSX
    "-x c".freeze,           # Force C language
    "\"${1}\"".freeze,
    "-o \"${2}\"".freeze
    ].freeze
  }

# Disable the -MD flag for OSX LLVM Clang, since unsupported
if RUBY_PLATFORM =~ /darwin/ && `gcc --version 2> /dev/null` =~ /Apple LLVM version .* \(clang/m # OSX w/LLVM Clang
  MD_FLAG = '' # Clang doesn't support the -MD flag
else
  MD_FLAG = '-MD'
end

DEFAULT_TEST_DEPENDENCIES_GENERATOR_TOOL = {
  :executable => ENV['TEST_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['TEST_CC'],
  :name => 'default_test_dependencies_generator'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['TEST_CPPFLAGS'].nil? ? "" : ENV['TEST_CPPFLAGS'].split,
    '-E'.freeze,
    "-I\"${5}\"".freeze, # Per-test executable search paths
    "-D\"${4}\"".freeze, # Per-test executable defines
    "-DGNU_COMPILER".freeze,
    "-MT \"${3}\"".freeze,
    '-MM'.freeze,
    MD_FLAG.freeze,
    '-MG'.freeze,
    "-MF \"${2}\"".freeze,
    "-x c".freeze, # Force C language
    "-c \"${1}\"".freeze,
    # '-nostdinc'.freeze,
    ].freeze
  }

DEFAULT_RELEASE_DEPENDENCIES_GENERATOR_TOOL = {
  :executable => ENV['RELEASE_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['RELEASE_CC'],
  :name => 'default_release_dependencies_generator'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['RELEASE_CPPFLAGS'].nil? ? "" : ENV['RELEASE_CPPFLAGS'].split,
    '-E'.freeze,
    {"-I\"$\"" => 'COLLECTION_PATHS_SOURCE_INCLUDE_VENDOR'}.freeze,
    {"-I\"$\"" => 'COLLECTION_PATHS_RELEASE_TOOLCHAIN_INCLUDE'}.freeze,
    {"-D$" => 'COLLECTION_DEFINES_RELEASE_AND_VENDOR'}.freeze,
    {"-D$" => 'DEFINES_RELEASE_PREPROCESS'}.freeze,
    "-DGNU_COMPILER".freeze,
    "-MT \"${3}\"".freeze,
    '-MM'.freeze,
    MD_FLAG.freeze,
    '-MG'.freeze,
    "-MF \"${2}\"".freeze,
    "-x c".freeze, # Force C language
    "-c \"${1}\"".freeze,
    # '-nostdinc'.freeze,
    ].freeze
  }

DEFAULT_RELEASE_COMPILER_TOOL = {
  :executable => ENV['RELEASE_CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['RELEASE_CC'],
  :name => 'default_release_compiler'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['RELEASE_CPPFLAGS'].nil? ? "" : ENV['RELEASE_CPPFLAGS'].split,
    "-I\"${5}\"".freeze, # Search paths
    "-D\"${6}\"".freeze, # Defines
    "-DGNU_COMPILER".freeze,
    ENV['RELEASE_CFLAGS'].nil? ? "" : ENV['RELEASE_CFLAGS'].split,
    "-c \"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    # gcc's list file output options are complex; no use of ${3} parameter in default config
    "-MMD".freeze,
    "-MF \"${4}\"".freeze,
    ].freeze
  }

DEFAULT_RELEASE_ASSEMBLER_TOOL = {
  :executable => ENV['RELEASE_AS'].nil? ? FilePathUtils.os_executable_ext('as').freeze : ENV['RELEASE_AS'],
  :name => 'default_release_assembler'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['RELEASE_ASFLAGS'].nil? ? "" : ENV['RELEASE_ASFLAGS'].split,
    "-I\"${3}\"".freeze, # Search paths
    "-D\"${4}\"".freeze, # Defines (FYI--allowed with GNU assembler but ignored)
    "\"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    ].freeze
  }

DEFAULT_RELEASE_LINKER_TOOL = {
  :executable => ENV['RELEASE_CCLD'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['RELEASE_CCLD'],
  :name => 'default_release_linker'.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['RELEASE_CFLAGS'].nil? ? "" : ENV['RELEASE_CFLAGS'].split,
    ENV['RELEASE_LDFLAGS'].nil? ? "" : ENV['RELEASE_LDFLAGS'].split,
    "\"${1}\"".freeze,
    "${5}".freeze,
    "-o \"${2}\"".freeze,
    "".freeze,
    "${4}".freeze,
    ENV['RELEASE_LDLIBS'].nil? ? "" : ENV['RELEASE_LDLIBS'].split
    ].freeze
  }

DEFAULT_TEST_BACKTRACE_GDB_TOOL = {
  :executable => ENV['GDB'].nil? ? FilePathUtils.os_executable_ext('gdb').freeze : ENV['GDB'],
  :name => 'default_test_backtrace_gdb'.freeze,
  # Must be optional because validation is contingent on backtrace configuration.
  # (Don't break a build if `gdb` is unavailable but backtrace does not require it.)
  :optional => true.freeze,
  :arguments => [
    '-q'.freeze,
    '--batch'.freeze,
    '--eval-command run'.freeze,
    "--command \"${1}\"".freeze, # Debug script file to run
    '--args'.freeze,
    '${2}'.freeze,               # Test executable
    '-n ${3}'.freeze             # Exact test case name matching flag
    ].freeze
  }

DEFAULT_TOOLS_TEST = {
  :tools => {
    :test_compiler => DEFAULT_TEST_COMPILER_TOOL,
    :test_linker   => DEFAULT_TEST_LINKER_TOOL,
    :test_fixture  => DEFAULT_TEST_FIXTURE_TOOL,
    :test_fixture_simple_backtrace => DEFAULT_TEST_FIXTURE_SIMPLE_BACKTRACE_TOOL,
    :test_backtrace_gdb => DEFAULT_TEST_BACKTRACE_GDB_TOOL,
    }
  }

DEFAULT_TOOLS_TEST_ASSEMBLER = {
  :tools => {
    :test_assembler => DEFAULT_TEST_ASSEMBLER_TOOL,
    }
  }

DEFAULT_TOOLS_TEST_PREPROCESSORS = {
  :tools => {
    :test_shallow_includes_preprocessor => DEFAULT_TEST_SHALLOW_INCLUDES_PREPROCESSOR_TOOL,
    :test_nested_includes_preprocessor => DEFAULT_TEST_NESTED_INCLUDES_PREPROCESSOR_TOOL,
    :test_file_preprocessor     => DEFAULT_TEST_FILE_PREPROCESSOR_TOOL,
    }
  }

DEFAULT_TOOLS_TEST_DEPENDENCIES = {
  :tools => {
    :test_dependencies_generator => DEFAULT_TEST_DEPENDENCIES_GENERATOR_TOOL,
    }
  }

DEFAULT_TOOLS_RELEASE = {
  :tools => {
    :release_compiler => DEFAULT_RELEASE_COMPILER_TOOL,
    :release_linker   => DEFAULT_RELEASE_LINKER_TOOL,
    }
  }

DEFAULT_TOOLS_RELEASE_ASSEMBLER = {
  :tools => {
    :release_assembler => DEFAULT_RELEASE_ASSEMBLER_TOOL,
    }
  }

DEFAULT_TOOLS_RELEASE_DEPENDENCIES = {
  :tools => {
    :release_dependencies_generator => DEFAULT_RELEASE_DEPENDENCIES_GENERATOR_TOOL,
    }
  }


DEFAULT_RELEASE_TARGET_NAME = 'project'

DEFAULT_CEEDLING_PROJECT_CONFIG = {
    :project => {
      # :build_root must be set by user
      :use_mocks => false,
      :use_exceptions => false,
      :compile_threads => 1,
      :test_threads => 1,
      :use_test_preprocessor => :none,
      :test_file_prefix => 'test_',
      :release_build => false,
      :use_backtrace => :simple,
      :debug => false
    },

    :release_build => {
      # :output is set while building configuration -- allows smart default system-dependent file extension handling
      :use_assembly => false,
      :artifacts => []
    },

    :test_build => {
       :use_assembly => false
     },

    # Unlike other top-level entries, :environment is an array (of hashes) to preserve order
    :environment => [],

    :paths => {
      :test => [],    # Must be populated by user
      :source => [],  # Should be populated by user but TEST_INCLUDE_PATH() could be used exclusively instead
      :support => [],
      :include => [], # Must be populated by user
      :libraries => [],
      :test_toolchain_include => [],
      :release_toolchain_include => [],
    },

    :files => {
      :test => [],
      :source => [],
      :assembly => [],
      :support => [],
      :include => [],
    },

    :defines => {
      :use_test_definition => false,
      :test => [], # A hash/sub-hashes in config file can include operations and test executable matchers as keys
      :preprocess => [], # A hash/sub-hashes in config file can include operations and test executable matchers as keys
      :release => []
    },

    :flags => {
      # Test & release flags are validated for presence--empty flags causes an error
      # :test => [], # A hash/sub-hashes in config file can include operations and test executable matchers as keys
      # :release => [] # A hash/sub-hashes in config file can include arrays for operations
    },

    :libraries => {
      :flag => '-l${1}',
      :path_flag => '-L ${1}',
      :test => [],
      :release => []
    },

    :extension => {
      :header => '.h',
      :source => '.c',
      :assembly => '.s',
      :object => '.o',
      :libraries => ['.a','.so'],
      :executable => ( SystemWrapper.windows? ? EXTENSION_WIN_EXE : EXTENSION_NONWIN_EXE ),
      :map => '.map',
      :list => '.lst',
      :testpass => '.pass',
      :testfail => '.fail',
      :dependencies => '.d',
      :yaml => '.yml'
    },

    :unity => {
      :defines => [],
      :use_param_tests => false
    },

    :cmock => {
      :includes => [],
      :defines => [],
      :plugins => [],
      :unity_helper_path => [],
      # Yes, we're duplicating these defaults in CMock, but it's because:
      #  (A) We always need CMOCK_MOCK_PREFIX in Ceedling's environment
      #  (B) Test runner generator uses these same configuration values
      :mock_prefix => 'Mock',
      :mock_suffix => '',
      # Just because strict ordering is the way to go
      :enforce_strict_ordering => true
    },

    :cexception => {
      :defines => []
    },

    :test_runner => {
      :cmdline_args => false,
      :includes => [],
      :defines => [],
      :file_suffix => '_runner',
    },

    # All tools populated while building up config / defaults structure
    :tools => {},

    # Empty argument lists for default tools
    # Note: These can be overridden in project file to add arguments totally redefining tools
    :test_compiler  => { :arguments => [] },
    :test_assembler => { :arguments => [] },
    :test_linker    => { :arguments => [] },
    :test_fixture   => {
      :arguments => [],
      :link_objects => [], # compiled object files to always be linked in (e.g. cmock.o if using mocks)
    },
    :test_backtrace_gdb => { :arguments => [] },
    :test_includes_preprocessor  => { :arguments => [] },
    :test_file_preprocessor      => { :arguments => [] },
    :test_file_preprocessor_directives => { :arguments => [] },
    :test_dependencies_generator => { :arguments => [] },
    :release_compiler  => { :arguments => [] },
    :release_linker    => { :arguments => [] },
    :release_assembler => { :arguments => [] },
    :release_dependencies_generator => { :arguments => [] }
  }.freeze


CEEDLING_RUNTIME_CONFIG = {
    :unity => {
      :vendor_path => CEEDLING_VENDOR
    },

    :cmock => {
      :vendor_path => CEEDLING_VENDOR
    },

    :cexception => {
      :vendor_path => CEEDLING_VENDOR
    },

    :plugins => {
      :load_paths => [],
      :enabled => CEEDLING_PLUGINS,
    }
  }.freeze


DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE = %q{
% ignored        = hash[:results][:counts][:ignored]
% failed         = hash[:results][:counts][:failed]
% stdout_count   = hash[:results][:counts][:stdout]
% header_prepend = ((hash[:header].length > 0) ? "#{hash[:header]}: " : '')
% banner_width   = 25 + header_prepend.length # widest message

% if (stdout_count > 0)
<%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'TEST OUTPUT')%>
%   hash[:results][:stdout].each do |string|
%     string[:collection].each do |item|
<%=string[:source][:file]%>: "<%=item%>"
%     end
%   end

% end
% if (ignored > 0)
<%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'IGNORED TEST SUMMARY')%>
%   hash[:results][:ignores].each do |ignore|
%     ignore[:collection].each do |item|
<%=ignore[:source][:file]%>:<%=item[:line]%>:<%=item[:test]%>
% if (item[:message].length > 0)
: "<%=item[:message]%>"
% else
<%="\n"%>
% end
%     end
%   end

% end
% if (failed > 0)
<%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'FAILED TEST SUMMARY')%>
%   hash[:results][:failures].each do |failure|
%     failure[:collection].each do |item|
<%=failure[:source][:file]%>:<%=item[:line]%>:<%=item[:test]%>
% if (item[:message].length > 0)
: "<%=item[:message]%>"
% else
<%="\n"%>
% end
%     end
%   end

% end
% total_string = hash[:results][:counts][:total].to_s
% format_string = "%#{total_string.length}i"
<%=@ceedling[:plugin_reportinator].generate_banner(header_prepend + 'OVERALL TEST SUMMARY')%>
% if (hash[:results][:counts][:total] > 0)
TESTED:  <%=hash[:results][:counts][:total].to_s%>
PASSED:  <%=sprintf(format_string, hash[:results][:counts][:passed])%>
FAILED:  <%=sprintf(format_string, failed)%>
IGNORED: <%=sprintf(format_string, ignored)%>
% else

No tests executed.
% end

}
