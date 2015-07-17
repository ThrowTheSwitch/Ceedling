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
        `bundle exec ruby -S ceedling new #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { contains_documentation }
    it { can_test_projects }
    it { can_use_the_module_plugin }
  end

  describe "deployed in a project's `vendor` directory without docs." do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --nodocs #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { does_not_contain_documentation }
    it { can_test_projects }
    it { can_use_the_module_plugin }
  end

  describe "deployed as a gem" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --as-gem #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { does_not_contain_a_vendor_directory }
    it { can_test_projects }
    it { can_use_the_module_plugin }
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
      expect(@output.lines.to_a.length).to eq 3
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
            @output = `bundle exec ruby -S rake test:all`
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
    #         @output = `bundle exec ruby -S rake test:all`
    #         expect(@output).to match(/TESTED:\s+7/)
    #         expect(@output).to match(/PASSED:\s+7/)
    #       end
    #     end
    #   end
    # end
  end
end
