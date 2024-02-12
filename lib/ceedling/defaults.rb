require 'ceedling/constants'
require 'ceedling/system_wrapper'
require 'ceedling/file_path_utils'

#this should be defined already, but not always during system specs
CEEDLING_VENDOR = File.expand_path(File.dirname(__FILE__) + '/../../vendor') unless defined? CEEDLING_VENDOR
CEEDLING_PLUGINS = [] unless defined? CEEDLING_PLUGINS

DEFAULT_TEST_COMPILER_TOOL = {
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_test_compiler'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
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
  :executable => ENV['AS'].nil? ? FilePathUtils.os_executable_ext('as').freeze : ENV['AS'],
  :name => 'default_test_assembler'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['AS'].nil? ? "" : ENV['AS'].split[1..-1],
    ENV['ASFLAGS'].nil? ? "" : ENV['ASFLAGS'].split,
    "-I\"${3}\"".freeze, # Search paths
    # Anny defines (${4}) are not included since GNU assembler ignores them
    "\"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    ].freeze
  }

DEFAULT_TEST_LINKER_TOOL = {
  :executable => ENV['CCLD'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CCLD'],
  :name => 'default_test_linker'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CCLD'].nil? ? "" : ENV['CCLD'].split[1..-1],
    ENV['CFLAGS'].nil? ? "" : ENV['CFLAGS'].split,
    ENV['LDFLAGS'].nil? ? "" : ENV['LDFLAGS'].split,
    "${1}".freeze,
    "${5}".freeze,
    "-o \"${2}\"".freeze,
    "".freeze,
    "${4}".freeze,
    ENV['LDLIBS'].nil? ? "" : ENV['LDLIBS'].split
    ].freeze
  }

DEFAULT_TEST_FIXTURE_TOOL = {
  :executable => '${1}'.freeze,
  :name => 'default_test_fixture'.freeze,
  :stderr_redirect => StdErrRedirect::AUTO.freeze,
  :optional => false.freeze,
  :arguments => [].freeze
  }

