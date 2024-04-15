require 'ceedling/plugin'
require 'ceedling/constants'
require 'pathname'

DEPENDENCIES_ROOT_NAME = 'dependencies'
DEPENDENCIES_TASK_ROOT = DEPENDENCIES_ROOT_NAME + ':'
DEPENDENCIES_SYM       = DEPENDENCIES_ROOT_NAME.to_sym

class Dependencies < Plugin

  def setup
    @plugin_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    # Set up a fast way to look up dependencies by name or static lib path
    @dependencies = {}
    @dynamic_libraries = []
    DEPENDENCIES_DEPS.each do |deplib|

      @dependencies[ deplib[:name] ] = deplib.clone
      all_deps = get_static_libraries_for_dependency(deplib) +
                 get_dynamic_libraries_for_dependency(deplib) +
                 get_include_directories_for_dependency(deplib) +
                 get_source_files_for_dependency(deplib)
      all_deps.each do |key|
        @dependencies[key] = @dependencies[ deplib[:name] ]
      end

      @dynamic_libraries += get_dynamic_libraries_for_dependency(deplib)
    end
  end

  def config()
    updates = {
      :collection_paths_include => COLLECTION_PATHS_INCLUDE,
      :collection_all_headers => COLLECTION_ALL_HEADERS,
    }

    DEPENDENCIES_DEPS.each do |deplib|
      @ceedling[DEPENDENCIES_SYM].get_include_directories_for_dependency(deplib).each do |incpath|
        updates[:collection_paths_include] << incpath
      end

      @ceedling[DEPENDENCIES_SYM].get_include_files_for_dependency(deplib).each do |inc|
        updates[:collection_all_headers] << inc
      end
    end

    updates
  end

  def get_name(deplib)
    raise "Each dependency must have a name!" if deplib[:name].nil?
    return deplib[:name].gsub(/\W*/,'')
  end

  def get_fetch_path(deplib)
    if deplib.include? :paths
      return deplib[:paths][:fetch] || deplib[:paths][:source] || File.join('dependencies', get_name(deplib))
    else
      return File.join('dependencies', get_name(deplib))
    end
  end

  def get_source_path(deplib)
    if deplib.include? :paths
      return deplib[:paths][:source] || deplib[:paths][:fetch] || File.join('dependencies', get_name(deplib))
    else
      return File.join('dependencies', get_name(deplib))
    end
  end

  def get_build_path(deplib)
    if deplib.include? :paths
      return deplib[:paths][:build] || deplib[:paths][:source] || deplib[:paths][:fetch] || File.join('dependencies', get_name(deplib))
    else
      return File.join('dependencies', get_name(deplib))
    end
  end

  def get_artifact_path(deplib)
    if deplib.include? :paths
      return deplib[:paths][:artifact] || deplib[:paths][:build] || File.join('dependencies', get_name(deplib))
    else
      return File.join('dependencies', get_name(deplib))
    end
  end

  def get_working_paths(deplib, artifact_only=false)
    paths = if deplib.include?(:paths)
      if artifact_only
        [deplib[:paths][:artifact]].compact.uniq
      else
        deplib[:paths].values.compact.uniq
      end
    else
      []
    end
    paths = [ File.join('dependencies', get_name(deplib)) ] if (paths.empty?)
    return paths
  end

  def get_static_libraries_for_dependency(deplib)
    (deplib[:artifacts][:static_libraries] || []).map {|path| File.join(get_artifact_path(deplib), path)}
  end

  def get_dynamic_libraries_for_dependency(deplib)
    (deplib[:artifacts][:dynamic_libraries] || []).map {|path| File.join(get_artifact_path(deplib), path)}
  end

  def get_source_files_for_dependency(deplib)
    (deplib[:artifacts][:source] || []).map {|path| File.join(get_artifact_path(deplib), path)}
  end

  def get_include_directories_for_dependency(deplib)
    paths = (deplib[:artifacts][:includes] || []).map do |path| 
      if (path =~ /.*\.h$/)
        path.split(/[\/\\]/)[0..-2]
      elsif (path =~ /(?:^\+:)|(?:^-:)|(?:\*\*)/)
        @ceedling[:file_path_collection_utils].collect_paths([path])
      else
        path
      end
    end
    return paths.map{|path| File.join(get_artifact_path(deplib), path) }.uniq 
  end

  def get_include_files_for_dependency(deplib)
    (deplib[:artifacts][:includes] || []).map {|path| File.join(get_artifact_path(deplib), path)}
  end

  def set_env_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?
    return if (blob[:environment].nil?)
    return if (blob[:environment].empty?)

    blob[:environment].each do |e|
      m = e.match(/^(\w+)\s*(\+?\-?=)\s*(.*)$/)
      unless m.nil?
        case m[2]
        when "+="
          ENV[m[1]] = (ENV[m[1]] || "") + m[3]
        when "-="
          ENV[m[1]] = (ENV[m[1]] || "").gsub(m[3],'')
        else
          ENV[m[1]] = m[3]
        end
      end
    end
  end

  def wrap_command(cmd)
    if (cmd.class == String)
      cmd = { 
        :name => cmd.split(/\s+/)[0],
        :executable => cmd.split(/\s+/)[0],
        :line => cmd, 
        :options => { :boom => true } 
      } 
    end
    return cmd
  end

  def fetch_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?
    if (blob[:fetch].nil?) || (blob[:fetch][:method].nil?)
      @ceedling[:streaminator].stream_puts("No method to fetch #{blob[:name]}", Verbosity::COMPLAIN)
      return
    end
    unless (directory(get_source_path(blob))) #&& !Dir.empty?(get_source_path(blob)))
      @ceedling[:streaminator].stream_puts("Path #{get_source_path(blob)} is required", Verbosity::COMPLAIN)
      return
    end

    FileUtils.mkdir_p(get_fetch_path(blob)) unless File.exist?(get_fetch_path(blob))

    steps = case blob[:fetch][:method]
            when :none
              []
            when :zip
              [ "unzip -o #{blob[:fetch][:source]}" ]
            when :tar_gzip
              [ "tar -xvzf #{blob[:fetch][:source]} -C ./" ]
            when :git
              branch = blob[:fetch][:tag] || blob[:fetch][:branch] || ''
              branch = ("-b " + branch) unless branch.empty?
              unless blob[:fetch][:hash].nil?
                # Do a deep clone to ensure the commit we want is available
                retval = [ "git clone #{branch} #{blob[:fetch][:source]} ." ]
                # Checkout the specified commit
                retval << "git checkout #{blob[:fetch][:hash]}"
              else
                # Do a thin clone
                retval = [ "git clone #{branch} --depth 1 #{blob[:fetch][:source]} ." ]
              end
            when :svn
              revision = blob[:fetch][:revision] || ''
              revision = ("--revision " + branch) unless branch.empty?
              retval = [ "svn checkout #{revision} #{blob[:fetch][:source]} ." ]
              retval
            when :custom
              blob[:fetch][:executable]
            else
              raise "Unknown fetch method '#{blob[:fetch][:method]}' for dependency '#{blob[:name]}'"
            end

    # Perform the actual fetching
    @ceedling[:streaminator].stream_puts("Fetching dependency #{blob[:name]}...", Verbosity::NORMAL)
    Dir.chdir(get_fetch_path(blob)) do
      steps.each do |step|
        @ceedling[:tool_executor].exec( wrap_command(step) )
      end
    end
  end

  def build_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?

    # We don't clean anything unless we know how to fetch a new copy
    if (blob[:build].nil? || blob[:build].empty?)
      @ceedling[:streaminator].stream_puts("Nothing to build for dependency #{blob[:name]}", Verbosity::NORMAL)
      return
    end

    FileUtils.mkdir_p(get_source_path(blob)) unless File.exist?(get_source_path(blob))
    FileUtils.mkdir_p(get_artifact_path(blob)) unless File.exist?(get_artifact_path(blob))

    # Perform the build
    @ceedling[:streaminator].stream_puts("Building dependency #{blob[:name]}...", Verbosity::NORMAL)
    Dir.chdir(get_source_path(blob)) do
      blob[:build].each do |step|
        if (step.class == Symbol)
          exec_dependency_builtin_command(step, blob)
        else
          @ceedling[:tool_executor].exec( wrap_command(step) )
        end
      end
    end
  end

  def clean_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?

    # We don't clean anything unless we know how to fetch a new copy
    if (blob[:fetch].nil? || blob[:fetch][:method].nil?)
      @ceedling[:streaminator].stream_puts("Nothing to clean for dependency #{blob[:name]}", Verbosity::NORMAL)
      return
    end

    # We only need to clean the artifacts if the source isn't being fetched
    artifacts_only = (blob[:fetch][:method] == :none)

    # Perform the actual Cleaning
    @ceedling[:streaminator].stream_puts("Cleaning dependency #{blob[:name]}...", Verbosity::NORMAL)
    get_working_paths(blob, artifacts_only).each do |path|
      FileUtils.rm_rf(path) if File.directory?(path)
    end
  end

  def deploy_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?

    # We don't need to deploy anything if there isn't anything to deploy
    if (blob[:artifacts].nil? || blob[:artifacts][:dynamic_libraries].nil? || blob[:artifacts][:dynamic_libraries].empty?)
      @ceedling[:streaminator].stream_puts("Nothing to deploy for dependency #{blob[:name]}", Verbosity::NORMAL)
      return
    end

    # Perform the actual Deploying
    @ceedling[:streaminator].stream_puts("Deploying dependency #{blob[:name]}...", Verbosity::NORMAL)
    FileUtils.cp( lib_path, File.dirname(PROJECT_RELEASE_BUILD_TARGET) )
  end

  def add_headers_and_sources()
    # Search for header file paths and files to add to our collections
    cfg = @ceedling[:configurator].project_config_hash

    DEPENDENCIES_DEPS.each do |deplib|
      get_include_directories_for_dependency(deplib).each do |header|
        cfg[:collection_paths_include] << header
        cfg[:collection_paths_source_and_include] << header
        cfg[:collection_paths_test_support_source_include] << header
        cfg[:collection_paths_test_support_source_include_vendor] << header
        cfg[:collection_paths_release_toolchain_include] << header
      end

      get_include_files_for_dependency(deplib).each do |header|
        cfg[:collection_all_headers] << header

        cfg[:files] ||= {}
        cfg[:files][:include] ||= []
        cfg[:files][:include] << header
      end

      get_source_files_for_dependency(deplib).each do |source|
        cfg[:collection_paths_source_and_include] << source
        cfg[:collection_paths_test_support_source_include] << source
        cfg[:collection_paths_test_support_source_include_vendor] << source
        cfg[:collection_paths_release_toolchain_include] << source
        Dir[ File.join(source, "*#{EXTENSION_SOURCE}") ].each do |f|
          cfg[:collection_all_source] << f
        end
      end
    end
  end

  def exec_dependency_builtin_command(step, blob)
    case step
    when :build_lib # We are going to use our defined deps tools to build this library
      build_lib(blob)
    else 
      raise "No such build action as #{step.inspect} for dependency #{blob[:name]}" 
    end
  end

  def build_lib(blob)
    src = []
    asm = []
    hdr = []
    obj = []

    name = blob[:name] || ""
    source_path = Pathname.new get_source_path(blob)
    build_path = Pathname.new get_build_path(blob)
    relative_build_path = build_path.relative_path_from(source_path)

    # Verify there is an artifact that we're building that makes sense
    libs = []
    raise "No library artifacts specified for dependency #{name}" unless blob.include?(:artifacts)
    libs += blob[:artifacts][:static_libraries] if blob[:artifacts].include?(:static_libraries)
    libs += blob[:artifacts][:static_libraries] if blob[:artifacts].include?(:static_libraries)
    libs = libs.flatten.uniq
    raise "No library artifacts specified for dependency #{name}" if libs.empty?
    lib = libs[0]

    # Find all the source, header, and assembly files 
    src = Dir["./**/*#{EXTENSION_SOURCE}"]
    hdr = Dir["./**/*#{EXTENSION_HEADER}"].map{|f| File.dirname(f) }.uniq
    if (EXTENSION_ASSEMBLY && !EXTENSION_ASSEMBLY.empty?)  
      asm = Dir["./**/*#{EXTENSION_ASSEMBLY}"]
    end

    # Do we have what we need to do this?
    raise "Nothing to build" if (asm.empty? and src.empty?)
    raise "No assembler specified for building dependency #{name}" unless (defined?(TOOLS_DEPS_ASSEMBLER) || asm.empty?)
    raise "No compiler specified for building dependency #{name}" unless (defined?(TOOLS_DEPS_COMPILER) || src.empty?)
    raise "No linker specified for building dependency #{name}" unless defined?(TOOLS_DEPS_LINKER)

    # Build all the source files
    src.each do |src_file|
      object_file = relative_build_path + File.basename(src_file).ext(EXTENSION_OBJECT)
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_PATHS_DEPS, find_my_paths(src_file, blob))
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_DEFINES_DEPS, find_my_defines(src_file, blob))
      @ceedling[:generator].generate_object_file_c(
        tool:         TOOLS_DEPS_COMPILER,
        module_name:  File.basename(src_file).ext(),
        context:      DEPENDENCIES_SYM,
        source:       src_file,
        object:       object_file,
        search_paths: hdr,
        flags:        (blob[:flags] || []),
        defines:      (blob[:defines] || []),
        list:         @ceedling[:file_path_utils].form_release_build_list_filepath( File.basename(src_file,EXTENSION_OBJECT) )
      )
      obj << object_file
    end 

    # Build all the assembly files
    asm.each do |src_file|
      object_file = relative_build_path + File.basename(src_file).ext(EXTENSION_OBJECT)
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_PATHS_DEPS, find_my_paths(src_file, blob))
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_DEFINES_DEPS, find_my_defines(src_file, blob))
      @ceedling[:generator].generate_object_file_asm(
        tool:        TOOLS_DEPS_ASSEMBLER,
        module_name: File.basename(src_file).ext(),
        context:     DEPENDENCIES_SYM,
        source:      src_file,
        object:      object_file
      )
      obj << object_file
    end

    # Link the library
    @ceedling[:generator].generate_executable_file(
      TOOLS_DEPS_LINKER,
      DEPENDENCIES_SYM,
      obj,
      [],
      relative_build_path+lib,
      @ceedling[:file_path_utils].form_test_build_map_filepath(get_artifact_path(blob),lib),
      (blob[:libraries] || []),
      (blob[:libpaths] || [])
    )

    # Move the library to the specifed artifact folder
    unless get_build_path(blob) == get_artifact_path(blob)
      src = File.expand_path(lib)
      dst = File.expand_path(get_artifact_path(blob), Array.new(get_build_path(blob).split(/[\\\/]+/).length,"../").join()) + "/" + lib
      FileUtils.cp_r(src, dst)
    end
  end

  def find_my_paths( c_file, blob, file_type = :c )  
    return ((blob[:source] || []) + (blob[:include] || [])).compact.uniq
  end  

  def find_my_defines( c_file, blob, file_type = :c )  
    return (blob[:defines] || []).compact.uniq 
  end  

  def replace_constant(constant, new_value)  
    Object.send(:remove_const, constant.to_sym) if (Object.const_defined? constant)  
    Object.const_set(constant, new_value)  
  end
end


# end blocks always executed following rake run
END {
}
