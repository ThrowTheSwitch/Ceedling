# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator_bare_includes_extractor'
require 'ceedling/includes/includes'

# PreprocessinatorBareIncludesExtractor is a pure parser: it turns the `gcc -M -MG -MP`
# "phony" make rules -- one `header:` line per dependency -- into bare Include objects.
# The handler that runs GCC (PreprocessinatorIncludesHandler#extract_bare_includes)
# gates on MAKE_RULE_MATCHER first and hands only matching output here, so these tests
# feed representative make-rule text directly.
describe PreprocessinatorBareIncludesExtractor do
  def extract(text) = described_class.extract_includes(text)

  it 'returns one bare Include per phony rule line' do
    rules = <<~RULES
      widget.o: widget.c widget.h stdint.h
      widget.h:
      stdint.h:
    RULES
    result = extract(rules)
    expect(result.map(&:filename)).to eq(['widget.h', 'stdint.h'])
    expect(result).to all(be_an_instance_of(Include))
  end

  it 'produces no includes from a make rule with no phony lines (file has no #includes)' do
    expect(extract("solo.o: solo.c\n")).to eq([])
  end

  it 'captures a phony rule for a pathful dependency' do
    rules = <<~RULES
      os.o: ../../src/os/os.h fstd_types.h
      ../../src/os/os.h:
      fstd_types.h:
    RULES
    expect(extract(rules).map(&:filepath)).to contain_exactly('../../src/os/os.h', 'fstd_types.h')
  end

  it 'deduplicates a dependency that appears in more than one phony rule' do
    rules = <<~RULES
      a.o: a.c shared.h
      shared.h:
      shared.h:
    RULES
    expect(extract(rules).map(&:filename)).to eq(['shared.h'])
  end

  it 'ignores GCC diagnostic lines interleaved with the phony rules' do
    rules = <<~RULES
      os.o: os.c os.h
      os.h:
      os.h:73:20: error: no include path in which to search for stdint.h
         73 | #include <stdint.h>
            |                    ^
    RULES
    expect(extract(rules).map(&:filename)).to eq(['os.h'])
  end

  it 'ignores a bare dependency filename that has no extension' do
    # INCLUDE_MATCHER requires a `.<ext>` -- an extensionless phony rule is skipped.
    rules = <<~RULES
      m.o: m.c helper.h Makefile
      helper.h:
      Makefile:
    RULES
    expect(extract(rules).map(&:filename)).to eq(['helper.h'])
  end
end
