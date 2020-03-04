# © Copyright 2019-2020 HP Development Company, L.P.
# SPDX-License-Identifier: MIT

require 'yaml'
require_relative 'section_parser'
require 'csv'


def MergeArrays(a1, a2)
   if a1 && a2
      a1 |= a2
   elsif not a1 && a2
      a1 = a2
   end
   return a1
end


UNIT_TESTS_DIR_NAME = "UnitTests"  # HPTODO: Env variable?
TEST_FILE_PREFIX = "test_"  # HPTODO: Get prefix from config

MAX_MACRO_DEPTH = 3

DEFAULT_FILTERS = FILTERS.values_at(:comment, :preprocessor, :bracket)

def CreateMacroDictionary(dsc_filepath, filters=nil)
   if File.exists?(dsc_filepath)
      data = File.read(dsc_filepath)
   else
      raise "ERROR: The DSC file \"#{dsc_filepath}\" does not exist."
   end

   if not filters.nil?
      filters.each do |filter|
         data = data.gsub(filter, "")
      end
   end

   macro_dict = Hash.new

   data.lines().each do |line|
      line = line.strip()
      unless line.empty?
         match = /DEFINE\s+(\w+)\s*=\s*(.+)/.match(line)
         if match
            name = "$(" + match[1].strip() + ")"
            value = match[2].strip()
            macro_dict[name] = value
         end
      end
   end

   for key1 in macro_dict.keys
      if macro_dict[key1].include? "$"
         $i = 0
         while $i < MAX_MACRO_DEPTH
            for key2 in macro_dict.keys
               if macro_dict[key1].include? key2
                  macro_dict[key1] = macro_dict[key1].gsub(key2, macro_dict[key2])
               end
            end
            $i += 1
         end
      end
   end

   return macro_dict
end

def ReplaceMacros(str, macro_dict)
   new_str = str

   if macro_dict
      for key in macro_dict.keys
         if str.include? key
            new_str = str.gsub(key, macro_dict[key])
         end
      end
   end

   return new_str
end


def GetDecPaths(inf_path, workspace, edk_tools_path, macro_dict)
   rel_dec_paths = GetSectionContents(inf_path, /\[Packages.*\]/, filters=DEFAULT_FILTERS).uniq
   puts rel_dec_paths
   puts "..."
   dec_paths = []
   rel_dec_paths.each do |rel_dec_path|
      rel_dec_path = ReplaceMacros(rel_dec_path, macro_dict)
      full_dec_path = File.expand_path(rel_dec_path, dir_string=workspace)
      puts full_dec_path
      puts "..."
      if File.exists?(full_dec_path)
         dec_paths << full_dec_path
      else
         full_dec_path = File.expand_path(rel_dec_path, dir_string=edk_tools_path)
         dec_paths << full_dec_path
      end
   end

   return dec_paths.uniq
end


def GetIncludePaths(dec_paths, inf_path, edk_tools_path)
   include_paths = []
   dec_paths.each do |dec_path|
      rel_include_paths = GetSectionContents(dec_path, /\[Includes.*\]/, filters=DEFAULT_FILTERS)
      rel_include_paths.each do |rel_include_path|
         include_paths << File.expand_path(rel_include_path, dir_string=File.dirname(dec_path))
      end

      include_paths << File.dirname(dec_path)
   end

   include_paths << File.expand_path(File.dirname(inf_path))
   include_paths << File.expand_path(File.join(edk_tools_path, "MdeModulePkg"))
   include_paths << File.expand_path(File.join(edk_tools_path, "MdeModulePkg", "Application"))
   # include_paths << File.expand_path("vendor/ceedling/vendor/unity/src")


   return include_paths.uniq
end

