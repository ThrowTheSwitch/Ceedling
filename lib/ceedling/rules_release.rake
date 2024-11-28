# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

RELEASE_COMPILE_TASK_ROOT  = RELEASE_TASK_ROOT + 'compile:'  unless defined?(RELEASE_COMPILE_TASK_ROOT)
RELEASE_ASSEMBLE_TASK_ROOT = RELEASE_TASK_ROOT + 'assemble:' unless defined?(RELEASE_ASSEMBLE_TASK_ROOT)

# If GCC and Releasing a Library, Update Tools to Automatically Have Necessary Tags
if (TOOLS_RELEASE_COMPILER[:executable] == DEFAULT_RELEASE_COMPILER_TOOL[:executable])
  if (File.extname(PROJECT_RELEASE_BUILD_TARGET) == '.so')
    TOOLS_RELEASE_COMPILER[:arguments] << "-fPIC" unless TOOLS_RELEASE_COMPILER[:arguments].include?("-fPIC")
    TOOLS_RELEASE_LINKER[:arguments] << "-shared" unless TOOLS_RELEASE_LINKER[:arguments].include?("-shared")
  elsif (File.extname(PROJECT_RELEASE_BUILD_TARGET) == '.a')
    TOOLS_RELEASE_COMPILER[:arguments] << "-fPIC" unless TOOLS_RELEASE_COMPILER[:arguments].include?("-fPIC")
    TOOLS_RELEASE_LINKER[:executable] = 'ar'
    TOOLS_RELEASE_LINKER[:arguments] = ['rcs', '${2}', '${1}'].compact
  end
end

rule(/#{PROJECT_RELEASE_BUILD_OUTPUT_PATH}\/#{'.+' + Regexp.escape(EXTENSION_OBJECT)}$/ => [
    proc do |task_name|
      @ceedling[:file_finder].find_build_input_file(filepath: task_name, complain: :error, context: RELEASE_SYM)
    end
  ]) do |object|

  if @ceedling[:file_wrapper].extname(object.source) != EXTENSION_ASSEMBLY
    @ceedling[:generator].generate_object_file_c(
      tool:         TOOLS_RELEASE_COMPILER,
      module_name:  File.basename(object.source).ext(), # Source filename as module name
      context:      RELEASE_SYM,
      source:       object.source,
      object:       object.name,
      search_paths: COLLECTION_PATHS_INCLUDE,
      flags:        @ceedling[:flaginator].flag_down( context:RELEASE_SYM, operation:OPERATION_COMPILE_SYM ),
      defines:      @ceedling[:defineinator].defines( subkey:RELEASE_SYM ),
      list:         @ceedling[:file_path_utils].form_release_build_list_filepath( object.name ),
      dependencies: @ceedling[:file_path_utils].form_release_dependencies_filepath( object.name ) )
  else
    @ceedling[:generator].generate_object_file_asm(
      tool:         TOOLS_RELEASE_ASSEMBLER,
      module_name:  File.basename(object.source).ext(), # Source filename as module name
      context:      RELEASE_SYM,
      source:       object.source,
      object:       object.name,
      search_paths: COLLECTION_PATHS_INCLUDE,
      flags:        @ceedling[:flaginator].flag_down( context:RELEASE_SYM, operation:OPERATION_ASSEMBLE_SYM ),
      defines:      @ceedling[:defineinator].defines( subkey:RELEASE_SYM ),
      list:         @ceedling[:file_path_utils].form_release_build_list_filepath( object.name ),
      dependencies: @ceedling[:file_path_utils].form_release_dependencies_filepath( object.name ) )
  end
end

rule(/#{PROJECT_RELEASE_BUILD_TARGET}/) do |bin_file|
  objects, libraries = @ceedling[:release_invoker].sort_objects_and_libraries(bin_file.prerequisites)
  tool      = TOOLS_RELEASE_LINKER.clone
  lib_args  = @ceedling[:release_invoker].convert_libraries_to_arguments(libraries)
  lib_paths = @ceedling[:release_invoker].get_library_paths_to_arguments()
  map_file  = @ceedling[:configurator].project_release_build_map

  @ceedling[:generator].generate_executable_file(
    tool,
    RELEASE_SYM,
    objects,
    [], # Flags
    bin_file.name,
    map_file,
    lib_args,
    lib_paths )
  @ceedling[:release_invoker].artifactinate( bin_file.name, map_file, @ceedling[:configurator].release_build_artifacts )
end

namespace RELEASE_SYM do
  # Use rules to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)

  # Unadvertised Rake tasks to execute source file compilation
  namespace :compile do
    rule(/^#{RELEASE_COMPILE_TASK_ROOT}\S+(#{Regexp.escape(EXTENSION_SOURCE)}|#{Regexp.escape(EXTENSION_CORE_SOURCE)})$/ => [ # compile task names by regex
        proc do |task_name|
          source = task_name.sub(/#{RELEASE_COMPILE_TASK_ROOT}/, '')
          @ceedling[:file_finder].find_source_file(source)
        end
    ]) do |compile|
      @ceedling[:rake_wrapper][:prepare].invoke
      @ceedling[:release_invoker].setup_and_invoke_objects( [compile.source] )
    end
  end

  # Unadvertised Rake tasks to execute source file assembly
  if (RELEASE_BUILD_USE_ASSEMBLY)
  namespace :assemble do
    rule(/^#{RELEASE_ASSEMBLE_TASK_ROOT}\S+#{Regexp.escape(EXTENSION_ASSEMBLY)}$/ => [ # assemble task names by regex
        proc do |task_name|
          source = task_name.sub(/#{RELEASE_ASSEMBLE_TASK_ROOT}/, '')
          @ceedling[:file_finder].find_assembly_file(source)
        end
    ]) do |assemble|
      @ceedling[:rake_wrapper][:prepare].invoke
      @ceedling[:release_invoker].setup_and_invoke_objects( [assemble.source] )
    end
  end
  end

end

