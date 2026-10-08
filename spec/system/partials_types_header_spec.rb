# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Shared Partials Types Header (issue #1319)
## ==========================================
##
## Partials lifts a module's type definitions into one shared header so a module tested and
## mocked in the same test file still gets exactly one C definition of each type. That header
## lands in the generated include lists at the position the module's own header occupied, which
## is earlier than the module's own source placed its dependencies.
##
## Until this fix the shared header emitted no #include directives at all, so it compiled only
## where something earlier in the translation unit happened to have declared the names its
## extracted types reference. A module whose header declares a type in terms of one another
## header supplies failed with `unknown type name`, and the same gap applied to a macro an
## extracted type names.
##
## The header now carries those dependencies itself, and states the real module header's include
## guard deliberately so a transitive reach at that header finds it already satisfied.
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("partials_types") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    # =========================================================================
    describe "a Partial's extracted types depending on another header" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            File.write('src/units.h', <<~C)
              #ifndef UNITS_H
              #define UNITS_H

              typedef signed short Celsius;

              #endif // UNITS_H
            C
            File.write('src/sensor.h', <<~C)
              #ifndef SENSOR_H
              #define SENSOR_H

              #include "units.h"

              typedef struct
              {
                  Celsius limit;
              } SensorConfig;

              int sensor_over_limit(Celsius reading);

              #endif // SENSOR_H
            C
            File.write('src/sensor.c', <<~C)
              #include "sensor.h"

              static SensorConfig config = { .limit = 30 };

              static Celsius sensor_limit(void)
              {
                  return config.limit;
              }

              int sensor_over_limit(Celsius reading)
              {
                  return reading > sensor_limit();
              }
            C
            File.write('test/test_sensor.c', <<~C)
              #ifdef TEST

              #include "unity.h"
              #include "ceedling.h"

              #include TEST_PARTIAL_ALL_MODULE(sensor)

              void setUp(void) {}
              void tearDown(void) {}

              void test_sensor_reads_its_own_file_scope_config(void)
              {
                  TEST_ASSERT_EQUAL_INT(30, sensor_limit());
              }

              void test_sensor_over_limit_uses_the_exposed_limit(void)
              {
                  config.limit = 10;
                  TEST_ASSERT_TRUE(sensor_over_limit(11));
                  TEST_ASSERT_FALSE(sensor_over_limit(9));
              }

              #endif // TEST
            C

            @c.merge_project_yml_for_test( :project => { :use_partials => true } )
          end
        end
      end

      # Exercises the whole chain at once: the carried dependency makes the shared types header
      # compile, the stripped `static` on a file-scope variable makes it reachable from the test,
      # and the stripped `static` on a function makes it callable.
      it "builds and passes, reaching the module's exposed statics" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")

            expect(@c.last_exit_status).to eq(0), "build failed:\n#{output}"
            expect(output).to match(/TESTED:\s+2/)
            expect(output).to match(/PASSED:\s+2/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      # The dependency the shared header carries, and the guard it spoofs, are both emitted into
      # the generated file. Reading it directly states what the build result alone cannot show.
      it "carries the dependency and spoofs the real header's guard" do
        @c.with_context do
          Dir.chdir @proj_name do
            @c.ceedling_build_exec("test:all")

            generated = Dir.glob('build/test/partials/**/*sensor_types.h').first
            expect(generated).not_to be_nil, 'no shared types header was generated'

            contents = File.read(generated)
            expect(contents).to match(/#include\s+"units\.h"/)
            expect(contents).to match(/^#define SENSOR_H$/)

            # The spoof has to precede the carried include: that include can reach the real
            # module header in turn, and the guard must already be satisfied when it does.
            expect(contents.index('#define SENSOR_H')).to be < contents.index('#include "units.h"')
          end
        end
      end

    end

  end

end
