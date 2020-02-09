

class PreprocessinatorIncludesHandler

  constructor :configurator, :tool_executor, :task_invoker, :file_path_utils, :yaml_wrapper, :file_wrapper
  @@makefile_cache = {}

  # shallow includes: only those headers a source file explicitly includes

  def invoke_shallow_includes_list(filepath)
    @task_invoker.invoke_test_shallow_include_lists( [@file_path_utils.form_preprocessed_includes_list_filepath(filepath)] )
  end

  ##
  # Ask the preprocessor for a make-style dependency rule of only the headers
  # the source file immediately includes.
  #
  # === Arguments
  # +filepath+ _String_:: Path to the test file to process.
  #
  # === Return
  # _String_:: The text of the dependency rule generated by the preprocessor.
  def form_shallow_dependencies_rule(filepath)
    if @@makefile_cache.has_key?(filepath)
      return @@makefile_cache[filepath]
    end
    # change filename (prefix of '_') to prevent preprocessor from finding
    # include files in temp directory containing file it's scanning
    temp_filepath = @file_path_utils.form_temp_path(filepath, '_')

    # read the file and replace all include statements with a decorated version
    # (decorating the names creates file names that don't exist, thus preventing
    # the preprocessor from snaking out and discovering the entire include path
    # that winds through the code). The decorated filenames indicate files that
    # are included directly by the test file.
    contents = @file_wrapper.read(filepath)

    if !contents.valid_encoding?
      contents = contents.encode("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8')
    end

    contents.gsub!( /^\s*#include\s+[\"<]\s*(\S+)\s*[\">]/, "#include \"\\1\"\n#include \"@@@@\\1\"" )
    contents.gsub!( /^\s*TEST_FILE\(\s*\"\s*(\S+)\s*\"\s*\)/, "#include \"\\1\"\n#include \"@@@@\\1\"")
    @file_wrapper.write( temp_filepath, contents )

    # extract the make-style dependency rule telling the preprocessor to
    # ignore the fact that it can't find the included files
    command = @tool_executor.build_command_line(@configurator.tools_test_includes_preprocessor, [], temp_filepath)
    shell_result = @tool_executor.exec(command[:line], command[:options])

    @@makefile_cache[filepath] = shell_result[:output]
    return shell_result[:output]
  end

  ##
  # Extract the headers that are directly included by a source file using the
  # provided, annotated Make dependency rule.
  #
  # === Arguments
  # +filepath+ _String_:: C source or header file to extract includes for.
  #
  # === Return
  # _Array_ of _String_:: Array of the direct dependencies for the source file.
  def extract_includes(filepath)
    to_process = [filepath]
    ignore_list = []
    list = []

    include_paths = @configurator.project_config_hash[:collection_paths_include]
    include_paths = [] if include_paths.nil?
    include_paths.map! {|path| File.expand_path(path)}

    while to_process.length > 0
      target = to_process.shift()
      ignore_list << target
      # puts "[HELL] Processing: \t\t#{target}"
      new_deps, new_to_process = extract_includes_helper(target, include_paths, ignore_list)
      list += new_deps
      to_process += new_to_process
      if (!@configurator.project_config_hash.has_key?(:project_auto_link_deep_dependencies) or
          !@configurator.project_config_hash[:project_auto_link_deep_dependencies])
        break
      else
        list = list.uniq()
        to_process = to_process.uniq()
      end
    end

    return list
  end

  def extract_includes_helper(filepath, include_paths, ignore_list)
    # Extract the dependencies from the make rule
    hdr_ext = @configurator.extension_header
    make_rule = self.form_shallow_dependencies_rule(filepath)
    dependencies = make_rule.split.find_all {|path| path.end_with?(hdr_ext) }.uniq
    dependencies.map! {|hdr| hdr.gsub('\\','/') }

    # Separate the real files form the annotated ones and remove the '@@@@'
    annotated_headers, real_headers = dependencies.partition {|hdr| hdr =~ /^@@@@/ }
    annotated_headers.map! {|hdr| hdr.gsub('@@@@','') }
    # Matching annotated_headers values against real_headers to ensure that
    # annotated_headers contain full path entries (as returned by make rule)
    annotated_headers.map! {|hdr| real_headers.find {|real_hdr| !real_hdr.match(/(.*\/)?#{Regexp.escape(hdr)}/).nil? } }
    annotated_headers = annotated_headers.compact

    # Find which of our annotated headers are "real" dependencies. This is
    # intended to weed out dependencies that have been removed due to build
    # options defined in the project yaml and/or in the headers themselves.
    list = annotated_headers.find_all do |annotated_header|
      # find the index of the "real" include that matches the annotated one.
      idx = real_headers.find_index do |real_header|
        real_header =~ /^(.*\/)?#{Regexp.escape(annotated_header)}$/
      end
      # If we found a real include, delete it from the array and return it,
      # otherwise return nil. Since nil is falsy this has the effect of making
      # find_all return only the annotated headers for which a real include was
      # found/deleted
      idx ? real_headers.delete_at(idx) : nil
    end.compact

    # Extract direct dependencies that were also added
    # HP_MOD: Start
    # src_ext = @configurator.extension_source
    # sdependencies = make_rule.split.find_all {|path| path.end_with?(src_ext) }.uniq
    # sdependencies.map! {|hdr| hdr.gsub('\\','/') }
    # list += sdependencies
    # HP_MOD: End

    to_process = []

    if @configurator.project_config_hash.has_key?(:project_auto_link_deep_dependencies) && @configurator.project_config_hash[:project_auto_link_deep_dependencies]
      # Creating list of mocks
      mocks = annotated_headers.find_all do |annotated_header|
        File.basename(annotated_header) =~ /^#{@configurator.project_config_hash[:cmock_mock_prefix]}.*$/
      end.compact

      # Creating list of headers that should be recursively pre-processed
      # Skipping mocks and unity.h
      headers_to_deep_link = annotated_headers.select do |annotated_header|
        !(mocks.include? annotated_header) and (annotated_header.match(/^(.*\/)?unity\.h$/).nil?)
      end
      headers_to_deep_link.map! {|hdr| File.expand_path(hdr)}

      mocks.each do |mock|
        dirname = File.dirname(mock)
        #basename = File.basename(mock).delete_prefix(@configurator.project_config_hash[:cmock_mock_prefix])
        basename = File.basename(mock).sub(@configurator.project_config_hash[:cmock_mock_prefix], '')
        if dirname != "."
          ignore_list << File.join(dirname, basename)
        else
          ignore_list << basename
        end
      end.compact

      # Filtering list of final includes to only include mocks and anything that is NOT in the ignore_list
      list = list.select do |item|
        mocks.include? item or !(ignore_list.any? { |ignore_item| !item.match(/^(.*\/)?#{Regexp.escape(ignore_item)}$/).nil? })
      end

      headers_to_deep_link.each do |hdr|
        if (ignore_list.none? {|ignore_header| hdr.match(/^(.*\/)?#{Regexp.escape(ignore_header)}$/)} and
            include_paths.none? {|include_path| hdr =~ /^#{include_path}\.*/})
          if File.exist?(hdr)
            to_process << hdr
            #source_file = hdr.delete_suffix(hdr_ext) + src_ext
            source_file = hdr.chomp(hdr_ext) + src_ext
            if source_file != hdr and File.exist?(source_file)
              to_process << source_file
            end
          end
        end
      end
    end

    return list, to_process

  end

  def write_shallow_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, list)
  end
end
