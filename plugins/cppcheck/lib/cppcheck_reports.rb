# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

require 'cppcheck_constants'

class CppcheckReport
  attr_reader :artifact_filepath
  
  def initialize(system_objects, config)
    @ceedling = system_objects
    
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator = @ceedling[:loginator]
    @tool_executor = @ceedling[:tool_executor]
    @tool_validator = @ceedling[:tool_validator]
    
    @config = config
  end
  
  def report_type
    raise NotImplementedError, "#{self.class} must implement report_type"
  end
  
  def generate(opts, *args)
    opts = opts.dup()
    opts += build_opts()
    
    @loginator.log("Creating Cppcheck #{report_type} report...", Verbosity::NORMAL)
    run_tool(TOOLS_CPPCHECK, opts, *args)
  end
  
  private
  
  def form_artifact_filepath(filename, extension)
    return File.join(
      CPPCHECK_ARTIFACTS_PATH,
      File.basename(filename).ext(extension)
    )
  end
  
  def run_tool(tool, opts, *args)
    command = @tool_executor.build_command_line(tool, opts, *args)
    @loginator.log("Command: #{command}", Verbosity::DEBUG)
    results = @tool_executor.exec(command)
    return results
  end
  
  def build_opts
    ["--output-file=#{@artifact_filepath}"]
  end
end

class CppcheckHtmlReport < CppcheckReport
  def initialize(system_objects, config, xml_artifact_filepath)
    super(system_objects, config)

    @tool_validator.validate(
      tool: TOOLS_CPPCHECK_HTMLREPORT,
      boom: true
    )

    @artifact_filepath = CPPCHECK_ARTIFACTS_HTML_PATH
    @xml_artifact_filepath = xml_artifact_filepath
  end
  
  def report_type = :html
  
  def generate(opts, *args)
    @loginator.log("Creating Cppcheck #{report_type} report...", Verbosity::NORMAL)
    run_tool(TOOLS_CPPCHECK_HTMLREPORT, build_opts())
  end
  
  private
  
  def build_opts
    opts = []
    
    opts << "--file=#{@xml_artifact_filepath}"
    opts << "--report-dir=#{@artifact_filepath}"
    opts << "--source-dir=."
    
    unless @config[:html_title].nil? || @config[:html_title].empty?
      opts << "--title=#{@config[:html_title]}"
    end
    
    return opts
  end
end

class CppcheckSarifReport < CppcheckReport
  def initialize(system_objects, config)
    super(system_objects, config)

    @artifact_filepath = form_artifact_filepath(
      @config[:sarif_artifact_filename] || CPPCHECK_ARTIFACTS_FILE_SARIF,
      '.sarif'
    )
  end

  def report_type = :sarif

  private

  def build_opts
    super + ["--output-format=sarif"]
  end
end

class CppcheckTextReport < CppcheckReport
  def initialize(system_objects, config)
    super(system_objects, config)

    @artifact_filepath = form_artifact_filepath(
      @config[:text_artifact_filename] || CPPCHECK_ARTIFACTS_FILE_TEXT,
      '.txt'
    )
  end

  def report_type = :text
end

class CppcheckXmlReport < CppcheckReport
  def initialize(system_objects, config)
    super(system_objects, config)

    @artifact_filepath = form_artifact_filepath(
      @config[:xml_artifact_filename] || CPPCHECK_ARTIFACTS_FILE_XML,
      '.xml'
    )

    @xml_version = @config[:xml_report_version] || 3
    validate_version(@xml_version)
  end

  def report_type = :xml

  private

  def build_opts
    super + ["--xml", "--xml-version=#{@xml_version}"]
  end

  def validate_version(version)
    unless version == 2 or version == 3
      @loginator.log(
        "XML report version '#{version}' is not supported.",
        Verbosity::ERRORS
      )
      raise CeedlingException.new("Invalid XML report version has been requested.")
    end
  end
end
