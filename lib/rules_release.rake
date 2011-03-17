
RELEASE_COMPILE_TASK_ROOT  = RELEASE_TASK_ROOT + 'compile:'
RELEASE_ASSEMBLE_TASK_ROOT = RELEASE_TASK_ROOT + 'assemble:'


if (RELEASE_BUILD_USE_ASSEMBLY)
rule(/#{PROJECT_RELEASE_BUILD_OUTPUT_ASM_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      @ceedling[:file_finder].find_assembly_file(task_name)
    end  
  ]) do |object|
  @ceedling[:generator].generate_object_file(TOOLS_RELEASE_ASSEMBLER, RELEASE_CONTEXT, object.source, object.name)
end
end


rule(/#{PROJECT_RELEASE_BUILD_OUTPUT_C_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      @ceedling[:file_finder].find_compilation_input_file(task_name)
    end  
  ]) do |object|
  @ceedling[:generator].generate_object_file(TOOLS_RELEASE_COMPILER, RELEASE_CONTEXT, object.source, object.name)
end


rule(/#{PROJECT_RELEASE_BUILD_TARGET}/) do |bin_file|
  @ceedling[:generator].generate_executable_file(TOOLS_RELEASE_LINKER, RELEASE_CONTEXT, bin_file.prerequisites, bin_file.name)
end


namespace RELEASE_CONTEXT do
  # use rules to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)

  namespace :compile do
    rule(/^#{RELEASE_COMPILE_TASK_ROOT}\S+#{'\\'+EXTENSION_SOURCE}$/ => [ # compile task names by regex
        proc do |task_name|
          source = task_name.sub(/#{RELEASE_COMPILE_TASK_ROOT}/, '')
          @ceedling[:file_finder].find_source_file(source, :error)
        end
    ]) do |compile|
      @ceedling[:rake_wrapper][:directories].invoke
      @ceedling[:project_config_manager].process_release_config_change
      @ceedling[:release_invoker].setup_and_invoke_c_objects( [compile.source] )
    end
  end
  
  if (RELEASE_BUILD_USE_ASSEMBLY)
  namespace :assemble do
    rule(/^#{RELEASE_ASSEMBLE_TASK_ROOT}\S+#{'\\'+EXTENSION_ASSEMBLY}$/ => [ # assemble task names by regex
        proc do |task_name|
          source = task_name.sub(/#{RELEASE_ASSEMBLE_TASK_ROOT}/, '')
          @ceedling[:file_finder].find_assembly_file(source)
        end
    ]) do |assemble|
      @ceedling[:rake_wrapper][:directories].invoke
      @ceedling[:project_config_manager].process_release_config_change
      @ceedling[:release_invoker].setup_and_invoke_asm_objects( [assemble.source] )
    end
  end
  end

end

