# © Copyright 2019-2020 HP Development Company, L.P.
# SPDX-License-Identifier: MIT

require 'pathname'

EDK2_ROOT_NAME         = 'edk2'
EDK2_TASK_ROOT         = EDK2_ROOT_NAME + ':'
EDK2_SYM               = EDK2_ROOT_NAME.to_sym

EDK2_ARTIFACTS_PATH = File.expand_path(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, EDK2_ROOT_NAME))

EDK2_ROOT_PATH = File.expand_path(File.dirname(__FILE__))
EDK2_ASSETS_PATH = File.expand_path(File.join(EDK2_ROOT_PATH, "assets"))
EDK2_LIB_PATH = File.expand_path(File.join(EDK2_ROOT_PATH, "lib"))

EDK2_AUTOGEN_TOOL_PATH = File.expand_path(File.join(EDK2_ASSETS_PATH, "autogen", "ut_autogen.py"))
EDK2_SUPPORT_PATH = File.expand_path(File.join(EDK2_ASSETS_PATH, "support"))

CLOBBER.include(File.join(PROJECT_ROOT, "user.yml"))

require "#{EDK2_LIB_PATH}/autogen.rb"
require "#{EDK2_LIB_PATH}/update_paths.rb"

namespace :edk2 do
    module_root_separator = ":"

    desc "Perform edk2 autogen for module"
    task :autogen, :inf_path do |t, args|
        AutoGen.new.module_autogen(EDK2_AUTOGEN_TOOL_PATH, args.inf_path, EDK2_ARTIFACTS_PATH)
    end

    desc "Copy edk2 support files to artifacts folder"
    task :copy_support do
        support_files = @ceedling[:file_wrapper].directory_listing(File.join(EDK2_SUPPORT_PATH, '*'))
        support_files.each do |file|
            @ceedling[:file_wrapper].cp(file, EDK2_ARTIFACTS_PATH)
        end
    end

    desc "Updates user include paths based on the discoved inf paths"
    task :update_paths, :inf_path do |t, args|
        puts @ceedling[:setupinator].config_hash
        # raise
        user_yml = UpdateModulePathsFromInf(
            PROJECT_ROOT,
            EDK2_ARTIFACTS_PATH,
            File.join(PROJECT_BUILD_ROOT, "test", "cache"),
            @ceedling[:setupinator].config_hash[:edk2][:projectpaths][:edk2_tools_path],
            @ceedling[:setupinator].config_hash[:edk2][:projectpaths][:dsc_path],
            args.inf_path,
            @ceedling[:setupinator].config_hash[:edk2][:projectpaths][:user_support_path]
        )
        @ceedling[:setupinator].config_hash.merge!(user_yml)
        # puts @ceedling[:setupinator].config_hash
        # raise
    end

    desc "Validates compiler options, enforces user to include Uefi.h, AutoGen.h, etc"
    task :check_includes do
        required = ["Uefi.h", "AutoGen.h"]
        includes = @ceedling[:setupinator].config_hash[:flags][:ceedling_test][:compile][:*]
        required.each do |require|
            if includes.count {|inc| inc.include?(require)} < 1
                raise "ERROR: project.yml's :flags:ceedling_test:compile:* does not contain include for \"#{require}\". EDK2 requires this file. Please update project.yml."
            end
        end
    end

    desc "Setup ceedling to test inf module (autogen, create user.yml, etc)"
    task :test, :inf_path do |t, args|
        inf_path = args.inf_path.gsub("\\", "/")
        inf_path = File.expand_path(inf_path)
        puts inf_path
        puts Pathname(inf_path)
        if File.extname(inf_path).downcase != ".inf"
            raise "ERROR: \"#{inf_path}\" is not an INF file"
        end
        if !File.exist?(inf_path)
            raise "ERROR \"#{inf_path} does not exist on filesystem.\""
        end

        Rake::Task["edk2:autogen"].invoke(inf_path)
        Rake::Task["edk2:copy_support"].invoke
        Rake::Task["edk2:update_paths"].invoke(inf_path)
        Rake::Task["edk2:check_includes"].invoke

        # Finally invoke Ceedling to run our tests, probably would be helpful if
        # we could just resetup Ceedling...
        # the following call invokes ceedling and closes current process
        exec("ceedling test")
        # @ceedling[:test_invoker].setup_and_invoke(@ceedling[:setupinator].config_hash[:files][:test])
    end
end