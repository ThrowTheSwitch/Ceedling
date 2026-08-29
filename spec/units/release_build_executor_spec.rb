# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filename_extension'
require 'rake'
require 'ceedling/release_invoker/release_build_executor'
require 'ceedling/release_invoker/release_invoker_types'

describe ReleaseBuildExecutor do
  before(:each) do
    @configurator     = double( "Configurator" )
    @loginator        = double( "Loginator" )
    @reportinator     = double( "Reportinator" )
    @batchinator      = double( "Batchinator" )
    @generator        = double( "Generator" )
    @file_finder      = double( "FileFinder" )
    @file_wrapper     = double( "FileWrapper" )
    @file_path_utils  = double( "FilePathUtils" )
    @dependinator     = double( "Dependinator" )

    @tools_release_compiler  = { name: 'fake compiler' }
    @tools_release_assembler = { name: 'fake assembler' }
    @tools_release_linker    = { name: 'fake linker' }

    allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new('.asm') )
    allow(@configurator).to receive(:tools_release_compiler).and_return( @tools_release_compiler )
    allow(@configurator).to receive(:tools_release_assembler).and_return( @tools_release_assembler )
    allow(@configurator).to receive(:tools_release_linker).and_return( @tools_release_linker )
    allow(@configurator).to receive(:project_release_build_target).and_return( 'build/release/out/project.out' )
    allow(@configurator).to receive(:project_release_build_map).and_return( 'build/release/out/project.map' )
    allow(@configurator).to receive(:release_build_artifacts).and_return( [] )
    allow(@configurator).to receive(:project_release_artifacts_path).and_return( 'build/artifacts/release' )

    allow(@file_path_utils).to receive(:form_release_build_list_filepath).and_return( 'build/release/out/list' )
    allow(@file_path_utils).to receive(:form_release_dependencies_filepath).and_return( 'build/release/dependencies/deps' )

    allow(@reportinator).to receive(:generate_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)

    # Default: no prior `.d` file on disk, and the tracker reports every target
    # stale -- i.e. every real build in this spec proceeds as an unconditional
    # fresh compile/link unless a test overrides `stale?` to exercise the skip path.
    allow(@file_wrapper).to receive(:exist?).and_return( false )
    allow(@file_wrapper).to receive(:mkdir)
    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:register_gcc_deps_file)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)

    @executor = described_class.new(
      {
        :configurator     => @configurator,
        :loginator        => @loginator,
        :reportinator     => @reportinator,
        :batchinator      => @batchinator,
        :generator        => @generator,
        :file_finder      => @file_finder,
        :file_wrapper     => @file_wrapper,
        :file_path_utils  => @file_path_utils,
        :dependinator     => @dependinator
      }
    )

    @state = ReleaseInvokerTypes::ReleaseState.new(
      :compile_flags  => [],
      :assemble_flags => [],
      :link_flags     => [],
      :defines        => [],
      :search_paths   => []
    )
  end

  # `@batchinator.exec` is a real collaborator only in production; here it's
  # stubbed to synchronously yield every `things` entry to the given block,
  # matching its real per-item iteration contract without pulling in Parallel.
  def stub_batchinator_exec
    allow(@batchinator).to receive(:exec) do |workload:, things:, &block|
      things.each { |item| block.call(item) }
    end
  end

  context "#compile_release_component (private, exercised via #compile_objects)" do
    before(:each) { stub_batchinator_exec() }

    it "compiles a C source file with the configured release compiler tool" do
      allow(@file_finder).to receive(:find_build_input_file).with( filepath: 'build/release/out/foo.o', context: RELEASE_SYM ).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )

      expect(@generator).to receive(:generate_object_file_c) do |**args|
        expect( args[:tool] ).to eq( @tools_release_compiler )
        expect( args[:source] ).to eq( 'src/foo.c' )
        expect( args[:object] ).to eq( 'build/release/out/foo.o' )
      end
      expect(@generator).to_not receive(:generate_object_file_asm)

      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end

    it "assembles an assembly source file with the configured release assembler tool" do
      allow(@file_finder).to receive(:find_build_input_file).with( filepath: 'build/release/out/foo.o', context: RELEASE_SYM ).and_return( 'src/foo.asm' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.asm' ).and_return( '.asm' )

      expect(@generator).to receive(:generate_object_file_asm) do |**args|
        expect( args[:tool] ).to eq( @tools_release_assembler )
      end
      expect(@generator).to_not receive(:generate_object_file_c)

      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end

    it "skips compiling and does not mark the object fresh when the dependency tracker reports it unchanged" do
      allow(@file_finder).to receive(:find_build_input_file).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@generator).to_not receive(:generate_object_file_c)
      expect(@dependinator).to_not receive(:mark_fresh)

      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end

    it "logs a summary line stating how many objects were recalled from cache" do
      allow(@file_finder).to receive(:find_build_input_file).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping compilation for 1 object (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping compilation for 1 object (nothing changed)..." )
      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end

    it "logs no summary line when every object needed compiling" do
      allow(@file_finder).to receive(:find_build_input_file).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@generator).to receive(:generate_object_file_c)

      expect(@loginator).to_not receive(:log).with( /Skipping compilation/ )

      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end

    it "registers the configured compiler tool as meta for a C source, and the configured assembler tool for an assembly source" do
      allow(@file_finder).to receive(:find_build_input_file).with( filepath: 'build/release/out/foo.o', context: RELEASE_SYM ).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@generator).to receive(:generate_object_file_c)

      expect(@dependinator).to receive(:register).with( 'build/release/out/foo.o', files: ['src/foo.c'], meta: hash_including( tools: [@tools_release_compiler] ) )
      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end

    it "registers the object's source before checking staleness, and its freshly-written gcc deps file after a real compile" do
      allow(@file_finder).to receive(:find_build_input_file).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@file_wrapper).to receive(:exist?).with('build/release/dependencies/deps').and_return( true )

      expect(@dependinator).to receive(:register).with( 'build/release/out/foo.o', files: ['src/foo.c'], meta: anything ).ordered
      expect(@dependinator).to receive(:register_gcc_deps_file).with('build/release/dependencies/deps').ordered # pre-compile: prior .d file, if any
      expect(@dependinator).to receive(:stale?).with('build/release/out/foo.o').and_return(true).ordered
      expect(@generator).to receive(:generate_object_file_c).ordered
      expect(@dependinator).to receive(:register_gcc_deps_file).with('build/release/dependencies/deps').ordered # post-compile: freshly-written .d file
      expect(@dependinator).to receive(:mark_fresh).with('build/release/out/foo.o').ordered

      @state.objects = ['build/release/out/foo.o']
      @executor.compile_objects( @state )
    end
  end

  context "#link" do
    before(:each) do
      @state.objects = ['build/release/out/foo.o']
    end

    it "links and marks the artifact fresh, and records that it was rebuilt, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@generator).to receive(:generate_executable_file)
      expect(@dependinator).to receive(:mark_fresh).with( 'build/release/out/project.out' )

      @executor.link( @state )

      expect( @state.executable_rebuilt ).to be(true)
    end

    it "skips linking and records that it was not rebuilt when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@generator).to_not receive(:generate_executable_file)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.link( @state )

      expect( @state.executable_rebuilt ).to be(false)
    end

    it "logs a summary line stating how many executables were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping linking for 1 executable (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping linking for 1 executable (nothing changed)..." )
      @executor.link( @state )
    end

    it "logs no summary line when the executable needed linking" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@generator).to receive(:generate_executable_file)

      expect(@loginator).to_not receive(:log).with( /Skipping linking/ )

      @executor.link( @state )
    end
  end

  context "#link -- library and library-search-path argument construction" do
    before(:each) do
      @state.objects = ['build/release/out/foo.o']
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@dependinator).to receive(:mark_fresh)
      allow(@generator).to receive(:generate_executable_file)
    end

    it "separates a configured library-extension object from plain objects before linking" do
      stub_const( "EXTENSION_LIBRARIES", FilenameExtension.new('.a') )
      @state.objects = ['build/release/out/foo.o', 'vendor/libbar.a']

      expect(@generator).to receive(:generate_executable_file) do |_tool, _sym, objects, *_rest|
        expect(objects).to eq( ['build/release/out/foo.o'] )
      end

      @executor.link( @state )
    end

    it "formats a separated library as a linker argument via the configured flag template" do
      stub_const( "EXTENSION_LIBRARIES", FilenameExtension.new('.a') )
      stub_const( "LIBRARIES_FLAG", '-l${1}' )
      @state.objects = ['build/release/out/foo.o', 'vendor/libbar.a']

      expect(@generator).to receive(:generate_executable_file) do |_tool, _sym, _objects, _flags, _target, _map, lib_args, _lib_paths|
        expect(lib_args).to eq( ['-lvendor/libbar.a'] )
      end

      @executor.link( @state )
    end

    it "includes configured system and release-only libraries as linker arguments even when nothing was separated out of the object list" do
      stub_const( "LIBRARIES_SYSTEM", ['m'] )
      stub_const( "LIBRARIES_RELEASE", ['pthread'] )
      stub_const( "LIBRARIES_FLAG", '-l${1}' )

      expect(@generator).to receive(:generate_executable_file) do |_tool, _sym, _objects, _flags, _target, _map, lib_args, _lib_paths|
        expect(lib_args).to eq( ['-lm', '-lpthread'] )
      end

      @executor.link( @state )
    end

    it "formats configured library search paths as linker arguments via the configured flag template" do
      stub_const( "PATHS_LIBRARIES", ['vendor/lib'] )
      stub_const( "LIBRARIES_PATH_FLAG", '-L${1}' )

      expect(@generator).to receive(:generate_executable_file) do |_tool, _sym, _objects, _flags, _target, _map, _lib_args, lib_paths|
        expect(lib_paths).to eq( ['-Lvendor/lib'] )
      end

      @executor.link( @state )
    end

    it "links plainly, with no library arguments, when none of the library-related project settings are configured" do
      expect(@generator).to receive(:generate_executable_file) do |_tool, _sym, objects, _flags, _target, _map, lib_args, lib_paths|
        expect(objects).to eq( ['build/release/out/foo.o'] )
        expect(lib_args).to eq( [] )
        expect(lib_paths).to eq( [] )
      end

      @executor.link( @state )
    end

    it "registers the resolved link flags and library arguments, not just the object files, as meta" do
      stub_const( "LIBRARIES_SYSTEM", ['m'] )
      stub_const( "LIBRARIES_FLAG", '-l${1}' )
      stub_const( "PATHS_LIBRARIES", ['vendor/lib'] )
      stub_const( "LIBRARIES_PATH_FLAG", '-L${1}' )
      @state.link_flags = ['-Wall']

      expect(@dependinator).to receive(:register).with(
        'build/release/out/project.out',
        files: ['build/release/out/foo.o'],
        meta:  { flags: ['-Wall'], lib_args: ['-lm'], lib_paths: ['-Lvendor/lib'], tools: [@tools_release_linker] }
      )

      @executor.link( @state )
    end
  end

  context "#artifactinate" do
    it "copies the artifact, map file, and configured extra artifacts when the executable was rebuilt" do
      @state.executable_rebuilt = true
      allow(@configurator).to receive(:release_build_artifacts).and_return( ['README.md'] )
      allow(@file_wrapper).to receive(:exist?).and_return( true )

      expect(@file_wrapper).to receive(:cp).with( 'build/release/out/project.out', 'build/artifacts/release' )
      expect(@file_wrapper).to receive(:cp).with( 'build/release/out/project.map', 'build/artifacts/release' )
      expect(@file_wrapper).to receive(:cp).with( 'README.md', 'build/artifacts/release' )

      @executor.artifactinate( @state )
    end

    it "does nothing when the executable was not rebuilt" do
      @state.executable_rebuilt = false
      expect(@file_wrapper).to_not receive(:cp)

      @executor.artifactinate( @state )
    end

    it "logs a summary line counting the target, map, and every configured extra artifact when the executable was not rebuilt" do
      @state.executable_rebuilt = false
      allow(@configurator).to receive(:release_build_artifacts).and_return( ['README.md', 'CHANGELOG.md'] )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping artifact collection for 4 artifacts (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping artifact collection for 4 artifacts (nothing changed)..." )
      @executor.artifactinate( @state )
    end

    it "logs no summary line when the executable was rebuilt" do
      @state.executable_rebuilt = true
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:cp)

      expect(@loginator).to_not receive(:log).with( /Skipping artifact collection/ )

      @executor.artifactinate( @state )
    end

    it "skips a configured artifact that doesn't exist on disk" do
      @state.executable_rebuilt = true
      allow(@file_wrapper).to receive(:exist?).and_return( false )

      expect(@file_wrapper).to_not receive(:cp)

      @executor.artifactinate( @state )
    end
  end
end
