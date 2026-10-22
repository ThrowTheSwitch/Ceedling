# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The text of a test file holding an ignored test for each function a header declares,
# for `module:test`.
#
# A new file follows the layout Unity's module generator gives a test file. An existing
# file keeps everything it has and gains tests only for functions it does not yet test.
# A function counts as tested by any `test_<function>` or `test_<function>_...` test,
# so a user's own descriptive test names count. New tests go ahead of the file's closing
# `#endif`, or at its end when it has none.
class ModuleGeneratorTestFile

  Result = Struct.new( :content, :added )

  def initialize(module_name:, header:, includes:, boilerplate:, test_define:, test_guard:)
    @module_name = module_name
    @header      = header
    @includes    = includes
    @boilerplate = boilerplate
    @test_define = test_define
    @test_guard  = test_guard
  end

  def render(functions, existing: nil)
    added = existing.nil? ? functions : functions.reject { |function| tested?( existing, function ) }
    tests = added.map { |function| test_for( function ) }.join

    return Result.new( existing.nil? ? new_file( tests ) : extend_file( existing, tests ), added )
  end

  private

  def tested?(content, function)
    return content.match?( /\bvoid\s+test_#{Regexp.escape( function )}(?:_\w*)?\s*\(/ )
  end

  def test_for(function)
    return "\nvoid test_#{function}_NeedToImplement(void)\n{\n    TEST_IGNORE_MESSAGE(\"Need to Implement #{function}\");\n}\n"
  end

  def new_file(tests)
    includes = (@includes + [@header]).map { |include| "#include \"#{include}\"\n" }.join

    return "#{boilerplate}##{@test_guard} #{@test_define}\n\n#include \"unity.h\"\n\n#{includes}\n" \
           "void setUp(void)\n{\n}\n\nvoid tearDown(void)\n{\n}\n#{tests}\n#endif // #{@test_define}\n"
  end

  def boilerplate
    return @boilerplate.to_s.empty? ? '' : "#{format( @boilerplate, @module_name )}\n"
  end

  # New tests go ahead of the last `#endif` and the blank line before it
  def extend_file(existing, tests)
    return existing if tests.empty?

    closing = existing.rindex( /^#endif\b/ )
    return existing + tests if closing.nil?

    head = existing[0...closing].chomp
    return "#{head}#{tests}\n#{existing[closing..]}"
  end

end
