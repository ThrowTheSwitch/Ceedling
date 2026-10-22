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


  # Distinct from `relative_subdir`, which answers '' both for a file sitting directly in a
  # root and for one no root contains. A caller that must tell those apart -- one deciding
  # whether to rewrite a query at all -- needs the difference.
  describe '.relative_subdir_if_rooted' do
    it 'returns the subdirectory below the matching root' do
      expect( PathMirror.relative_subdir_if_rooted('include/drivers/uart/config.h', ['include/**']) )
        .to eq('drivers/uart')
    end

    it 'returns an empty string for a file sitting directly in a root' do
      expect( PathMirror.relative_subdir_if_rooted('include/config.h', ['include']) ).to eq('')
    end

    it 'returns nil when no root contains the file' do
      expect( PathMirror.relative_subdir_if_rooted('src/config.c', ['include']) ).to be_nil
    end

    it 'prefers the longest matching root' do
      expect( PathMirror.relative_subdir_if_rooted('include/drivers/uart/config.h', ['include', 'include/drivers']) )
        .to eq('uart')
    end

    it 'returns nil for an empty root list' do
      expect( PathMirror.relative_subdir_if_rooted('include/config.h', []) ).to be_nil
    end
  end

  # One spelling of path-segment comparison, shared by every caller that matches trailing
  # path segments rather than whole paths.
  describe '.path_segments' do
    it 'splits on either separator' do
      expect( PathMirror.path_segments('drivers/uart\\config') ).to eq(['drivers', 'uart', 'config'])
    end

    it 'folds case so comparison is case-insensitive' do
      expect( PathMirror.path_segments('Drivers/UART') ).to eq(['drivers', 'uart'])
    end

    it 'drops empty segments from doubled or trailing separators' do
      expect( PathMirror.path_segments('drivers//uart/') ).to eq(['drivers', 'uart'])
    end
  end
end
