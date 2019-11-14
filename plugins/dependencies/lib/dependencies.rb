require 'ceedling/plugin'
require 'ceedling/constants'

DEPENDENCIES_ROOT_NAME         = 'dependencies'
DEPENDENCIES_TASK_ROOT         = DEPENDENCIES_ROOT_NAME + ':'
DEPENDENCIES_SYM               = DEPENDENCIES_ROOT_NAME.to_sym

class Dependencies < Plugin

  def setup
    @plugin_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    # Set up a fast way to look up dependencies by name or static lib path
    @dependencies = {}
    @dynamic_libraries = []
    DEPENDENCIES_LIBRARIES.each do |deplib|
      @dependencies[ deplib[:name] ] = deplib.clone
      get_static_libraries_for_dependency(deplib).each do |key|
        @dependencies[key] = @dependencies[ deplib[:name] ]
      end
      @dynamic_libraries += get_dynamic_libraries_for_dependency(deplib)
    end
  end

  def config
    updates = {
      :collection_paths_include => COLLECTION_PATHS_INCLUDE,
      :collection_all_headers => COLLECTION_ALL_HEADERS,
    }

    @ceedling[DEPENDENCIES_SYM].get_include_directories_for_dependency(deplib).each do |incpath|
      updates[:collection_paths_include] << incpath
      Dir[ File.join(incpath, "*#{EXTENSION_HEADER}") ].each do |f|
        updates[:collection_all_headers] << f
      end
    end

    return updates
  end

  def get_name(deplib)
    raise "Each dependency must have a name!" if deplib[:name].nil? 
    return deplib[:name].gsub(/\W*/,'')
  end

  def get_working_path(deplib)
    return deplib[:working_path] || File.join('dependencies', get_name(deplib))
  end

  def get_static_libraries_for_dependency(deplib)
    (deplib[:artifacts][:static_libraries] || []).map {|path| File.join(get_working_path(deplib), path)}
  end

  def get_dynamic_libraries_for_dependency(deplib)
    (deplib[:artifacts][:dynamic_libraries] || []).map {|path| File.join(get_working_path(deplib), path)}
  end

  def get_include_directories_for_dependency(deplib)
    (deplib[:artifacts][:includes] || []).map {|path| File.join(get_working_path(deplib), path)}
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

  def fetch_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?
    return if (blob[:fetch].nil?)
    return if (blob[:fetch][:method].nil?)

    case blob[:fetch][:method]
    when :none
      return
    when :zip
      @ceedling[:streaminator].stdout_puts("Fetching dependency #{blob[:name]}...", Verbosity::NORMAL)
      raise "TODO: Zip support not yet implemented in dependency plugin"
    when :git 
      @ceedling[:streaminator].stdout_puts("Fetching dependency #{blob[:name]}...", Verbosity::NORMAL)
      raise "TODO: Git support not yet implemented in dependency plugin"
    else
      raise "Unknown fetch method '#{blob[:fetch][:method].to_s}' for dependency '#{blob[:name]}'"
    end
  end

  def build_if_required(lib_path)
    blob = @dependencies[lib_path]
    raise "Could not find dependency '#{lib_path}'" if blob.nil?
    raise "Could not find build steps for dependency '#{blob[:name]}'" if (blob[:build].nil? || blob[:build].empty?)

    @ceedling[:streaminator].stdout_puts("Building dependency #{blob[:name]}...", Verbosity::NORMAL)
    blob[:build].each do |step|
      @ceedling[:tool_executor].exec( step )
    end
  end

  def add_headers()
    # Search for header file paths and files to add to our collections
    DEPENDENCIES_LIBRARIES.each do |deplib|
      get_include_directories_for_dependency(deplib).each do |header|
        cfg = @ceedling[:configurator].project_config_hash
        cfg[:collection_paths_include] << header
        cfg[:collection_paths_source_and_include] << header
        cfg[:collection_paths_test_support_source_include] << header
        cfg[:collection_paths_test_support_source_include_vendor] << header
        Dir[ File.join(header, "*#{EXTENSION_HEADER}") ].each do |f|
          cfg[:collection_all_headers] << f
        end
      end
    end

    # Make all these updated files findable by Ceedling
    @ceedling[:file_finder].prepare_search_sources()
  end
end

# end blocks always executed following rake run
END {
}
