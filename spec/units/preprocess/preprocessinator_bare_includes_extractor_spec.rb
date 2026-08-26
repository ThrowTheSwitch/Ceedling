# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator_bare_includes_extractor'
require 'ceedling/includes/includes'

# Pure, stateless parser -- no IO, no fixtures needed, just real make-rule
# text as GCC's `-M -MG -MP` output would actually contain it.
describe PreprocessinatorBareIncludesExtractor do
  describe '.extract_includes' do
    it 'returns an empty list for a self-referential rule with no dependencies' do
      make_rules = "widget.o: widget.h\n"

      includes = described_class.extract_includes( make_rules )

      expect( includes ).to eq( [] )
    end

    it 'extracts a single include from its own phony rule line' do
      make_rules = <<~MAKE
        widget.o: widget.h fstd_types.h
        fstd_types.h:
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.map(&:filepath) ).to eq( ['fstd_types.h'] )
    end

    it 'extracts multiple includes, each from its own phony rule line' do
      make_rules = <<~MAKE
        os.o: ../../src/app/task/os/os.h fstd_types.h FreeRTOS.h queue.h
        fstd_types.h:
        FreeRTOS.h:
        queue.h:
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.map(&:filepath) ).to eq( ['fstd_types.h', 'FreeRTOS.h', 'queue.h'] )
    end

    it 'deduplicates a phony rule line that appears more than once' do
      make_rules = <<~MAKE
        widget.o: widget.h fstd_types.h
        fstd_types.h:
        fstd_types.h:
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.map(&:filepath) ).to eq( ['fstd_types.h'] )
    end

    it 'extracts both .h and .c dependencies' do
      make_rules = <<~MAKE
        widget.o: widget.h helper.c
        helper.c:
        widget.h:
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.map(&:filepath) ).to eq( ['helper.c', 'widget.h'] )
    end

    it 'extracts a dependency with a relative directory path' do
      make_rules = <<~MAKE
        os.o: ../../src/app/task/os/os.h
        ../../src/app/task/os/os.h:
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.map(&:filepath) ).to eq( ['../../src/app/task/os/os.h'] )
    end

    it 'ignores trailing compiler error output after the phony rules' do
      make_rules = <<~MAKE
        os.o: ../../src/app/task/os/os.h stdbool.h
        stdbool.h:
        ../../src/app/task/os/os.h:72:21: error: no include path in which to search for stdbool.h
           72 | #include <stdbool.h>
              |                     ^
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.map(&:filepath) ).to eq( ['stdbool.h'] )
    end

    it 'returns an empty list for input with no phony rule lines at all' do
      includes = described_class.extract_includes( '' )

      expect( includes ).to eq( [] )
    end

    it 'returns plain Include objects, not a subclass' do
      make_rules = <<~MAKE
        widget.o: widget.h fstd_types.h
        fstd_types.h:
      MAKE

      includes = described_class.extract_includes( make_rules )

      expect( includes.first.class ).to eq( Include )
    end
  end
end
