# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
#
#   Derived from the Fake Function Framework Ceedling plugin, absorbed as a
#   modified snapshot in 2024 after seven years as a submodule.
#   Copyright (c) 2018 ElectronVector -- MIT
#   ⏩️ https://github.com/ElectronVector/fake_function_framework
# =========================================================================

require 'ceedling/plugins/plugin'
require 'fff_mock_generator'

class Fff < Plugin

  # Set up Ceedling to use this plugin
  def setup
    @ceedling[:loginator].log( "Using Fake Function Framework (fff)...", Verbosity::OBNOXIOUS )
  end

  def post_runner_generate(arg_hash)
    # After the test runner file has been created, append the FFF globals
    # definition to the end of the test runner. These globals will be shared by
    # all mocks linked into the test.
    File.open(arg_hash[:runner_file], 'a') do |f|
      f.puts
      f.puts "//=======Defintions of FFF variables====="
      f.puts %{#include "fff.h"}
      f.puts "DEFINE_FFF_GLOBALS;"
    end
  end

end # class Fff

class FffCMockWrapper

    def initialize(options=nil)
    @cm_config      = CMockConfig.new(options)
    @cm_parser      = CMockHeaderParser.new(@cm_config)
    @silent        = (@cm_config.verbosity < 2)

    # These are the additional files to include in the mock files.
    @includes_h_pre_orig_header  = (@cm_config.includes || @cm_config.includes_h_pre_orig_header || []).map{|h| h.match?(/</) ? h : "\"#{h}\""}
    @includes_h_post_orig_header = (@cm_config.includes_h_post_orig_header || []).map{|h| h.match?(/</) ? h : "\"#{h}\""}
    @includes_c_pre_header       = (@cm_config.includes_c_pre_header || []).map{|h| h.match?(/</) ? h : "\"#{h}\""}
    @includes_c_post_header      = (@cm_config.includes_c_post_header || []).map{|h| h.match?(/</) ? h : "\"#{h}\""}
  end

  # Matches CMock's own entry point, which Ceedling calls with the folder a mock's
  # #include names. A fake is written below the mock root at that folder, as CMock would.
  def setup_mocks(files, folder = nil)
    [files].flatten.each do |src|
      generate_mock(src, folder)
    end
  end

  def generate_mock(header_file_to_mock, folder=nil)
      module_name = File.basename(header_file_to_mock, '.h')
      puts( "Creating fake functions for #{module_name}..." ) unless @silent
      mock_name = @cm_config.mock_prefix + module_name + @cm_config.mock_suffix
      mock_path = folder.nil? ? @cm_config.mock_path : File.join(@cm_config.mock_path, folder)
      if @cm_config.subdir
          # If a subdirectory has been configured, append it to the mock path.
          mock_path = "#{mock_path}/#{@cm_config.subdir}"
      end
      full_path_for_mock = "#{mock_path}/#{mock_name}"
      c_name = c_name_for(mock_name, folder)

      # Parse the header file so we know what to mock.
      parsed_header = @cm_parser.parse(module_name, File.read(header_file_to_mock))

      # Create the directory if it doesn't exist.
      mkdir_p full_path_for_mock.pathmap("%d")

      # Generate the fake function header file.
      puts( "Creating fake functions: #{full_path_for_mock}.h" )

      # Create the mock header.
      File.open("#{full_path_for_mock}.h", 'w') do |f|
        f.write(FffMockGenerator.create_mock_header(module_name, mock_name, parsed_header,
          @includes_h_pre_orig_header, @includes_h_post_orig_header, c_name: c_name))
      end

      # Create the mock source file.
      File.open("#{full_path_for_mock}.c", 'w') do |f|
        f.write(FffMockGenerator.create_mock_source(mock_name, parsed_header,
          @includes_c_pre_orig_header, @includes_c_post_orig_header, c_name: c_name))
      end
  end

  # The name for a fake's guard and control functions, as CMock forms it. With
  # :mock_name_include_folder, the folder below the mock root comes first, so two
  # same-named fakes stay distinct and match the runner's calls. A leading ./ is
  # dropped, and characters a C identifier can't hold become `_`, as Unity's
  # TypeSanitizer does.
  def c_name_for(mock_name, folder)
    mock_folder = [@cm_config.subdir, folder].compact
    return mock_name unless @cm_config.mock_name_include_folder && !mock_folder.empty?

    identity = File.join( *mock_folder, '' ).sub( %r{\A(?:\.[/\\])+}, '' ) + mock_name
    return identity.gsub( %r{[-/\\.,\s]}, '_' )
  end

end

# Switch out the CMock with FFF Mock Generator
if !self.class.const_defined?(:RealCMock)
  if !self.class.const_defined?(:CMock)
    require "cmock"
    RealCMock = CMock
  end
  self.class.send(:remove_const, :CMock)
  CMock = FffCMockWrapper
end
