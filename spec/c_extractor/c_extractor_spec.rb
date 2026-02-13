# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor'
require 'stringio'

##
## These unit tests exercise the CExtractor class's individual methods.
## A separate set of integration tests exercise the composition of all CExtractor* objects
## in extracting features from C source code.
##
describe CExtractor do

  ###
  ### extract_next_feature()
  ###
  describe "#extract_next_feature (private method testing)" do
    # Helper to create a simple extractor that looks for a specific pattern
    # NOTE: `scanner.scan()` expects pattern to match from the current position
    let(:create_pattern_extractor) do
      ->(pattern) do
        ->(scanner) do
          if scanner.scan(pattern)
            matched = scanner.matched
            return [true, matched]
          end
          return [false, nil]
        end
      end
    end

    # Helper to access private method
    let(:extract_feature) do
      ->(io, max_length, extractor, chunk_size=10) do
        extractor_obj = CExtractor.from_string(content: "", chunk_size: chunk_size)
        extractor_obj.send(:extract_next_feature, io: io, max_length: max_length, extractor: extractor)
      end
    end

     context "basic extraction" do
      it "extracts a simple pattern within first chunk" do
        content = "HELLO // comment"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/HELLO/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("HELLO")
        expect(io.pos).to eq(5) # Position after "HELLO"
      end

      it "returns nil when pattern is not found before EOF" do
        content = "// no content in these chunks"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/NOTFOUND/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to be_nil
        expect(io.pos).to eq(0)
      end

      it "advances scanner position on success" do
        content = "PREFIX:DATA:SUFFIX"
        io = StringIO.new(content)
        
        extractor = ->(scanner) do
          # Look for pattern like "PREFIX:DATA:"
          if scanner.scan(/PREFIX:(\w+):/)
            return [true, scanner[1]] # Return just the captured DATA part
          end
          [false, nil]
        end
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("DATA")
        expect(io.pos).to eq(12) # After "PREFIX:DATA:"
      end    end

    context "multiple extractions" do
      it "extracts multiple features sequentially from same IO" do
        content = "FIRST SECOND THIRD"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w+/)
        
        result1 = extract_feature.call(io, 1000, extractor)
        result2 = extract_feature.call(io, 1000, extractor)
        result3 = extract_feature.call(io, 1000, extractor)
        result4 = extract_feature.call(io, 1000, extractor)
        
        expect(result1).to eq("FIRST")
        expect(result2).to eq("SECOND")
        expect(result3).to eq("THIRD")
        expect(result4).to be_nil
      end

      it "positions IO correctly after each extraction" do
        content = "AAA BBB CCC"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w+/)
        
        extract_feature.call(io, 1000, extractor)
        pos_after_first = io.pos
        
        extract_feature.call(io, 1000, extractor)
        pos_after_second = io.pos
        
        expect(pos_after_first).to eq(3) # After "AAA"
        expect(pos_after_second).to eq(7) # After "AAA BBB"
      end
    end

    context "whitespace and deadspace handling" do
      it "skips whitespace before pattern" do
        content = "   \n\t  PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end

      it "skips comments before pattern" do
        content = "// comment\n/* block */PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end

      it "skips preprocessor directives before pattern" do
        content = "#include <stdio.h>\n#define FOO 123\nPATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end
    end

    context "IO access and buffer usage" do
      it "extracts pattern that spans multiple chunks" do
        content = "/*pre*/ LOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOONG_PATTERN /*post*/"
        io = StringIO.new(content)
        # Chunk size is 10, so "LONG_PATTERN" will span chunks
        extractor = create_pattern_extractor.call(/L(O)+NG_PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("LOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOONG_PATTERN")
      end

      it "grows buffer across many chunks until pattern is found" do
        # Create content where pattern appears after several chunks
        content = "\t" * 100 + "TARGET"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/TARGET/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("TARGET")
      end

      it "raises error when buffer exceeds max_length" do
        content = "x" * 200 # Long string
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/NOTFOUND/)
        
        expect {
          extract_feature.call(io, 100, extractor)
        }.to raise_error(CeedlingException, /exceeded maximum length/)
      end

      it "extracts multiple features from same chunk" do
        # Other test cases deal with growing the internal buffer with multiple chunk reads from IO.
        # This test case ensures we can extract multiple features from the same large chunk.

        content = "FIRST" + (' ' * 500) + "SECOND" + (' ' * 500) + "THIRD"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w+/)

        extractor_obj = CExtractor.from_string(content: "", chunk_size: 2000)

        result1 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result2 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result3 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result4 = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
               
        expect(result1).to eq("FIRST")
        expect(result2).to eq("SECOND")
        expect(result3).to eq("THIRD")
        expect(result4).to be_nil
      end
    end

    context "edge cases" do
      it "handles empty IO" do
        io = StringIO.new("")
        extractor = create_pattern_extractor.call(/ANYTHING/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to be_nil
      end

      it "handles IO with only whitespace and comments" do
        content = "   \n\t  // comment\n/* block */  \n"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to be_nil
      end

      it "handles pattern at very end of IO" do
        content = "/*prefix*/ PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
        expect(io.eof?).to be true
      end

      it "handles pattern at very beginning of IO" do
        content = "PATTERN /*suffix*/"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
        expect(io.pos).to eq(7)
      end

      it "allows extraction when pattern exactly matches chunk size" do
        content = "FOUND"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/FOUND/)
        
        result = extract_feature.call(io, 100, extractor, 5)
        
        expect(result).to eq("FOUND")
      end

      it "allows extraction when exactly at max_length" do
        content = "\n" * 95 + "FOUND" # 100 characters
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/FOUND/)
        
        result = extract_feature.call(io, 100, extractor)
        
        expect(result).to eq("FOUND")
      end

      it "handles pattern split exactly at chunk boundary" do
        # With chunk_size=10, "/*012345*/" fills first chunk exactly
        content = "/*012345*/PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end

      it "handles comment spanning chunk boundaries" do
        content = "/* comment across\nchunk boundary */PATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("PATTERN")
      end
    end

    context "performance and safety" do
      it "stops reading when max_length is reached" do
        # Create content larger than max_length
        large_content = "x" * 500
        io = StringIO.new(large_content)
        extractor = create_pattern_extractor.call(/NOTFOUND/)
        
        expect {
          extract_feature.call(io, 200, extractor)
        }.to raise_error(CeedlingException, /exceeded maximum length/)
        
        # IO should not have read entire content
        expect(io.pos).to be < large_content.length
      end

      it "handles rapid successive extractions" do
        content = "A B C D E F G H I J"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/\w/)
        
        results = []
        10.times do
          result = extract_feature.call(io, 1000, extractor)
          break unless result
          results << result
        end
        
        expect(results).to eq(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"])
      end
    end
  end

end