# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$: << File.expand_path('../../../../plugins/sanitize/lib', __FILE__)
require 'sanitize_config'

describe SanitizeConfig do
  let(:defaults) do
    { sanitizers: ['address', 'undefined'], recover: false, detect_leaks: true, test_builds: false, fail_build: true, runtime_options: {}, flags: {} }
  end

  def resolve(platform: :linux, **overrides)
    return described_class.new( defaults.merge( overrides ), platform: platform )
  end

  describe 'flags' do
    it 'instruments compiles to halt at the first finding, with stack frames kept' do
      expect(resolve.compile_flags).to eq( ['-fsanitize=address,undefined', '-fno-sanitize-recover=all', '-fno-omit-frame-pointer', '-g'] )
    end

    it 'links the sanitizers\' runtimes' do
      expect(resolve.link_flags).to eq( ['-fsanitize=address,undefined'] )
    end

    it 'leaves recovery on when asked to keep running after a finding' do
      expect(resolve( recover: true ).compile_flags).not_to include( '-fno-sanitize-recover=all' )
    end

    it 'adds a project\'s own compile and link flags last' do
      config = resolve( flags: { compile: ['-O1'], link: ['-static-libasan'] } )

      expect(config.compile_flags.last).to eq( '-O1' )
      expect(config.link_flags.last).to eq( '-static-libasan' )
    end

    # ASan's runtime includes leak detection
    it 'checks leaks through ASan without a separate leak sanitizer' do
      expect(resolve( sanitizers: ['address', 'leak'] ).compile_flags.first).to eq( '-fsanitize=address' )
    end

    it 'builds a leak sanitizer alone when ASan is not asked for' do
      expect(resolve( sanitizers: ['leak'] ).compile_flags.first).to eq( '-fsanitize=leak' )
    end
  end

  # Findings come from each report, not from the exit code. A halt leaves Unity's summary
  # missing, which reads as a crash, and a leak at exit leaves a clean summary.
  describe 'runtime environment' do
    it 'halts at the first finding, prints stacks, and exits as the test would' do
      expect(resolve.environment).to eq(
        'ASAN_OPTIONS'  => 'halt_on_error=1:exitcode=0:detect_leaks=1',
        'UBSAN_OPTIONS' => 'halt_on_error=1:print_stacktrace=1:exitcode=0'
      )
    end

    it 'keeps running after a finding when asked to recover' do
      expect(resolve( recover: true ).environment['UBSAN_OPTIONS']).to start_with( 'halt_on_error=0' )
    end

    it 'turns leak checking off when asked' do
      expect(resolve( detect_leaks: false ).environment['ASAN_OPTIONS']).to include( 'detect_leaks=0' )
    end

    it 'sets the leak sanitizer\'s own options when it runs alone' do
      expect(resolve( sanitizers: ['leak'] ).environment).to eq( 'LSAN_OPTIONS' => 'exitcode=0' )
    end

    it 'adds a project\'s own runtime options last' do
      config = resolve( runtime_options: { asan: ['strict_string_checks=1'], ubsan: ['report_error_type=1'] } )

      expect(config.environment['ASAN_OPTIONS']).to end_with( ':strict_string_checks=1' )
      expect(config.environment['UBSAN_OPTIONS']).to end_with( ':report_error_type=1' )
    end
  end

  # LeakSanitizer is not supported on macOS, where ASan aborts when asked to check leaks
  describe 'on macOS' do
    it 'never asks ASan to check leaks, with a notice' do
      config = resolve( platform: :macos )

      expect(config.environment['ASAN_OPTIONS']).not_to include( 'detect_leaks' )
      expect(config.notices).to include( /leak.*not supported on macOS/i )
    end

    it 'drops a requested leak sanitizer, with a notice' do
      config = resolve( sanitizers: ['address', 'leak'], platform: :macos )

      expect(config.sanitizers).to eq( [:address] )
      expect(config.notices).to include( /leak.*not supported on macOS/i )
    end
  end

  describe 'validation' do
    it 'reads sanitizer names as symbols or strings in any letter case' do
      expect(resolve( sanitizers: [:Address, 'UNDEFINED'] ).sanitizers).to eq( [:address, :undefined] )
    end

    it 'rejects an unknown sanitizer, listing the choices' do
      expect { resolve( sanitizers: ['thread'] ) }.to raise_error(
        CeedlingException, /:sanitize ↳ :sanitizers entry `thread` is not a supported sanitizer. Choose from :address, :undefined, :leak./
      )
    end

    it 'rejects an empty sanitizer list' do
      expect { resolve( sanitizers: [] ) }.to raise_error( CeedlingException, /:sanitize ↳ :sanitizers names no sanitizer/ )
    end

    it 'rejects a setting that is not a boolean' do
      expect { resolve( recover: 'false' ) }.to raise_error( CeedlingException, /:sanitize ↳ :recover must be TRUE or FALSE/ )
    end
  end
end