def GetRelativeIncludePaths(test_paths)
   relative_include_paths = []
   print("GetRelativeIncludePaths\n")

   test_paths.each do |test_path|
      if File.exists?(test_path)
         data = File.read(test_path)
      else
         raise "ERROR: \"#{test_path}\" does not exist."
      end

      includes = data.scan(/^\s*#include\s+\"\s*(.+)\.[hH]\s*\"/).flatten
      print("includes: \n")
      print(includes)

      includes.each do |include|
         if File.dirname(include) != "."
            relative_include_paths << File.dirname(include)
         end
      end
   end

   # RSC Start
   #    Hack to support common mocks without relative paths. If they have a relative path, cmock/ceedling currently doesn't replicate it when creating the mock files.
   relative_include_paths << "Library"
   relative_include_paths << "Protocol"
   # RSC End


   print("\nrelative_include_paths: \n")
   print(relative_include_paths)
   return relative_include_paths.uniq
end


def GetSourcePaths(inf_path)
   source_paths = []
   rel_source_paths = GetSectionContents(inf_path, /\[Sources.*\]/, filters=DEFAULT_FILTERS)
   rel_source_paths.each do |rel_source_path|
      if rel_source_path.end_with?(".c") or rel_source_path.end_with?(".h")
         source_paths << File.expand_path(rel_source_path, dir_string=File.dirname(inf_path))
      end
   end

   return source_paths.uniq
end

def ValidateSourceInIncludePaths(include_paths, source_paths)
   temp = include_paths  
   source_paths.each do |src|
      folder_path = File.dirname(src)
      if not include_paths.include? folder_path
         temp << folder_path 
      end
   end

   return temp
end

def GetTestPaths(source_paths, inf_path)
   test_paths = []
   test_dir = File.join(File.dirname(inf_path), UNIT_TESTS_DIR_NAME)

   source_paths.each do |source_path|
      filename = File.basename(source_path)

      test_path = File.join(test_dir, TEST_FILE_PREFIX + filename)
      if File.exists?(test_path)
         test_paths << File.expand_path(test_path)
      end
   end

   return test_paths.uniq
end

def GetSupportPaths()
   support_paths = []
   # support_paths << File.expand_path("support")
   # support_paths << GetEdk2SupportPath()

   return support_paths.uniq
end


def GetSources(inf_path)
   sources = []
   c_sources = []

   sources = GetSectionContents(inf_path, /\[Sources.*\]/, filters=DEFAULT_FILTERS)

   sources.each do |source|
      if source.end_with?(".c")
         c_sources << source
      end
   end

   return c_sources.uniq
end


def GetIncludes(inf_path)
   library_classes = []
   includes = []
   library_classes = GetSectionContents(inf_path, /\[LibraryClasses.*\]/, filters=DEFAULT_FILTERS)


   keys = ['library', 'headers']
   # library_mapping = CSV.read("LibraryIncludes.csv", { :col_sep => '|' }).map {|a| Hash[ keys.zip(a) ] }

   library_mapping = CSV.read("LibraryIncludes.CSV", col_sep: "|").drop(1).to_h

   library_classes.each do |library|
      libmap = library_mapping.assoc(library)
      if not libmap.nil?
         includes.concat libmap[1].split(',')
      end
   end

   return includes.uniq
end


def UpdateModulePathsFromInf(workspace, artifacts, cache, edk_tools_path, dsc_path, inf_path, proj_support_path)
   puts "..."
   puts workspace
   puts "..."
   puts edk_tools_path
   puts "..."
   puts dsc_path
   puts "..."
   puts inf_path
   puts "..."
   puts proj_support_path
   puts "..."
   macro_dict              = CreateMacroDictionary(dsc_path, filters=DEFAULT_FILTERS)
   dec_paths               = GetDecPaths(inf_path, workspace, edk_tools_path, macro_dict)
   include_paths           = GetIncludePaths(dec_paths, inf_path, edk_tools_path)
   source_paths            = GetSourcePaths(inf_path)
   test_paths              = GetTestPaths(source_paths, inf_path)
   # support_paths           = [File.expand_path(artifacts)]
   support_paths           = [File.expand_path(artifacts), File.expand_path(proj_support_path)]
   include_paths           << File.expand_path(artifacts)
   include_paths = ValidateSourceInIncludePaths(include_paths, source_paths)
   # if not proj_support_path == nil
   #    support_paths << proj_support_path.to_path()
   # end
   relative_include_paths  = GetRelativeIncludePaths(test_paths)

   new_include_paths = []
   relative_include_paths.each do |rel_path|
      include_paths.each do |inc_path|
         test_path = File.join(inc_path, rel_path)
         if File.exists?(test_path)
            new_include_paths << test_path
         end
      end
   end

   new_include_paths.each do |new_path|
      include_paths << new_path
   end

   junit_report = File.basename(inf_path)+".xml"
   if not test_paths.empty?
      yaml_hash = {
         :paths => {
            :include => include_paths,
            :support => support_paths
            },
         :files => {
            :source => source_paths,
            :test => test_paths
            },
         :junit_tests_report => {
            :artifact_filename => junit_report
            }
         }

      puts yaml_hash.to_yaml

      # if b_append and File.exists?(yaml_filename)
         # old_yaml_hash = YAML.load_file(yaml_filename)
         # yaml_hash[:paths][:include] = MergeArrays(yaml_hash[:paths][:include], old_yaml_hash[:paths][:include])
         # yaml_hash[:paths][:support] = MergeArrays(yaml_hash[:paths][:support], old_yaml_hash[:paths][:support])
         # yaml_hash[:files][:source]  = MergeArrays(yaml_hash[:files][:source],  old_yaml_hash[:files][:source])
         # yaml_hash[:files][:test]    = MergeArrays(yaml_hash[:files][:test],    old_yaml_hash[:files][:test])
      # end
      puts File.join(workspace,"user.yml")
      if File.exist?(File.join(workspace,"user.yml"))
         File.delete(File.join(workspace,"user.yml"))
      end
      File.write(File.join(workspace,"user.yml"), yaml_hash.to_yaml)
   else
      raise "ERROR: Could not find test files for \"#{inf_path}\"."
   end
   return yaml_hash
end
