# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/file_wrapper'

# Writes one of a Partial's generated headers one item at a time.
#
# GeneratorPartials decides what each item is. The writer keeps the state that spans items: the
# blank lines around functions and the source's later includes, which go where the module
# header's items end. Every generated header opens and closes the same way, so the writer owns
# both ends.
class PartialHeaderWriter

  # @param io   [IO]     Output file handle
  # @param name [String] The header's filename, from which its own include guard comes
  def initialize(io:, name:)
    @io     = io
    @guard  = FileWrapper.generate_include_guard( name )
    @written           = false
    @last_was_function = false
  end

  # Everything above the header's own content: its include guard, the spoof of the real module
  # header's guard, and the includes that header carries.
  #
  # The order of the last two is the whole point. A carried header can transitively reach the
  # real module header, so the spoof has to be satisfied before any include is processed rather
  # than after. And relocated content names things a generated file does not define, so without
  # the includes it compiles only where something earlier in the translation unit happened to
  # supply those names.
  #
  # @param include_guard [String, nil] The real module header's own guard, or nil when it has none
  #   and so supplies nothing to spoof
  # @param includes      [Array]       The includes ahead of the header's content
  def preamble(include_guard, includes)
    @io << "#ifndef #{@guard}\n"
    @io << "#define #{@guard}\n\n"
    @io << "#define #{include_guard}\n\n" if include_guard
    return if includes.empty?

    includes.each { |include| @io << "#{include}\n" }
    @io << "\n"
  end

  # A line of content that is no function, such as a macro, a type or an extern
  def line(text)
    @io << text << "\n"
    _wrote( function: false )
  end

  # A function's signature, set apart from what precedes it by a blank line
  def function(signature)
    @io << "\n" if @written and !@last_was_function
    @io << signature << ";\n\n"
    _wrote( function: true )
  end

  # The source's includes after the module header, written where the header's items end, as the
  # source meets them when it compiles. The spoof keeps the real header out, so these includes
  # find its types and macros only in what a generated header writes ahead of them. `macros` are
  # header macros held back until the includes, which come first. Both lists are consumed, so
  # only the first call with includes writes anything.
  def following_includes(includes, macros: [])
    return if includes.empty?

    macros.each { |macro| @io << "#{macro.text}\n" }
    @io << "\n" if (@written and !@last_was_function) or macros.any?
    includes.each { |include| @io << "#{include}\n" }
    @io << "\n"
    macros.clear
    includes.clear
    # The includes end in a blank line, as a function does
    _wrote( function: true )
  end

  # A blank line before the guard's close when the last item didn't already end in one
  def finish
    @io << "\n" if @written and !@last_was_function
    @io << "#endif // #{@guard}\n\n"
  end

  private

  def _wrote(function:)
    @last_was_function = function
    @written           = true
  end
end
