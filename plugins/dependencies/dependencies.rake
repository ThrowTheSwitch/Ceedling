
DEPENDENCIES_LIBRARIES.each do |deplib|

  # Make sure the required working directory exists
  # (don't worry about the subdirectories. That's the job of the dep's build tool)
  deplib_working_path = @ceedling[DEPENDENCIES_SYM].get_working_path(deplib)
  directory(deplib_working_path)
  task :directories => [ deplib_working_path ]

  # Add a rule for building the actual libraries from dependency list
  @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib).each do |libpath|
    file libpath do |filetask|
      path = filetask.name

      # We double-check that it doesn't already exist, because this process sometimes
      # produces multiple files, but they may have already been flagged as invoked
      unless (File.exists?(path))

        # Set Environment Variables, Fetch, and Build
        @ceedling[DEPENDENCIES_SYM].set_env_if_required(path)
        @ceedling[DEPENDENCIES_SYM].fetch_if_required(path)
        @ceedling[DEPENDENCIES_SYM].build_if_required(path)
      end
    end
  end

  # Finally, add the static libraries to our RELEASE build dependency list
  task RELEASE_SYM => @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib) 

  namespace DEPENDENCIES_SYM do
    namespace :make do
      # Add task to directly just build this dependency
      task @ceedling[DEPENDENCIES_SYM].get_name(deplib) => @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib)
    end

    namespace :clean do
      # Add task to directly clobber this dependency
      task @ceedling[DEPENDENCIES_SYM].get_name(deplib) do
        raise "TODO: dependency tool can't clean dependencies yet"
      end
    end
  end
end

# Add any artifact:include folders to our release & test includes paths so linking and mocking work.
@ceedling[DEPENDENCIES_SYM].add_headers()

# Add tasks for building or cleaning ALL depencies
namespace DEPENDENCIES_SYM do
  desc "Build any missing dependencies."
  task :make => DEPENDENCIES_LIBRARIES.map{|deplib| "#{DEPENDENCIES_SYM}:make:#{@ceedling[DEPENDENCIES_SYM].get_name(deplib)}"}
  
  desc "Clean all dependencies."
  task :clean => DEPENDENCIES_LIBRARIES.map{|deplib| "#{DEPENDENCIES_SYM}:clean:#{@ceedling[DEPENDENCIES_SYM].get_name(deplib)}"}
end

namespace :files do
  desc "List all collected dependency libraries."
  task :dependencies do
    puts "dependency files:"
    deps = []
    DEPENDENCIES_LIBRARIES.each do |deplib|
      deps << @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib)
      deps << @ceedling[DEPENDENCIES_SYM].get_dynamic_libraries_for_dependency(deplib)
    end
    deps.flatten!
    deps.sort.each {|dep| puts " - #{dep}"}
    puts "file count: #{deps.size}"
  end
end

# Add task to copy dynamic libraries to the release folder when finished
#TODO master task depends on all individual dlls in release dir. 
#individual dlls in release depend on dlls in artifact dir. task is just a copy. bam. done
