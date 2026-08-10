# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/path_mirror'

describe PathMirror do

  describe '.relative_subdir' do
    it 'returns an empty string for a file directly inside a configured root' do
      expect(described_class.relative_subdir('src/foo.c', ['src/**'])).to eq('')
    end

    it 'returns the directory structure below a configured root' do
      expect(described_class.relative_subdir('src/drivers/foo.c', ['src/**'])).to eq('drivers')
      expect(described_class.relative_subdir('src/drivers/sensors/foo.c', ['src/**'])).to eq('drivers/sensors')
    end

    it 'strips +:/-: aggregation decorators from configured roots before comparing' do
      expect(described_class.relative_subdir('src/drivers/foo.c', ['+:src/**'])).to eq('drivers')
      expect(described_class.relative_subdir('src/drivers/foo.c', ['-:src/**'])).to eq('drivers')
    end

    it 'picks the most specific (longest) matching root when configured roots are nested' do
      roots = ['src/**', 'src/legacy/**']
      expect(described_class.relative_subdir('src/legacy/foo.c', roots)).to eq('')
      expect(described_class.relative_subdir('src/legacy/vendor/foo.c', roots)).to eq('vendor')
      expect(described_class.relative_subdir('src/drivers/foo.c', roots)).to eq('drivers')
    end

    it 'returns an empty string when no configured root contains the file' do
      expect(described_class.relative_subdir('build/vendor/unity/src/unity.c', ['src/**'])).to eq('')
    end

    it 'returns an empty string when given no roots at all' do
      expect(described_class.relative_subdir('src/drivers/foo.c', [])).to eq('')
    end

    it 'treats a plain, non-globbed root the same as a globbed one' do
      expect(described_class.relative_subdir('src/drivers/foo.c', ['src'])).to eq('drivers')
    end
  end

  describe '.clean_roots and .relative_subdir_from_clean_roots' do
    it 'produces the same result as .relative_subdir when roots are cleaned once upfront' do
      clean = described_class.clean_roots(['+:src/**', '-:src/legacy/**'])
      expect(described_class.relative_subdir_from_clean_roots('src/drivers/foo.c', clean)).to eq('drivers')
      expect(described_class.relative_subdir_from_clean_roots('src/legacy/vendor/foo.c', clean)).to eq('vendor')
    end

    it 'drops decorated roots that clean to nothing' do
      expect(described_class.clean_roots(['+:', '-:*.c', 'src'])).to eq(['src'])
    end
  end

end
