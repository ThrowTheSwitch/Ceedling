require 'spec_system_helper'

describe "Ceedling" do
  include CeedlingTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "fake_project" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "deployed in a project's `vendor` directory." do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local --docs #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { contains_documentation }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_test_name_replaced_defines_with_success }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }
    it { can_test_projects_with_both_mock_and_real_header }
    it { can_test_projects_with_success_when_space_appears_between_hash_and_include }
    it { uses_raw_output_report_plugin }
    it { can_use_the_module_plugin }
    it { can_use_the_module_plugin_path_extension }
    it { can_use_the_module_plugin_with_include_path }
    it { can_use_the_module_plugin_with_non_default_paths }
    it { handles_creating_the_same_module_twice_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension }
    it { test_run_of_projects_fail_because_of_sigsegv_without_report }
    it { test_run_of_projects_fail_because_of_sigsegv_with_report }
    it { can_run_single_test_with_full_test_case_name_from_test_file_with_success_cmdline_args_are_enabled }
    it { can_run_single_test_with_partiall_test_case_name_from_test_file_with_enabled_cmdline_args_success }
    it { exlcude_test_case_name_filter_works_and_only_one_test_case_is_executed }
    it { none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file_and_cmdline_args_are_enabled }
    it { none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same }
    it { run_all_test_when_test_case_name_is_passed_but_cmdline_args_are_disabled_with_success }
  end

  describe "deployed in a project's `vendor` directory with gitignore." do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local --docs --gitignore #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { has_an_ignore }
    it { contains_a_vendor_directory }
    it { contains_documentation }
    it { can_test_projects_with_success }
    it { can_use_the_module_plugin }
  end



  describe "deployed in a project's `vendor` directory without docs." do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { does_not_contain_documentation }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_test_name_replaced_defines_with_success }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }
    it { can_use_the_module_plugin }
    it { can_use_the_module_plugin_path_extension }
    it { can_use_the_module_plugin_with_include_path }
    it { handles_creating_the_same_module_twice_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension }
  end

  describe "ugrade a project's `vendor` directory" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { does_not_contain_documentation }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }
    it { can_use_the_module_plugin }
    it { can_use_the_module_plugin_path_extension }
    it { can_use_the_module_plugin_with_include_path }
    it { can_use_the_module_plugin_with_non_default_paths }
    it { handles_creating_the_same_module_twice_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension }

    it { can_upgrade_projects }
    it { can_upgrade_projects_even_if_test_support_folder_does_not_exists }
    it { contains_a_vendor_directory }
    it { does_not_contain_documentation }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }
    it { can_use_the_module_plugin }
    it { can_use_the_module_plugin_path_extension }
    it { can_use_the_module_plugin_with_include_path }
    it { can_use_the_module_plugin_with_non_default_paths }
    it { handles_creating_the_same_module_twice_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension }
  end

  describe "Cannot ugrade a non existing project" do
    it { cannot_upgrade_non_existing_project }
  end

  describe "deployed as a gem" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { does_not_contain_a_vendor_directory }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_test_name_replaced_defines_with_success }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_compile_error }
    it { can_use_the_module_plugin }
    it { can_use_the_module_plugin_path_extension }
    it { can_use_the_module_plugin_with_include_path }
    it { can_use_the_module_plugin_with_non_default_paths }
    it { handles_creating_the_same_module_twice_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin }
    it { handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension }
  end

  describe "deployed with auto link deep denendencies" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { can_test_projects_with_enabled_auto_link_deep_deependency_with_success }
  end

  describe "deployed with enabled preprocessor directives" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { can_test_projects_with_enabled_preprocessor_directives_with_success }
  end

  describe "command: `ceedling examples`" do
    before do
      @c.with_context do
        @output = `bundle exec ruby -S ceedling examples 2>&1`
      end
    end

    it "should list out all the examples" do
      expect(@output).to match(/blinky/)
      expect(@output).to match(/temp_sensor/)
    end
  end

  describe "command: `ceedling example [example]`" do
    describe "temp_sensor" do
      before do
        @c.with_context do
          output = `bundle exec ruby -S ceedling example temp_sensor 2>&1`
          expect(output).to match(/created!/)
        end
      end

      it "should be testable" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:all`
            expect(@output).to match(/TESTED:\s+47/)
            expect(@output).to match(/PASSED:\s+47/)
          end
        end
      end
    end

    # # blinky depends on avr-gcc. If you happen to have this installed, go
    # # ahead and uncomment this test and run it. This will fail on CI, so I'm
    # # removing it for now.
    #
    # describe "blinky" do
    #   before do
    #     @c.with_context do
    #       output = `bundle exec ruby -S ceedling example blinky 2>&1`
    #       expect(output).to match(/created!/)
    #     end
    #   end
    #
    #   it "should be testable" do
    #     @c.with_context do
    #       Dir.chdir "blinky" do
    #         @output = `bundle exec ruby -S ceedling test:all`
    #         expect(@output).to match(/TESTED:\s+7/)
    #         expect(@output).to match(/PASSED:\s+7/)
    #       end
    #     end
    #   end
    # end
  end
end