DEFAULT_TEST_SHALLOW_INCLUDES_PREPROCESSOR_TOOL = {
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_test_includes_preprocessor'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
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
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_test_includes_preprocessor'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
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
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_test_file_preprocessor'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
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

DEFAULT_TEST_FILE_PREPROCESSOR_DIRECTIVES_TOOL = {
  :executable => FilePathUtils.os_executable_ext('gcc').freeze,
  :name => 'default_test_file_preprocessor_directives'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    '-E'.freeze,
    "-I\"${4}\"".freeze, # Per-test executable search paths
    "-D\"${3}\"".freeze, # Per-test executable defines
    "-DGNU_COMPILER".freeze,
    '-fdirectives-only'.freeze,
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
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_test_dependencies_generator'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
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
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_release_dependencies_generator'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
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
  :executable => ENV['CC'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CC'],
  :name => 'default_release_compiler'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CC'].nil? ? "" : ENV['CC'].split[1..-1],
    ENV['CPPFLAGS'].nil? ? "" : ENV['CPPFLAGS'].split,
    "-I\"${5}\"".freeze, # Search paths
    "-D\"${6}\"".freeze, # Defines
    "-DGNU_COMPILER".freeze,
    ENV['CFLAGS'].nil? ? "" : ENV['CFLAGS'].split,
    "-c \"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    # gcc's list file output options are complex; no use of ${3} parameter in default config
    "-MMD".freeze,
    "-MF \"${4}\"".freeze,
    ].freeze
  }

DEFAULT_RELEASE_ASSEMBLER_TOOL = {
  :executable => ENV['AS'].nil? ? FilePathUtils.os_executable_ext('as').freeze : ENV['AS'],
  :name => 'default_release_assembler'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['AS'].nil? ? "" : ENV['AS'].split[1..-1],
    ENV['ASFLAGS'].nil? ? "" : ENV['ASFLAGS'].split,
    "-I\"${3}\"".freeze, # Search paths
    "-D\"${4}\"".freeze, # Defines (FYI--allowed with GNU assembler but ignored)
    "\"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    ].freeze
  }

DEFAULT_RELEASE_LINKER_TOOL = {
  :executable => ENV['CCLD'].nil? ? FilePathUtils.os_executable_ext('gcc').freeze : ENV['CCLD'],
  :name => 'default_release_linker'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => false.freeze,
  :arguments => [
    ENV['CCLD'].nil? ? "" : ENV['CCLD'].split[1..-1],
    ENV['CFLAGS'].nil? ? "" : ENV['CFLAGS'].split,
    ENV['LDFLAGS'].nil? ? "" : ENV['LDFLAGS'].split,
    "\"${1}\"".freeze,
    "${5}".freeze,
    "-o \"${2}\"".freeze,
    "".freeze,
    "${4}".freeze,
    ENV['LDLIBS'].nil? ? "" : ENV['LDLIBS'].split
    ].freeze
  }

DEFAULT_BACKTRACE_TOOL = {
  :executable => ENV['GDB'].nil? ? FilePathUtils.os_executable_ext('gdb').freeze : ENV['GDB'],
  :name => 'default_backtrace_reporter'.freeze,
  :stderr_redirect => StdErrRedirect::AUTO.freeze,
  :optional => true.freeze,
  :arguments => [
    '-q',
    '--eval-command run',
    '--eval-command backtrace',
    '--batch',
    '--args'
    ].freeze
  }


DEFAULT_TOOLS_TEST = {
  :tools => {
    :test_compiler => DEFAULT_TEST_COMPILER_TOOL,
    :test_linker   => DEFAULT_TEST_LINKER_TOOL,
    :test_fixture  => DEFAULT_TEST_FIXTURE_TOOL,
    :backtrace_reporter => DEFAULT_BACKTRACE_TOOL,
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
    :test_file_preprocessor_directives => DEFAULT_TEST_FILE_PREPROCESSOR_DIRECTIVES_TOOL,
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

DEFAULT_CEEDLING_CONFIG = {
    :project => {
      # :build_root must be set by user
      :use_mocks => true,
      :compile_threads => 1,
      :test_threads => 1,
      :use_test_preprocessor => false,
      :test_file_prefix => 'test_',
      :options_paths => [],
      :release_build => false,
      :use_backtrace => false,
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

    # unlike other top-level entries, environment's value is an array to preserve order
    :environment => [
      # when evaluated, this provides wider text field for rake task comments
      {:rake_columns => '120'},
    ],

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
      :vendor_path => CEEDLING_VENDOR,
      :defines => []
    },

    :cmock => {
      :vendor_path => CEEDLING_VENDOR,
      :includes => [],
      :defines => []
    },

    :cexception => {
      :vendor_path => CEEDLING_VENDOR,
      :defines => []
    },

    :test_runner => {
      :includes => [],
      :file_suffix => '_runner',
    },

    # all tools populated while building up config structure
    :tools => {},

    # empty argument lists for default tools
    # (these can be overridden in project file to add arguments to tools without totally redefining tools)
    :test_compiler  => { :arguments => [] },
    :test_assembler => { :arguments => [] },
    :test_linker    => { :arguments => [] },
    :test_fixture   => {
      :arguments => [],
      :link_objects => [], # compiled object files to always be linked in (e.g. cmock.o if using mocks)
    },
    :test_includes_preprocessor  => { :arguments => [] },
    :test_file_preprocessor      => { :arguments => [] },
    :test_file_preprocessor_directives => { :arguments => [] },
    :test_dependencies_generator => { :arguments => [] },
    :release_compiler  => { :arguments => [] },
    :release_linker    => { :arguments => [] },
    :release_assembler => { :arguments => [] },
    :release_dependencies_generator => { :arguments => [] },

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
