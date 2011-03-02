
rule(/#{PROJECT_RELEASE_BUILD_OUTPUT_ASM_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      @ceedling[:file_finder].find_assembly_file(task_name)
    end  
  ]) do |object|
  @ceedling[:generator].generate_object_file(TOOLS_RELEASE_ASSEMBLER, object.source, object.name)
end


rule(/#{PROJECT_RELEASE_BUILD_OUTPUT_C_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      @ceedling[:file_finder].find_compilation_input_file(task_name)
    end  
  ]) do |object|
  @ceedling[:generator].generate_object_file(TOOLS_RELEASE_COMPILER, object.source, object.name)
end


rule(/#{PROJECT_RELEASE_BUILD_TARGET}/) do |bin_file|
  @ceedling[:generator].generate_executable_file(TOOLS_RELEASE_LINKER, bin_file.prerequisites, bin_file.name)
end


