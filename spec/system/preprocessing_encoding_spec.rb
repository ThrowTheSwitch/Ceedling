# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("encoding") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    describe "Test builds with multibyte UTF-8 characters in C source file comments" do
      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.c"), 'src/'
          end
        end
      end

      it "tests standard preprocessing with non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
            @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :mocks } })
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            # Only assert non-fallback when the platform actually supports -fdirectives-only.
            # Apple clang (macOS) silently ignores the flag and ceedling falls back automatically.
            expect(output).not_to match(/using fallback method/i) unless output.match(/lacks -fdirectives-only support/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests fallback preprocessing with non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
            settings = {
              :project    => { :use_test_preprocessor => :mocks },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests Partials with standard preprocessing and non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder_partial.c"), 'test/'
            # :use_partials automatically enables mocking and preprocessing — no explicit
            # :use_test_preprocessor needed.
            @c.merge_project_yml_for_test({ :project => { :use_partials => true } })
            output = @c.ceedling_build_exec("test:unicoder_partial")
            expect(@c.last_exit_status).to eq(0)
            # Only assert non-fallback when the platform actually supports -fdirectives-only.
            # Apple clang (macOS) silently ignores the flag and ceedling falls back automatically.
            expect(output).not_to match(/using fallback method/i) unless output.match(/lacks -fdirectives-only support/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests Partials with fallback preprocessing and non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder_partial.c"), 'test/'
            settings = {
              :project    => { :use_partials => true },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:unicoder_partial")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end
    end

    # Distinct from the multibyte-UTF-8 cases above: those plant *valid*
    # multi-byte characters (whole, well-formed sequences). This plants an
    # *incomplete* one -- a lead byte with missing or insufficient
    # continuation bytes, as if a multi-byte character had been clipped by a
    # chunk boundary or a truncated copy/paste. Written directly with
    # File.binwrite (not a checked-in fixture asset) so the malformed bytes
    # never have to round-trip through a text editor or git's own line-ending
    # handling -- only ever exist on disk for the life of this test.
    describe "Test builds with an incomplete (truncated) multi-byte UTF-8 sequence in C source file comments" do
      before do
        @c.with_context do
          Dir.chdir @proj_name do
            # \xE4\xBD is the first two of three bytes of U+4F60 (你), missing
            # its final continuation byte. \xE4 alone is a lead byte with no
            # continuation bytes at all. Both are invalid UTF-8 on their own.
            File.binwrite('src/truncated_encoding.h', <<~HEADER.dup.force_encoding('BINARY'))
              /* Truncated multi-byte sequence: \xE4\xBD -- missing its final continuation byte */
              #ifndef TRUNCATED_ENCODING_H
              #define TRUNCATED_ENCODING_H

              /* Lone lead byte, no continuation at all: \xE4 */
              int truncated_encoding_greet(void);

              #endif /* TRUNCATED_ENCODING_H */
            HEADER

            File.binwrite('src/truncated_encoding.c', <<~SOURCE.dup.force_encoding('BINARY'))
              /* Truncated multi-byte sequence in implementation: \xE4\xBD */
              #include "truncated_encoding.h"

              int truncated_encoding_greet(void)
              {
                  return 5; /* \xE4 lone lead byte in a trailing comment */
              }
            SOURCE

            File.write('test/test_truncated_encoding.c', <<~TEST)
              #include "unity.h"
              #include "mock_truncated_encoding.h"

              void test_truncated_encoding_greet_returns_expected_length(void)
              {
                  truncated_encoding_greet_ExpectAndReturn(5);
                  TEST_ASSERT_EQUAL(5, truncated_encoding_greet());
              }
            TEST
          end
        end
      end

      it "tests standard preprocessing with a truncated multi-byte sequence in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :mocks } })
            output = @c.ceedling_build_exec("test:truncated_encoding")
            expect(@c.last_exit_status).to eq(0)
            expect(output).not_to match(/using fallback method/i) unless output.match(/lacks -fdirectives-only support/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests fallback preprocessing with a truncated multi-byte sequence in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = {
              :project    => { :use_test_preprocessor => :mocks },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:truncated_encoding")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end
    end
  end
end
