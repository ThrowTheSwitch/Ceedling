
DEPENDENCIES_LIBRARIES.each do |deplib|

  # Look up the name of this dependency library
  deplib_name = @ceedling[DEPENDENCIES_SYM].get_name(deplib)

  # Make sure the required working directories exists
  # (don't worry about the subdirectories. That's the job of the dep's build tool)
  paths = @ceedling[DEPENDENCIES_SYM].get_working_paths(deplib)
  paths.each {|path| directory(path) }
  task :directories => paths

  # Add a rule for building the actual libraries from dependency list
  ( @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib) +
    @ceedling[DEPENDENCIES_SYM].get_dynamic_libraries_for_dependency(deplib) ).each do |libpath|
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

  # Give ourselves a way to trigger individual dependencies
  namespace DEPENDENCIES_SYM do
    namespace :deploy do
      # Add task to directly just build this dependency
      task(deplib_name => @ceedling[DEPENDENCIES_SYM].get_dynamic_libraries_for_dependency(deplib)) do |t,args|
        @ceedling[DEPENDENCIES_SYM].deploy_if_required(deplib_name)
      end
    end

    namespace :make do
      # Add task to directly just build this dependency
      task(deplib_name => @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib))
    end

    namespace :clean do
      # Add task to directly clobber this dependency
      task(deplib_name) do 
        @ceedling[DEPENDENCIES_SYM].clean_if_required(deplib_name)
      end
    end

    namespace :fetch do
      # Add task to directly clobber this dependency
      task(deplib_name) do 
        @ceedling[DEPENDENCIES_SYM].fetch_if_required(deplib_name)
      end
    end
  end

  # Finally, add the static libraries to our RELEASE build dependency list
  task PROJECT_RELEASE_BUILD_TARGET => @ceedling[DEPENDENCIES_SYM].get_static_libraries_for_dependency(deplib) 

  # Add the dynamic libraries to our RELEASE task dependency list so that they will be copied automatically
  task RELEASE_SYM => @ceedling[DEPENDENCIES_SYM].get_dynamic_libraries_for_dependency(deplib)
end

# Add any artifact:include folders to our release & test includes paths so linking and mocking work.
@ceedling[DEPENDENCIES_SYM].add_headers()

# Add tasks for building or cleaning ALL depencies
namespace DEPENDENCIES_SYM do
  desc "Deploy missing dependencies."
  task :deploy => DEPENDENCIES_LIBRARIES.map{|deplib| "#{DEPENDENCIES_SYM}:deploy:#{@ceedling[DEPENDENCIES_SYM].get_name(deplib)}"}

  desc "Build any missing dependencies."
  task :make => DEPENDENCIES_LIBRARIES.map{|deplib| "#{DEPENDENCIES_SYM}:make:#{@ceedling[DEPENDENCIES_SYM].get_name(deplib)}"}
  
  desc "Clean all dependencies."
  task :clean => DEPENDENCIES_LIBRARIES.map{|deplib| "#{DEPENDENCIES_SYM}:clean:#{@ceedling[DEPENDENCIES_SYM].get_name(deplib)}"}
  
  desc "Fetch all dependencies."
  task :fetch => DEPENDENCIES_LIBRARIES.map{|deplib| "#{DEPENDENCIES_SYM}:fetch:#{@ceedling[DEPENDENCIES_SYM].get_name(deplib)}"}
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
