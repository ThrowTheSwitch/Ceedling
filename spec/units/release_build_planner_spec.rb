# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/release_invoker/release_build_planner'

describe ReleaseBuildPlanner do
  before(:each) do
    @configurator     = double( "Configurator" )
    @loginator        = double( "Loginator" )
    @reportinator     = double( "Reportinator" )
    @flaginator       = double( "Flaginator" )
    @defineinator     = double( "Defineinator" )
    @file_path_utils  = double( "FilePathUtils" )
    @file_wrapper     = double( "FileWrapper" )

    @planner = described_class.new(
      {
        :configurator    => @configurator,
        :loginator       => @loginator,
        :reportinator    => @reportinator,
        :flaginator      => @flaginator,
        :defineinator    => @defineinator,
        :file_path_utils => @file_path_utils,
        :file_wrapper    => @file_wrapper
      }
    )

    @state = ReleaseInvokerTypes::ReleaseState.new()

    allow(@configurator).to receive(:tools_release_compiler).and_return( { executable: 'gcc', arguments: [] } )
    allow(@configurator).to receive(:tools_release_linker).and_return( { executable: 'gcc', arguments: [] } )
    allow(@configurator).to receive(:project_release_build_target).and_return( 'build/release/out/project.out' )
    allow(@configurator).to receive(:collection_release_build_input).and_return( ['src/Foo.c'] )
    allow(@configurator).to receive(:collection_release_artifact_extra_link_objects).and_return( [] )
    allow(@configurator).to receive(:collection_paths_include).and_return( ['src'] )

    allow(@flaginator).to receive(:flag_down).and_return( [] )
    allow(@defineinator).to receive(:defines).and_return( [] )
    allow(@file_path_utils).to receive(:form_release_build_objects_filelist) { |files| files.map { |f| "build/release/out/#{File.basename(f, '.*')}.o" } }
  end

  describe "#plan" do
    it "computes the object list from the full release source collection when files is nil" do
      @planner.plan( @state, files: nil )
      expect( @state.objects ).to eq( ['build/release/out/Foo.o'] )
    end

    it "includes extra link-only objects alongside the compiled sources" do
      allow(@configurator).to receive(:collection_release_artifact_extra_link_objects).and_return( ['vendor/cexception/CException.o'] )
      expect(@file_path_utils).to receive(:form_release_build_objects_filelist).with( ['src/Foo.c', 'vendor/cexception/CException.o'] ).and_return( [] )
      @planner.plan( @state, files: nil )
    end

    it "scopes the object list to just the given file when files is provided, ignoring the full source collection" do
      expect(@file_path_utils).to receive(:form_release_build_objects_filelist).with( ['src/Bar.c'] ).and_return( ['build/release/out/Bar.o'] )
      @planner.plan( @state, files: ['src/Bar.c'] )
      expect( @state.objects ).to eq( ['build/release/out/Bar.o'] )
    end

    it "resolves compile, assemble, and link flags once for the whole build, with no per-file matcher" do
      expect(@flaginator).to receive(:flag_down).with( context: RELEASE_SYM, operation: OPERATION_COMPILE_SYM ).and_return( ['-Wall'] )
      expect(@flaginator).to receive(:flag_down).with( context: RELEASE_SYM, operation: OPERATION_ASSEMBLE_SYM ).and_return( ['-mthumb'] )
      expect(@flaginator).to receive(:flag_down).with( context: RELEASE_SYM, operation: OPERATION_LINK_SYM ).and_return( ['-static'] )

      @planner.plan( @state, files: nil )

      expect( @state.compile_flags ).to eq( ['-Wall'] )
      expect( @state.assemble_flags ).to eq( ['-mthumb'] )
      expect( @state.link_flags ).to eq( ['-static'] )
    end

    it "resolves defines once for the whole build" do
      expect(@defineinator).to receive(:defines).with( subkey: RELEASE_SYM ).and_return( ['FEATURE_X=ON'] )
      @planner.plan( @state, files: nil )
      expect( @state.defines ).to eq( ['FEATURE_X=ON'] )
    end

    it "resolves search paths from the project's include path collection" do
      @planner.plan( @state, files: nil )
      expect( @state.search_paths ).to eq( ['src'] )
    end

    context "tool tag tailoring" do
      it "leaves tools untouched for a plain executable target" do
        compiler = { executable: 'gcc', arguments: [] }
        linker   = { executable: 'gcc', arguments: [] }
        allow(@configurator).to receive(:tools_release_compiler).and_return( compiler )
        allow(@configurator).to receive(:tools_release_linker).and_return( linker )
        allow(@configurator).to receive(:project_release_build_target).and_return( 'build/release/out/project.out' )

        @planner.plan( @state, files: nil )

        expect( compiler[:arguments] ).to eq( [] )
        expect( linker[:arguments] ).to eq( [] )
        expect( linker[:executable] ).to eq( 'gcc' )
      end

      it "adds -fPIC and -shared for a .so target using the default compiler" do
        compiler = { executable: 'gcc', arguments: [] }
        linker   = { executable: 'gcc', arguments: [] }
        allow(@configurator).to receive(:tools_release_compiler).and_return( compiler )
        allow(@configurator).to receive(:tools_release_linker).and_return( linker )
        allow(@configurator).to receive(:project_release_build_target).and_return( 'build/release/out/project.so' )

        @planner.plan( @state, files: nil )

        expect( compiler[:arguments] ).to include( '-fPIC' )
        expect( linker[:arguments] ).to include( '-shared' )
      end

      it "swaps the linker for ar and adds -fPIC for a .a target using the default compiler" do
        compiler = { executable: 'gcc', arguments: [] }
        linker   = { executable: 'gcc', arguments: [] }
        allow(@configurator).to receive(:tools_release_compiler).and_return( compiler )
        allow(@configurator).to receive(:tools_release_linker).and_return( linker )
        allow(@configurator).to receive(:project_release_build_target).and_return( 'build/release/out/project.a' )

        @planner.plan( @state, files: nil )

        expect( compiler[:arguments] ).to include( '-fPIC' )
        expect( linker[:executable] ).to eq( 'ar' )
        expect( linker[:arguments] ).to eq( ['rcs', '${2}', '${1}'] )
      end

      it "does nothing when the project has configured its own compiler tool (not the Ceedling default)" do
        compiler = { executable: 'my-custom-gcc', arguments: [] }
        linker   = { executable: 'gcc', arguments: [] }
        allow(@configurator).to receive(:tools_release_compiler).and_return( compiler )
        allow(@configurator).to receive(:tools_release_linker).and_return( linker )
        allow(@configurator).to receive(:project_release_build_target).and_return( 'build/release/out/project.so' )

        @planner.plan( @state, files: nil )

        expect( compiler[:arguments] ).to eq( [] )
        expect( linker[:arguments] ).to eq( [] )
      end
    end
  end
end
