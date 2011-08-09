require 'plugin'
require 'constants'
require 'erb'
require 'fileutils'

class ModuleGenerator < Plugin

  attr_reader :config

  def setup
  
    #---- New module templates
    
    @test_template = (<<-EOS).left_margin
      #include "unity.h"
      <%if defined?(MODULE_GENERATOR_TEST_INCLUDES) && (MODULE_GENERATOR_TEST_INCLUDES.class == Array) && !MODULE_GENERATOR_TEST_INCLUDES.empty?%>
      <%MODULE_GENERATOR_TEST_INCLUDES.each do |header_file|%>
      #include "<%=header_file%>"
      <%end%>
      <%end%>
      #include "<%=@context[:headername]%>"
      
      void setUp(void)
      {
      }
      
      void tearDown(void)
      {
      }
      
      void test_<%=name%>_needs_to_be_implemented(void)
      {
      <%="\t"%>TEST_IGNORE_MESSAGE("Implement me!");
      }
      EOS

    @source_template = (<<-EOS).left_margin
      <%if defined?(MODULE_GENERATOR_SOURCE_INCLUDES) && (MODULE_GENERATOR_SOURCE_INCLUDES.class == Array) && !MODULE_GENERATOR_SOURCE_INCLUDES.empty?%>
      <%MODULE_GENERATOR_SOURCE_INCLUDES.each do |header_file|%>
      #include "<%=header_file%>"
      <%end%>
      <%end%>
      #include "<%=@context[:headername]%>"
      EOS

    @header_template = (<<-EOS).left_margin
      #ifndef <%=@context[:name]%>_H
      #define <%=@context[:name]%>_H
      
      <%if defined?(MODULE_GENERATOR_HEADER_INCLUDES) && (MODULE_GENERATOR_HEADER_INCLUDES.class == Array) && !MODULE_GENERATOR_HEADER_INCLUDES.empty?%>
      <%MODULE_GENERATOR_HEADER_INCLUDES.each do |header_file|%>
      #include "<%=header_file%>"
      <%end%>
      <%end%>
      
      #endif // <%=@context[:name]%>_H
      EOS
      
      
    #---- New function templates
      
    @func_test_template = (<<-EOS).left_margin
      
      /* ------ <%=@declaration[:name]%> ------ */
      
      void test_<%=@declaration[:name]%>_needs_to_be_implemented(void)
      {
          TEST_IGNORE();
      }
      
      EOS
      
    
    @func_decl_template = (<<-EOS).left_margin
    
      <%=@declaration[:returns]%> <%=@declaration[:name]%>(<%=@declaration[:arguments]%>);
      
      EOS
    
    @func_impl_template = (<<-EOS).left_margin
    
      <%=@declaration[:returns]%> <%=@declaration[:name]%>(<%=@declaration[:arguments]%>)
      {
          return;
      }
      
      EOS
  end

  def create(path, optz={})
  
    extract_context(path, optz)

    if !optz.nil? && (optz[:destroy] == true)
      @ceedling[:streaminator].stdout_puts "Destroying '#{path}'..."
      @files.each do |file|
        if File.exist?(file[:path])
          @ceedling[:tool_executor].exec("svn delete \"#{file[:path]}\" --force")
          @ceedling[:streaminator].stdout_puts "File #{file[:path]} deleted and removed from source control"
        else
          @ceedling[:streaminator].stdout_puts "File #{file[:path]} does not exist!"
        end
      end
      exit
    end

    @ceedling[:streaminator].stdout_puts "Generating '#{path}'..."

    [File.dirname(@files[0][:path]), File.dirname(@files[1][:path])].each do |dir|
      makedirs(dir, {:verbose => true})
      @ceedling[:tool_executor].exec("svn add \"#{dir}\"")
    end

    # define_name = headername.gsub(/\.h$/, '_H').upcase

    @files[0][:template] = @test_template
    @files[1][:template] = @source_template
    @files[2][:template] = @header_template

    @files.each do |file|
      if File.exist?(file[:path])
        @ceedling[:streaminator].stdout_puts "File #{file[:path]} already exists!"
      else
        File.open(file[:path], 'w') do |new_file|
          new_file << ERB.new(file[:template], 0, "<>").result(binding)
        end
        @ceedling[:tool_executor].exec("svn add \"#{file[:path]}\"")
        if $?.exitstatus == 0
          @ceedling[:streaminator].stdout_puts "File #{file[:path]} created and added to source control"
        else
          @ceedling[:streaminator].stdout_puts "File #{file[:path]} created but FAILED adding to source control!"
        end
      end
    end

  end
  
  def add_function(path, optz={})
    extract_context(path, optz)
    
    parse_function_declaration(optz[:declaration])
    
    @files[0][:template] = @func_test_template
    @files[1][:template] = @func_impl_template
    @files[2][:template] = @func_decl_template

    @files.each do |file|
      if File.exist?(file[:path])
        puts "Appending content to " + file[:path] + "..."
        File.open(file[:path], 'a+') do |cur_file|
          cur_file << ERB.new(file[:template], 0, "<>").result(binding)
        end
      else
        raise "Error: #{file[:path]} could not be opened!"
      end
    end
    
    @ceedling[:streaminator].stdout_puts "Done generating new function goods!"
  end
  
  private
  
  def parse_function_declaration(declaration)
    p declaration
    tokens = declaration.match(/^\\?\"?\s*([\w\s]+)\s+(\w+)\s*\((.*)\)\s*\"?$/)
    p tokens
    @declaration = {
      :returns => tokens[1],
      :name => tokens[2],
      :arguments => tokens[3]
    }
    p "-"*10
    p @declaration
    p "-"*10
  end
  
  def extract_context(path, optz={})
    if (!defined?(MODULE_GENERATOR_PROJECT_ROOT) ||
        !defined?(MODULE_GENERATOR_SOURCE_ROOT) ||
        !defined?(MODULE_GENERATOR_TEST_ROOT))
      raise "You must have ':module_generator:project_root:', ':module_generator:source_root:' and ':module_generator:test_root:' defined in your Ceedling configuration file"
    end
    
    @context = {}

    @context[:paths] = {
      :base => @ceedling[:file_wrapper].get_expanded_path(MODULE_GENERATOR_PROJECT_ROOT).gsub('\\', '/').sub(/^\//, '').sub(/\/$/, ''),
      :src => MODULE_GENERATOR_SOURCE_ROOT.gsub('\\', '/').sub(/^\//, '').sub(/\/$/, ''),
      :test => MODULE_GENERATOR_TEST_ROOT.gsub('\\', '/').sub(/^\//, '').sub(/\/$/, '')
    }

    location = File.dirname(path.gsub('\\', '/'))
    location.sub!(/^\/?#{@context[:paths][:base]}\/?/i, '')
    location.sub!(/^\/?#{@context[:paths][:src]}\/?/i, '')
    location.sub!(/^\/?#{@context[:paths][:test]}\/?/i, '')
    
    @context[:location] = location

    @context[:name] = File.basename(path).sub(/\.[ch]$/, '')
    
    # p @context[:name]
    
    @context[:testname] = "test_#{@context[:name]}.c"
    @context[:sourcename] = "#{@context[:name]}.c"
    @context[:headername] = "#{@context[:name]}.h"
    
    # p @context

    @files = [
      {:path => File.join(PROJECT_ROOT, @context[:paths][:test], location, @context[:testname])},
      {:path => File.join(PROJECT_ROOT, @context[:paths][:src],  location, @context[:sourcename])},
      {:path => File.join(PROJECT_ROOT, @context[:paths][:src],  location, @context[:headername])}
    ]
    
    # p @files
  end
  
end