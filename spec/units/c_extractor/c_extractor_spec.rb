# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_functions'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_preprocessing'
require 'ceedling/c_extractor/c_extractor_definitions'
require 'stringio'

##
## These unit tests exercise the CExtractor class's individual methods.
## A separate set of integration tests exercise the composition of all CExtractor* objects
## in extracting features from C source code.
##
describe CExtractor do

  ###
  ### setup() / default_max_buffer_length() -- :partials -> :max_extraction_length wiring
  ###
  describe "#setup (private method testing)" do
    # Helper to build a CExtractor with a given configurator double, without wiring the
    # other collaborators -- default_max_buffer_length only reads @configurator
    let(:build_extractor) do
      ->(configurator) do
        extractor = CExtractor.new(
          {
            c_extractor_code_text:     CExtractorCodeText.new,
            c_extractor_functions:     CExtractorFunctions.new({ c_extractor_code_text: CExtractorCodeText.new }),
            c_extractor_declarations:  CExtractorDeclarations.new({ c_extractor_code_text: CExtractorCodeText.new }),
            c_extractor_preprocessing: CExtractorPreprocessing.new({ c_extractor_code_text: CExtractorCodeText.new }),
            c_extractor_definitions:   CExtractorDefinitions.new({ c_extractor_code_text: CExtractorCodeText.new }),
            configurator:              configurator,
            loginator:                 double('Loginator').as_null_object,
            file_wrapper:              double('FileWrapper').as_null_object
          }
        )
        extractor.setup()
        extractor
      end
    end

    it "scales :partials_max_extraction_length by 1000 when the configurator provides it" do
      configurator = double('Configurator', partials_max_extraction_length: 7)
      extractor = build_extractor.call(configurator)

      expect(extractor.send(:default_max_buffer_length)).to eq(7000)
    end

    it "falls back to the built-in default when the configurator doesn't provide it" do
      # A bare double with no stub -- #respond_to? is false, exactly like direct/test
      # construction of this class where no real project configuration is available.
      configurator = double('Configurator')
      extractor = build_extractor.call(configurator)

      expect(extractor.send(:default_max_buffer_length)).to eq(CExtractorConstants::DEFAULT_MAX_FUNCTION_LENGTH)
    end

    it "setup() itself assigns @max_buffer_length from default_max_buffer_length" do
      configurator = double('Configurator', partials_max_extraction_length: 3)
      extractor = build_extractor.call(configurator)

      # @max_buffer_length has no reader; drive behavior through from_string, which raises
      # once the buffer set up by setup() is exceeded.
      expect {
        extractor.from_string(content: ('x' * 3001), chunk_size: 500)
      }.to raise_error(CeedlingException, /exceeded maximum length of 3000 characters/)
    end
  end

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

    # Helper to build a fully-wired CExtractor via DI
    let(:build_extractor) do
      ->() do
        code_text      = CExtractorCodeText.new
        declarations   = CExtractorDeclarations.new({ c_extractor_code_text: code_text })
        functions      = CExtractorFunctions.new({ c_extractor_code_text: code_text })
        preprocessing  = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })
        definitions    = CExtractorDefinitions.new({ c_extractor_code_text: code_text })
        declarations.setup()
        functions.setup()
        extractor = CExtractor.new(
          {
            c_extractor_code_text:    code_text,
            c_extractor_functions:    functions,
            c_extractor_declarations: declarations,
            c_extractor_preprocessing: preprocessing,
            c_extractor_definitions:  definitions,
            # Bare double (no :partials_max_extraction_length stub) so #respond_to? is
            # false and CExtractor falls back to its own built-in default buffer length.
            configurator:             double('Configurator'),
            loginator:                double('Loginator').as_null_object,
            file_wrapper:             double('FileWrapper').as_null_object
          }
        )
        extractor.setup()
        extractor
      end
    end

    # Helper to access private method — unwraps the [feature, start_pos] tuple and returns just the feature
    let(:extract_feature) do
      ->(io, max_length, extractor_lambda, chunk_size=10) do
        obj = build_extractor.call()
        obj.chunk_size = chunk_size
        feature, _start = obj.send(:extract_next_feature, io: io, max_length: max_length, extractor: extractor_lambda)
        feature
      end
    end

     context "basic extraction" do
      it "extracts a simple pattern within first chunk" do
        content = "HELLO // comment"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/HELLO/)
        
        result = extract_feature.call(io, 1000, extractor)
        
        expect(result).to eq("HELLO")
        # End of IO chunk + handling of possible trailing orphaned semicolon & deadspace
        expect(io.pos).to eq(10)
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

      it "does not skip preprocessor directives — they are features, not deadspace" do
        content = "#include <stdio.h>\n#define FOO 123\nPATTERN"
        io = StringIO.new(content)
        extractor = create_pattern_extractor.call(/PATTERN/)

        result = extract_feature.call(io, 1000, extractor)

        expect(result).to be_nil
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

        extractor_obj = build_extractor.call()
        extractor_obj.chunk_size = 2000

        result1, _ = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result2, _ = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result3, _ = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
        result4, _ = extractor_obj.send(:extract_next_feature, io: io, max_length: 1200, extractor: extractor)
               
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
        # End of IO chunk + handling of possible trailing orphaned semicolon & deadspace
        expect(io.pos).to eq(10)
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

      # try_extract_bare_macro_invocation's own success/failure decision depends on
      # peeking past the invocation's closing ')' for a terminating ';'/'{' -- if that
      # peek lands exactly at eos? because only THIS chunk has been read so far (not
      # because the real file has ended), it must fail and let extract_next_feature grow
      # the buffer and retry, never treat a mid-buffer eos? as "no terminator follows."
      # Round-tripped through the real extract_next_feature (not called directly) so
      # this exercises the real growth-and-retry behavior the fix depends on.
      it "does not falsely succeed when a bare invocation's terminator would only appear in the next chunk" do
        code_text     = CExtractorCodeText.new
        preprocessing = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })

        # chunk_size=10: "FOO(0123)" is exactly 10 characters, so the first chunk read
        # ends precisely at the invocation's closing ')' -- the very next character (a
        # real terminating ';', making this NOT a bare invocation) only exists once a
        # second chunk is read.
        content = "FOO(0123);"
        io = StringIO.new(content)

        obj = build_extractor.call()
        obj.chunk_size = 10
        feature, _start = obj.send(
          :extract_next_feature, io: io, max_length: 1000,
          extractor: preprocessing.method(:try_extract_bare_macro_invocation)
        )

        expect(feature).to be_nil
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

  ###
  ### extract_contents() -- dispatch priority, termination, and cleanup
  ###
  ### extract_contents' own end-to-end dispatch correctness for every real construct
  ### type, and element_sequence ordering, is already exhaustively proven with real
  ### parsing by spec/integration/c_extractor_composition_spec.rb. These tests are
  ### scoped narrowly to ordering/termination/cleanup behavior that a mocked-collaborator
  ### test can isolate but a real-parsing test structurally can't (real C syntax is
  ### rarely ambiguous between two constructs at the same position).
  ###
  describe "#extract_contents (private method testing)" do
    # Helper to build a fully-wired CExtractor via DI, returning both the extractor and
    # its individual real collaborators so tests can stub one collaborator's method while
    # leaving the rest of the graph real -- mirrors #extract_next_feature's own
    # build_extractor helper above.
    let(:build_extractor) do
      ->() do
        code_text      = CExtractorCodeText.new
        declarations   = CExtractorDeclarations.new({ c_extractor_code_text: code_text })
        functions      = CExtractorFunctions.new({ c_extractor_code_text: code_text })
        preprocessing  = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })
        definitions    = CExtractorDefinitions.new({ c_extractor_code_text: code_text })
        declarations.setup()
        functions.setup()
        extractor = CExtractor.new(
          {
            c_extractor_code_text:    code_text,
            c_extractor_functions:    functions,
            c_extractor_declarations: declarations,
            c_extractor_preprocessing: preprocessing,
            c_extractor_definitions:  definitions,
            configurator:             double('Configurator'),
            loginator:                double('Loginator').as_null_object,
            file_wrapper:             double('FileWrapper').as_null_object
          }
        )
        extractor.setup()
        {
          extractor:     extractor,
          preprocessing: preprocessing,
          definitions:   definitions,
          functions:     functions,
          declarations:  declarations
        }
      end
    end

    it "tries directive extraction before typedef extraction at the same position" do
      built = build_extractor.call()

      allow(built[:preprocessing]).to receive(:try_extract_directive) do |scanner|
        scanner.terminate
        [true, "#define X 1"]
      end
      expect(built[:definitions]).not_to receive(:try_extract_typedef)

      io = StringIO.new("TOKEN")
      result = built[:extractor].send(:extract_contents, io, nil)

      expect(result).to be_a(CExtractorTypes::CModule)
      expect(result.macro_definitions.length).to eq(1)
    end

    it "tries typedef extraction before static-assert extraction at the same position" do
      built = build_extractor.call()

      allow(built[:definitions]).to receive(:try_extract_typedef) do |scanner|
        scanner.terminate
        [true, "typedef int foo_t;"]
      end
      expect(built[:preprocessing]).not_to receive(:try_extract_static_assert)

      io = StringIO.new("TOKEN")
      result = built[:extractor].send(:extract_contents, io, nil)

      expect(result.type_definitions.length).to eq(1)
    end

    it "tries bare-macro-invocation extraction before function-definition extraction at the same position" do
      built = build_extractor.call()

      allow(built[:preprocessing]).to receive(:try_extract_bare_macro_invocation) do |scanner|
        scanner.terminate
        [true, CExtractorTypes::CStatement.new(text: "FOO(0)")]
      end
      expect(built[:functions]).not_to receive(:try_extract_function_definition)

      io = StringIO.new("TOKEN")
      result = built[:extractor].send(:extract_contents, io, nil)

      expect(result.macro_invocations.length).to eq(1)
    end

    it "breaks out of the loop and returns the accumulated CModule when no extractor succeeds anywhere" do
      built = build_extractor.call()

      # None of the six extractors recognize this content at all (no leading '#',
      # no keyword, no identifier characters), so every one of them fails and the
      # loop must break rather than looping forever or raising.
      io = StringIO.new("@@@")
      result = built[:extractor].send(:extract_contents, io, nil)

      expect(result).to be_a(CExtractorTypes::CModule)
      expect(result.function_definitions).to eq([])
      expect(result.function_declarations).to eq([])
      expect(result.variable_declarations).to eq([])
      expect(result.macro_definitions).to eq([])
      expect(result.type_definitions).to eq([])
      expect(result.aggregate_definitions).to eq([])
      expect(result.macro_invocations).to eq([])
      expect(result.element_sequence).to eq([])
    end

    it "closes the IO via ensure even when a collaborator raises mid-loop" do
      built = build_extractor.call()
      allow(built[:preprocessing]).to receive(:try_extract_directive).and_raise(StandardError, "boom")

      io = StringIO.new("TOKEN")

      expect {
        built[:extractor].send(:extract_contents, io, nil)
      }.to raise_error(StandardError, "boom")

      expect(io.closed?).to be true
    end
  end

  ###
  ### _compute_line_info()
  ###
  describe "#_compute_line_info (private method testing)" do
    let(:extractor) do
      CExtractor.new(
        {
          c_extractor_code_text:     CExtractorCodeText.new,
          c_extractor_functions:     CExtractorFunctions.new({ c_extractor_code_text: CExtractorCodeText.new }),
          c_extractor_declarations:  CExtractorDeclarations.new({ c_extractor_code_text: CExtractorCodeText.new }),
          c_extractor_preprocessing: CExtractorPreprocessing.new({ c_extractor_code_text: CExtractorCodeText.new }),
          c_extractor_definitions:   CExtractorDefinitions.new({ c_extractor_code_text: CExtractorCodeText.new }),
          configurator:              double('Configurator'),
          loginator:                 double('Loginator').as_null_object,
          file_wrapper:              double('FileWrapper').as_null_object
        }
      ).tap { |e| e.setup() }
    end

    it "reports line 1 when nothing consumed contains a newline" do
      io = StringIO.new("int x; int y;")
      io.seek(7) # positioned right after "int x; "

      line, cumulative = extractor.send(:_compute_line_info, io, 0, 7, 0)

      expect(line).to eq(1)
      expect(cumulative).to eq(0)
    end

    it "advances the line number when newlines precede the feature start" do
      io = StringIO.new("int x;\nint y;\nint z;")
      io.seek(14) # positioned right after the second line

      line, cumulative = extractor.send(:_compute_line_info, io, 0, 14, 0)

      expect(line).to eq(3)
      expect(cumulative).to eq(2)
    end

    it "does not count newlines consumed after the feature start toward this call's reported line" do
      io = StringIO.new("int x;\nint y;\n")
      io.seek(14)

      # feature_start (0) is before any newline, but the call consumed through both lines --
      # this call's own reported line must reflect only the gap up to feature_start, while
      # the returned cumulative count reflects everything actually consumed.
      line, cumulative = extractor.send(:_compute_line_info, io, 0, 0, 0)

      expect(line).to eq(1)
      expect(cumulative).to eq(2)
    end

    it "handles a zero-length gap where the feature starts exactly at call_start" do
      io = StringIO.new("int x;\nint y;")
      io.seek(7)

      line, cumulative = extractor.send(:_compute_line_info, io, 7, 7, 3)

      expect(line).to eq(4)
      expect(cumulative).to eq(3)
    end

    it "adds newly consumed newlines on top of a nonzero starting cumulative count" do
      io = StringIO.new("first\nsecond\nthird")
      io.seek(13) # after "first\nsecond\n"

      line, cumulative = extractor.send(:_compute_line_info, io, 0, 13, 5)

      expect(line).to eq(8)
      expect(cumulative).to eq(7)
    end
  end

end