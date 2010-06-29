require 'constants'
require 'file_path_utils'


DEFAULT_TEST_COMPILER_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_test_compiler',
  :arguments => [
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_TOOLCHAIN_INCLUDE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_AND_SOURCE_AND_INCLUDE'},
    {"-D$" => 'COLLECTION_DEFINES_TEST'},
    {"$" => 'TEST_COMPILER_ARGUMENTS'},
    "-c ${1}",
    "-o ${2}",
    ]
  }

DEFAULT_TEST_LINKER_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_test_linker',
  :arguments => [
    {"$" => 'TEST_LINKER_ARGUMENTS'},
    "${1}",
    "-o ${2}",
    ]
  }
  
DEFAULT_TEST_FIXTURE_TOOL = {
  :executable => '${1}',
  :name => 'default_test_fixture',
  :arguments => [
    {"$" => 'TEST_FIXTURE_ARGUMENTS'},
    ]
  }



DEFAULT_TEST_INCLUDES_PREPROCESSOR_TOOL = {
  :executable => FilePathUtils.ext_exe('cpp'),
  :name => 'default_test_includes_preprocessor',
  :arguments => [
    '-MM', '-MG',
    {"-I\"$\"" => 'COLLECTION_PATHS_SOURCE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_INCLUDE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST'},
    {"-I\"$\"" => 'COLLECTION_PATHS_SUPPORT'},
    {"-D$" => 'COLLECTION_DEFINES_TEST'},
    {"-D$" => 'DEFINES_TEST_PREPROCESS'},
    {"$" => 'TEST_INCLUDES_PREPROCESSOR_ARGUMENTS'},
    '-w',
    '-nostdinc',
    "\"${1}\""
    ]
  }

DEFAULT_TEST_FILE_PREPROCESSOR_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_test_file_preprocessor',
  :arguments => [
    '-E',
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_AND_SOURCE_AND_INCLUDE'},
    {"-I\"$\"" => 'PATHS_TEST_TOOLCHAIN_INCLUDE'},
    {"-D$" => 'COLLECTION_DEFINES_TEST'},
    {"-D$" => 'DEFINES_TEST_PREPROCESS'},
    {"$" => 'TEST_FILE_PREPROCESSOR_ARGUMENTS'},
    "\"${1}\"",
    "-o \"${2}\""
    ]
  }

DEFAULT_TEST_DEPENDENCIES_GENERATOR_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_test_dependencies_generator',
  :arguments => [
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_AND_SOURCE_AND_INCLUDE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_TOOLCHAIN_INCLUDE'},
    {"-D$" => 'COLLECTION_DEFINES_TEST'},   
    {"-D$" => 'DEFINES_TEST_PREPROCESS'},     
    "-MT \"${3}\"",
    '-MM', '-MD', '-MG',
    "-MF \"${2}\"",
    {"$" => 'TEST_DEPENDENCIES_GENERATOR_ARGUMENTS'},
    "-c \"${1}\"",
    ]
  }

DEFAULT_RELEASE_DEPENDENCIES_GENERATOR_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_release_dependencies_generator',
  :arguments => [
    {"-I\"$\"" => 'COLLECTION_PATHS_SOURCE_AND_INCLUDE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_RELEASE_TOOLCHAIN_INCLUDE'},
    {"-D$" => 'DEFINES_RELEASE'},
    {"-D$" => 'DEFINES_RELEASE_PREPROCESS'},
    "-MT \"${3}\"",
    '-MM', '-MD', '-MG',
    "-MF \"${2}\"",
    {"$" => 'RELEASE_DEPENDENCIES_GENERATOR_ARGUMENTS'},
    "-c \"${1}\"",
    ]
  }


DEFAULT_RELEASE_COMPILER_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_release_compiler',
  :arguments => [
    {"-I\"$\"" => 'COLLECTION_PATHS_RELEASE_TOOLCHAIN_INCLUDE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_SOURCE_AND_INCLUDE'},
    {"-D$" => 'DEFINES_RELEASE'},        
    {"$" => 'RELEASE_COMPILER_ARGUMENTS'},
    "-c \"${1}\"",
    "-o \"${2}\"",
    ]
  }

DEFAULT_RELEASE_ASSEMBLER_TOOL = {
  :executable => FilePathUtils.ext_exe('as'),
  :name => 'default_release_assembler',
  :arguments => [
    {"-I\"$\"" => 'COLLECTION_PATHS_SOURCE_AND_INCLUDE'},
    {"-I\"$\"" => 'COLLECTION_PATHS_TARGET_INCLUDE'},
    {"$" => 'RELEASE_ASSEMBLER_ARGUMENTS'},
    '${1}',
    "-o \"${2}\"",
    ]
  }

DEFAULT_RELEASE_LINKER_TOOL = {
  :executable => FilePathUtils.ext_exe('gcc'),
  :name => 'default_release_linker',
  :arguments => [
    {"$" => 'RELEASE_LINKER_ARGUMENTS'},
    '${1}',
    "-o \"${2}\"",
    ]
  }


DEFAULT_CEEDLING_CONFIG = {
    :project => {
      :logging => false,
      :use_exceptions => true,
      :use_mocks => true,
      :use_test_preprocessor => false,
      :use_auxiliary_dependencies => false,
      :test_file_prefix => 'test_',
      :verbosity => Verbosity::NORMAL,
      :options_path => NULL_FILE_PATH,
      :release_build => false,
    },

    :release_build => {
      :output => 'project.out',
      :use_assembly => false,      
    },

    :paths => {
      :test => [],
      :source => [],
      :support => [],
      :include => [],
      :test_toolchain_include => [],
      :release_toolchain_include => [],
    },
    
    # unlike other top-level entries, environment's value is an array to preserve order
    :environment => [
      # when evaludated, this provides wider text field for rake task comments
      {:rake_columns => '120'},
    ],
    
    :defines => {
      :test => [],
      :test_preprocess => [],
      :release => [],
      :release_preprocess => [],
    },
    
    :extension => {
      :header => '.h',
      :source => '.c',
      :assembly => '.s',
      :object => '.o',
      :executable => '.out',
      :testpass => '.pass',
      :testfail => '.fail',
      :dependencies => '.d',
    },

    :unity => {
      :int_width => 32,
      :exclude_float => false,
      :float_type => 'float',    
      :float_precision => '0.00001f',
    },

    :test_runner => {
      :includes => [],
      :file_suffix => '_runner',
    },

    # all tools populated while building up config structure
    :tools => {},

    # empty argument lists for default tools
    # (these can be overridden in project file to add arguments to tools without totally redefining tools)
    :test_compiler => { :arguments => [] },
    :test_linker   => { :arguments => [] },
    :test_fixture  => { :arguments => [] },
    :test_includes_preprocessor  => { :arguments => [] },
    :test_file_preprocessor      => { :arguments => [] },
    :test_dependencies_generator => { :arguments => [] },
    :release_compiler  => { :arguments => [] },
    :release_linker    => { :arguments => [] },
    :release_assembler => { :arguments => [] },
    :release_dependencies_generator => { :arguments => [] },

    :plugins => {
      :base_path => NULL_FILE_PATH,
      :auxiliary_load_path => NULL_FILE_PATH,
      :enabled => [],
    }
  }
