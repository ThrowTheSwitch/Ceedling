# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rake'
require 'ceedling/constants'
require 'ceedling/reportinator'

describe Reportinator do
  before(:each) do
    @rp = described_class.new
  end

  # ---------------------------------------------------------------------------
  # .generate_duration_string / #generate_duration_string
  # ---------------------------------------------------------------------------

  describe '.generate_duration_string' do
    context 'sub-second durations' do
      it 'returns empty string for zero seconds' do
        expect(described_class.generate_duration_string(0)).to eq('')
      end

      it 'returns singular millisecond for 1 ms' do
        expect(described_class.generate_duration_string(0.001)).to eq('1 millisecond')
      end

      it 'returns plural milliseconds for 500 ms' do
        expect(described_class.generate_duration_string(0.5)).to eq('500 milliseconds')
      end

      it 'returns plural milliseconds for 999 ms' do
        expect(described_class.generate_duration_string(0.999)).to eq('999 milliseconds')
      end
    end

    context 'second-range durations' do
      it 'returns seconds for exactly 1 second' do
        expect(described_class.generate_duration_string(1.0)).to eq('1.0 seconds')
      end

      it 'returns seconds for 1.5 seconds' do
        expect(described_class.generate_duration_string(1.5)).to eq('1.5 seconds')
      end

      it 'returns seconds rounded to precision' do
        expect(described_class.generate_duration_string(1.567, precision: 2)).to eq('1.57 seconds')
        expect(described_class.generate_duration_string(1.567, precision: 1)).to eq('1.6 seconds')
      end
    end

    context 'minute-range durations' do
      it 'returns singular minute for exactly 60 seconds' do
        expect(described_class.generate_duration_string(60.0)).to eq('1 minute')
      end

      it 'returns minute and seconds for 90 seconds' do
        expect(described_class.generate_duration_string(90.0)).to eq('1 minute 30.0 seconds')
      end

      it 'returns plural minutes for exactly 2 minutes' do
        expect(described_class.generate_duration_string(120.0)).to eq('2 minutes')
      end
    end

    context 'hour-range durations' do
      it 'returns singular hour for exactly 1 hour' do
        expect(described_class.generate_duration_string(3600.0)).to eq('1 hour')
      end

      it 'returns hour, minute, and seconds for 1 hour 1 minute 1 second' do
        expect(described_class.generate_duration_string(3661.0)).to eq('1 hour 1 minute 1.0 seconds')
      end

      it 'returns plural hours for exactly 2 hours' do
        expect(described_class.generate_duration_string(7200.0)).to eq('2 hours')
      end
    end

    context 'day-range durations' do
      it 'returns singular day for exactly 1 day' do
        expect(described_class.generate_duration_string(86400.0)).to eq('1 day')
      end

      it 'returns plural days for exactly 2 days' do
        expect(described_class.generate_duration_string(172800.0)).to eq('2 days')
      end

      it 'drops sub-second remainder after days' do
        expect(described_class.generate_duration_string(172800.5)).to eq('2 days')
      end
    end

    context 'abbreviation' do
      it 'abbreviates hours to hr/hrs' do
        expect(described_class.generate_duration_string(3600.0, abbreviate: true)).to eq('1 hr')
        expect(described_class.generate_duration_string(7200.0, abbreviate: true)).to eq('2 hrs')
      end

      it 'abbreviates minutes to min/mins' do
        expect(described_class.generate_duration_string(60.0, abbreviate: true)).to eq('1 min')
        expect(described_class.generate_duration_string(120.0, abbreviate: true)).to eq('2 mins')
      end

      it 'abbreviates seconds to secs' do
        expect(described_class.generate_duration_string(1.5, abbreviate: true)).to eq('1.5 secs')
      end

      it 'abbreviates compound duration' do
        expect(described_class.generate_duration_string(3661.0, abbreviate: true)).to eq('1 hr 1 min 1.0 secs')
      end

      it 'does not abbreviate days or milliseconds' do
        expect(described_class.generate_duration_string(86400.0, abbreviate: true)).to eq('1 day')
        expect(described_class.generate_duration_string(0.001, abbreviate: true)).to eq('1 millisecond')
        expect(described_class.generate_duration_string(0.5, abbreviate: true)).to eq('500 milliseconds')
      end
    end
  end

  describe '#generate_duration_string' do
    it 'delegates to the class method with defaults' do
      expect(@rp.generate_duration_string(90.0)).to eq('1 minute 30.0 seconds')
    end

    it 'passes precision and abbreviate through to the class method' do
      expect(@rp.generate_duration_string(3661.0, precision: 1, abbreviate: true)).to eq('1 hr 1 min 1.0 secs')
    end
  end

  # ---------------------------------------------------------------------------
  # .generate_duration_from_interval / #generate_duration_from_interval
  # ---------------------------------------------------------------------------

  describe '.generate_duration_from_interval' do
    it 'returns empty string when start_time_s is nil' do
      expect(described_class.generate_duration_from_interval(start_time_s: nil, end_time_s: 10.0)).to eq('')
    end

    it 'returns empty string when end_time_s is nil' do
      expect(described_class.generate_duration_from_interval(start_time_s: 5.0, end_time_s: nil)).to eq('')
    end

    it 'returns empty string when both times are nil' do
      expect(described_class.generate_duration_from_interval(start_time_s: nil, end_time_s: nil)).to eq('')
    end

    it 'returns the formatted duration for a valid interval' do
      expect(described_class.generate_duration_from_interval(start_time_s: 0.0, end_time_s: 90.0)).to eq('1 minute 30.0 seconds')
    end

    it 'passes precision through to generate_duration_string' do
      expect(described_class.generate_duration_from_interval(start_time_s: 0.0, end_time_s: 1.567, precision: 1)).to eq('1.6 seconds')
    end

    it 'passes abbreviate through to generate_duration_string' do
      expect(described_class.generate_duration_from_interval(start_time_s: 0.0, end_time_s: 90.0, abbreviate: true)).to eq('1 min 30.0 secs')
    end
  end

  describe '#generate_duration_from_interval' do
    it 'delegates to the class method' do
      expect(@rp.generate_duration_from_interval(start_time_s: 0.0, end_time_s: 60.0)).to eq('1 minute')
    end

    it 'passes precision and abbreviate through' do
      expect(@rp.generate_duration_from_interval(start_time_s: 0.0, end_time_s: 7200.0, abbreviate: true)).to eq('2 hrs')
    end
  end

  # ---------------------------------------------------------------------------
  # #generate_banner
  # ---------------------------------------------------------------------------

  describe '#generate_banner' do
    it 'generates a banner with a width based on a string' do
      expect(@rp.generate_banner("Hello world!")).to eq("------------\nHello world!\n------------\n")
    end

    it 'generates a banner with a fixed width' do
      expect(@rp.generate_banner("Hello world!", 3)).to eq("---\nHello world!\n---\n")
    end
  end

  # ---------------------------------------------------------------------------
  # #generate_heading
  # ---------------------------------------------------------------------------

  describe '#generate_heading' do
    it 'generates a heading with a dash underline matching the message length' do
      expect(@rp.generate_heading("Hello")).to eq("\nHello\n-----")
    end

    it 'strips leading/trailing whitespace when measuring dash count' do
      expect(@rp.generate_heading("  Hi  ")).to eq("\n  Hi  \n--")
    end
  end

  # ---------------------------------------------------------------------------
  # #generate_progress
  # ---------------------------------------------------------------------------

  describe '#generate_progress' do
    it 'appends ellipsis to the message' do
      expect(@rp.generate_progress("Building")).to eq("Building...")
    end
  end

  # ---------------------------------------------------------------------------
  # #generate_module_progress
  # ---------------------------------------------------------------------------

  describe '#generate_module_progress' do
    it 'omits module label when filename matches module name' do
      result = @rp.generate_module_progress(module_name: 'foo', filename: 'foo.c', operation: 'Compiling')
      expect(result).to eq("Compiling foo.c...")
    end

    it 'prepends module label when filename differs from module name' do
      result = @rp.generate_module_progress(module_name: 'bar', filename: 'baz.c', operation: 'Compiling')
      expect(result).to eq("Compiling bar::baz.c...")
    end
  end

  # ---------------------------------------------------------------------------
  # #generate_config_walk
  # ---------------------------------------------------------------------------

  describe '#generate_config_walk' do
    it 'formats a list of keys with arrow separators' do
      expect(@rp.generate_config_walk([:foo, :bar, :baz])).to eq(':foo ↳ :bar ↳ :baz')
    end

    it 'returns a single key with no separator' do
      expect(@rp.generate_config_walk([:only])).to eq(':only')
    end

    it 'limits output to depth when depth is positive' do
      expect(@rp.generate_config_walk([:a, :b, :c], 2)).to eq(':a ↳ :b')
    end

    it 'filters out nil keys' do
      expect(@rp.generate_config_walk([:a, nil, :c])).to eq(':a ↳ :c')
    end
  end

end
