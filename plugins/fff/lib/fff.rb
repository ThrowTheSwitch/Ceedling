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

require 'fileutils'
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
    # CMock's levels: 0 errors only, 1 warnings, 2 normal, 3 verbose
    @verbosity      = @cm_config.verbosity

    # The additional files to include in the fake files, gathered as CMock gathers them
    @includes_h_pre_orig_header  = quoted( @cm_config.includes, @cm_config.includes_h_pre_orig_header )
    @includes_h_post_orig_header = quoted( @cm_config.includes_h_post_orig_header )
    @includes_c_pre_header       = quoted( @cm_config.includes_c_pre_header )
    @includes_c_post_header      = quoted( @cm_config.includes_c_post_header )
  end

  # Matches CMock's own entry point, which Ceedling calls with the folder a mock's
  # #include names. A fake is written below the mock root at that folder, as CMock would.
  def setup_mocks(files, folder = nil)
    [files].flatten.each do |src|
      generate_mock(src, folder)
    end
  end

  def generate_mock(header_file_to_mock, folder=nil)
    module_name = File.basename(header_file_to_mock, '.*')
    puts( "Creating fake functions for #{module_name}..." ) unless @verbosity < 2
    mock_name = @cm_config.mock_prefix + module_name + @cm_config.mock_suffix

    # Parse the header file so we know what to mock.
    parsed_header = @cm_parser.parse(module_name, File.read(header_file_to_mock))

    path = "#{mock_path_for( folder )}/#{mock_name}"
    write_fake( path, header_file_to_mock, mock_name, parsed_header, folder )
    write_header_copy( File.join( File.dirname( path ), File.basename( header_file_to_mock ) ), parsed_header )
  end

  # The name for a fake's guard and control functions, as CMock forms it. Every name has the
  # characters a C identifier can't hold turned to `_`, as Unity's TypeSanitizer does. That is
  # Unity's rule, not CIdentifier's, since the runner Unity generates must call the very names
  # this forms. With :mock_name_include_folder, the folder below the mock root comes first, so
  # two same-named fakes stay distinct and match the runner's calls. A leading ./ is dropped.
  def c_name_for(mock_name, folder)
    mock_folder = [@cm_config.subdir, folder].compact
    identity    = mock_name
    if @cm_config.mock_name_include_folder && !mock_folder.empty?
      identity = File.join( *mock_folder, '' ).sub( %r{\A(?:\.[/\\])+}, '' ) + mock_name
    end

    return identity.gsub( %r{[-/\\.,\s]}, '_' )
  end

  private

  # The directory a fake is written to: the mock root, the folder its #include names,
  # then any configured :subdir
  def mock_path_for(folder)
    mock_path = folder.nil? ? @cm_config.mock_path : File.join( @cm_config.mock_path, folder )
    return @cm_config.subdir ? "#{mock_path}/#{@cm_config.subdir}" : mock_path
  end

  # Writes the fake's header and source at `path`, which ends in the mock's name. The header
  # takes the original header's extension, as CMock's mock does. `folder` is the one its
  # #include names, which names the fake's C identifiers and through which the fake includes
  # the original header.
  def write_fake(path, header_file, mock_name, parsed_header, folder)
    module_name = File.basename( header_file, '.*' )
    module_ext  = File.extname( header_file )
    c_name      = c_name_for( mock_name, folder )
    FileUtils.mkdir_p( File.dirname( path ) )

    puts( "Creating fake functions: #{path}#{module_ext} and #{path}.c" ) unless @verbosity < 3
    File.write( "#{path}#{module_ext}", FffMockGenerator.create_mock_header( module_name, mock_name, parsed_header,
      @includes_h_pre_orig_header, @includes_h_post_orig_header, c_name: c_name, header_include: header_include( module_name, module_ext, folder ) ) )

    File.write( "#{path}.c", FffMockGenerator.create_mock_source( mock_name, parsed_header,
      @includes_c_pre_header, @includes_c_post_header, c_name: c_name, mock_header: "#{mock_name}#{module_ext}" ) )
  end

  # Under :treat_inlines :include, the header's text without its inline bodies, written beside
  # the fake as CMock writes it beside a mock. The fake's #include reaches this copy, so the
  # header's inline definitions never meet the fake's.
  def write_header_copy(path, parsed_header)
    return unless @cm_config.treat_inlines == :include

    File.write( path, parsed_header[:normalized_source] )
  end

  # The text a fake includes the original header by: the folder its #include names and the
  # header's filename, as CMock writes it, or Ceedling's respelling where the test's search
  # paths reach the header only by another spelling (:orig_header_include)
  def header_include(module_name, module_ext, folder)
    respelled = @cm_config.respond_to?( :orig_header_include ) ? @cm_config.orig_header_include : nil
    return respelled || File.join( *[folder].compact, "#{module_name}#{module_ext}" )
  end

  # Joins include lists, each named once, as #include operands. A name holding `<` is
  # kept as written, and any other is quoted, as CMock does.
  def quoted(*lists)
    return lists.compact.flatten.uniq.map { |name| name.match?( /</ ) ? name : "\"#{name}\"" }
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
