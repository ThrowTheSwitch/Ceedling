

desc "Build release target."
task :release => [:directories] do
  @ceedling[:release_invoker].setup_and_invoke
end


namespace :release do

  namespace :compile do
    COLLECTION_ALL_SOURCE.each do |source|
      # by source file name
      object = @ceedling[:file_path_utils].form_release_c_object_filepath(source)
      name   = File.basename(source)
      task name.to_sym => [:directories, object]
    end
  end

  namespace :assemble do
    COLLECTION_ALL_ASSEMBLY.each do |source|
      # by source file name
      object = @ceedling[:file_path_utils].form_release_asm_object_filepath(source)
      name   = File.basename(source)
      task name.to_sym => [:directories, object]
    end
  end

end