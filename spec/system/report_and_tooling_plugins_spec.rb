# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'json'
require 'rexml/document'

##
## Reporting and Tooling Plugins in a Real Build
## =============================================
##
## The log factory, the IDE and GTest-like console reports, and the JSON compilation
## database each run against a real project here. Their unit and integration specs prove
## what each one makes of its inputs. This spec proves Ceedling hands them those inputs
## from an actual build, and that what they leave behind is usable.
##
## One test file holds a passing, a failing, and an ignored test, so every outcome
## reaches every report.
##

ADDER_HEADER_C = <<~C
  #ifndef ADDER_H
  #define ADDER_H

  int adder_add(int a, int b);

  #endif // ADDER_H
C

ADDER_SOURCE_C = <<~C
  #include "adder.h"

  int adder_add(int a, int b)
  {
      return a + b;
  }
C

TEST_ADDER_C = <<~C
  #ifdef TEST

  #include "unity.h"
  #include "adder.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_adder_adds(void)
  {
      TEST_ASSERT_EQUAL_INT(5, adder_add(2, 3));
  }

  void test_adder_fails(void)
  {
      TEST_ASSERT_EQUAL_INT(5, adder_add(2, 2));
  }

  void test_adder_waits(void)
  {
      TEST_IGNORE();
  }

  #endif // TEST
C

# An inline function makes a header mockable only through a shadow header, which is
# what sends a source beside it to an isolated copy
GPIO_HEADER_C = <<~C
  #ifndef GPIO_H
  #define GPIO_H

  static inline int gpio_read(int pin) { return pin; }

  #endif // GPIO_H
C

READER_HEADER_C = <<~C
  #ifndef READER_H
  #define READER_H

  int reader_read(int pin);

  #endif // READER_H
C

READER_SOURCE_C = <<~C
  #include "reader.h"
  #include "gpio.h"

  int reader_read(int pin)
  {
      return gpio_read(pin);
  }
C

TEST_READER_C = <<~C
  #ifdef TEST

  #include "unity.h"
  #include "reader.h"
  #include "mock_gpio.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_reader_reads_through_the_mock(void)
  {
      gpio_read_ExpectAndReturn(4, 1);
      TEST_ASSERT_EQUAL_INT(1, reader_read(4));
  }

  #endif // TEST
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "report_plugins"

  describe "Deployed as a gem" do

    before do
      in_project do
        File.write('src/adder.h', ADDER_HEADER_C)
        File.write('src/adder.c', ADDER_SOURCE_C)
        File.write('test/test_adder.c', TEST_ADDER_C)
      end
    end

    # =========================================================================
    describe "the test suite report log factory" do
    # =========================================================================

      # The project template already configures all four reports
      before { in_project { @c.uncomment_project_yml_option_for_test('- report_tests_log_factory') } }

      let(:reports) do
        %w[tests_report.json junit_tests_report.xml cppunit_tests_report.xml tests_report.html].map do |name|
          File.join('build', 'artifacts', 'test', name)
        end
      end

      it "writes every configured report, each one well formed" do
        in_project do
          @c.ceedling_build_exec("test:all")

          json, junit, cppunit, html = reports.map { |report| File.read( report ) }

          expect(JSON.parse( json )['Summary']).to include('total_tests' => 3, 'passed' => 1, 'failures' => 1, 'ignored' => 1)
          expect(REXML::Document.new( junit ).root.attributes['tests']).to eq('3')
          expect(REXML::Document.new( cppunit ).root.elements['Statistics/Tests'].text).to eq('3')
          expect(html).to include('test_adder_fails')
        end
      end

      # The summary task builds no tests. It reports from the results the build left.
      it "writes the reports again from an earlier build's results on `ceedling summary`" do
        in_project do
          @c.ceedling_build_exec("test:all")
          FileUtils.rm_rf( File.join('build', 'artifacts', 'test') )

          @c.ceedling_build_exec("summary")

          expect(reports.select { |report| File.exist?( report ) }).to eq(reports)
          expect(REXML::Document.new( File.read( reports[1] ) ).root.attributes['tests']).to eq('3')
        end
      end
    end

    # =========================================================================
    describe "the IDE console report" do
    # =========================================================================

      before do
        in_project do
          @c.comment_project_yml_option_for_test('- report_tests_pretty_stdout')
          @c.uncomment_project_yml_option_for_test('- report_tests_ide_stdout')
        end
      end

      it "lists a failure as filepath, line, test name, and message" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(output).to match(%r{test/test_adder\.c:\d+:test_adder_fails: "Expected 5 Was 4"})
          expect(output).to match(/TESTED:\s+3/)
        end
      end
    end

    # =========================================================================
    describe "the GTest-like console report" do
    # =========================================================================

      before do
        in_project do
          @c.comment_project_yml_option_for_test('- report_tests_pretty_stdout')
          @c.uncomment_project_yml_option_for_test('- report_tests_gtestlike_stdout')
        end
      end

      # GTest has no ignored outcome, so the ignored test is left out of every count
      it "frames the run with GTest's header and footer counts" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(output).to include('[==========] Running 2 tests from 1 test cases.')
          expect(output).to include('[       OK ] test/test_adder.c.test_adder_adds')
          expect(output).to include('[  PASSED  ] 1 tests.')
          expect(output).to include('[  FAILED  ] 1 tests, listed below:')
        end
      end
    end

    # =========================================================================
    describe "the JSON compilation database" do
    # =========================================================================

      let(:database_path) { File.join('build', 'artifacts', 'compile_commands.json') }

      before { in_project { @c.uncomment_project_yml_option_for_test('- compile_commands_json_db') } }

      it "lists each compiled source once, across repeated builds" do
        in_project do
          @c.ceedling_build_exec("test:all")
          FileUtils.touch('src/adder.c')
          @c.ceedling_build_exec("test:all")

          files = JSON.parse( File.read( database_path ) ).map { |entry| entry['file'] }

          expect(files).to include('src/adder.c', 'test/test_adder.c')
          expect(files).to eq(files.uniq)
        end
      end

      # The compiler ran on a temporary copy, which is gone once the build ends
      it "names the original source in the command for a source compiled from an isolated copy" do
        in_project do
          File.write('src/gpio.h', GPIO_HEADER_C)
          File.write('src/reader.h', READER_HEADER_C)
          File.write('src/reader.c', READER_SOURCE_C)
          File.write('test/test_reader.c', TEST_READER_C)
          @c.merge_project_yml_for_test(
            :project => { :use_mocks => true },
            :paths   => { :include => ['src/**'] },
            :cmock   => { :treat_inlines => :include }
          )

          output = @c.ceedling_build_exec("test:test_reader")
          expect(output).to match(/Compiling an isolated copy of '.*reader\.c'/)

          entry = JSON.parse( File.read( database_path ) ).find { |compile| compile['file'] == 'src/reader.c' }

          expect(entry['command']).to include('src/reader.c')
          expect(entry['command'].scan( %r{[\w./\\-]*reader\.c\b} )).to all( eq('src/reader.c') )
        end
      end
    end

  end

end
