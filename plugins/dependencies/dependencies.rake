# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

@ceedling[DEPENDENCIES_SYM].specs.each do |dep|

  # Make sure the required working directories exists
  # (don't worry about the subdirectories. That's the job of the dep's build tool)
  paths = dep.working_paths
  paths.each {|path| directory(path) }
  task :directories => paths

  collector = @ceedling[DEPENDENCIES_SYM].path_collector
  headers_and_sources = dep.include_directories( collector ) + dep.include_files + dep.source_paths
  all_deps = dep.static_libraries + dep.dynamic_libraries + headers_and_sources

  # Add a rule for building the actual libraries from dependency list
  (dep.static_libraries + dep.dynamic_libraries).each do |libpath|
    file libpath do |filetask|
      path = filetask.name

      # We double-check that it doesn't already exist, because this process sometimes
      # produces multiple files, but they may have already been flagged as invoked
      if (File.exist?(path))
        @ceedling[:loginator].lazy( Verbosity::OBNOXIOUS ) { "Nothing to do for dependency #{path}" }
      else
        @ceedling[DEPENDENCIES_SYM].make_if_required(path)
      end
    end
  end

  # Add a rule for building the source and includes from dependency list
  headers_and_sources.each do |libpath|
    task libpath do |filetask|
      path = File.expand_path(filetask.name)

      if (File.file?(path) || File.directory?(path))
        @ceedling[:loginator].lazy( Verbosity::OBNOXIOUS ) { "Nothing to do for dependency #{path}" }
      else
        @ceedling[DEPENDENCIES_SYM].make_if_required(path)
      end
    end
  end

  # Give ourselves a way to trigger individual dependencies
  namespace DEPENDENCIES_SYM do
    namespace :deploy do
      # Add task to directly just build this dependency
      task(dep.task_name => dep.dynamic_libraries) do |_t,_args|
        @ceedling[DEPENDENCIES_SYM].deploy_if_required(dep.task_name)
      end
    end

    namespace :make do
      # Add task to directly just build this dependency
      task(dep.task_name => all_deps)
    end

    namespace :clean do
      # Add task to directly clobber this dependency
      task(dep.task_name) do
        @ceedling[DEPENDENCIES_SYM].clean_if_required(dep.task_name)
      end
    end

    namespace :fetch do
      # Add task to directly clobber this dependency
      task(dep.task_name => dep.source_path) do
        @ceedling[DEPENDENCIES_SYM].fetch_if_required(dep.task_name)
      end
    end
  end


  # Add source files to our list of things to build during release
  task PROJECT_RELEASE_BUILD_TARGET => dep.source_paths

  # Finally, add the static libraries to our RELEASE build dependency list
  task RELEASE_SYM => dep.static_libraries

  # Add the dynamic libraries to our RELEASE task dependency list so that they will be copied automatically
  task RELEASE_SYM => dep.dynamic_libraries

  # Paths to Libraries need to be Added to the Lib Path List
  all_libs = dep.static_libraries + dep.dynamic_libraries
  PATHS_LIBRARIES ||= []
  all_libs.each {|lib| PATHS_LIBRARIES << File.dirname(lib) }
  PATHS_LIBRARIES.uniq!
  PATHS_LIBRARIES.reject!{|s| s.empty?}

  # Libraries Need to be Added to the Library List
  LIBRARIES_SYSTEM ||= []
  all_libs.each {|lib| LIBRARIES_SYSTEM << File.basename(lib,'.*').sub(/^lib/,'') }
  LIBRARIES_SYSTEM.uniq!
  LIBRARIES_SYSTEM.reject!{|s| s.empty?}

  task :prepare => all_deps
end

# Add any artifact:include or :source folders to our release & test includes paths so linking and mocking work.
@ceedling[DEPENDENCIES_SYM].add_headers_and_sources()

# Add tasks for building or cleaning ALL depencies
namespace DEPENDENCIES_SYM do
  task_names = @ceedling[DEPENDENCIES_SYM].specs.map( &:task_name )

  desc "Deploy missing dependencies."
  task :deploy => task_names.map { |name| "#{DEPENDENCIES_SYM}:deploy:#{name}" }

  desc "Build any missing dependencies."
  task :make => task_names.map { |name| "#{DEPENDENCIES_SYM}:make:#{name}" }

  desc "Clean all dependencies."
  task :clean => task_names.map { |name| "#{DEPENDENCIES_SYM}:clean:#{name}" }

  desc "Fetch all dependencies."
  task :fetch => task_names.map { |name| "#{DEPENDENCIES_SYM}:fetch:#{name}" }
end

namespace :files do
  desc "List all collected dependency libraries."
  task :dependencies do
    puts "dependency files:"
    deps = @ceedling[DEPENDENCIES_SYM].specs.flat_map { |dep| dep.static_libraries + dep.dynamic_libraries }
    deps.sort.each {|dep| puts " - #{dep}"}
    puts "file count: #{deps.size}"
  end
end
