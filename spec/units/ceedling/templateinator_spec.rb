# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/templateinator'

# Templateinator compiles Ceedling's report templates. It replaced ERB, so these
# examples pin the template language itself rather than any one template. Every
# expected value here was taken from real ERB 2.2.0 output before ERB was removed.
#
# Everything is strings in and strings out. Templateinator has no collaborators and
# touches no IO. The real templates are covered byte for byte against captured ERB
# output by templateinator_golden_spec.rb.
describe Templateinator do
  before(:each) do
    @templateinator = described_class.new
  end

  def render(template)
    return @templateinator.render( template, binding )
  end

  describe 'percent lines' do
    # ERB accepted a percent only in column zero and allowed any whitespace after
    # it. Ceedling's own templates indent heavily to show nesting, so stripping the
    # percent alone, rather than a percent and a space, is load bearing.
    it 'treats an indented percent line as Ruby' do
      expect(render( "%   [1,2].each do |i|\n- <%=i%>\n%   end\n" )).to eq( "- 1\n- 2\n" )
    end

    it 'treats a Ruby comment on a percent line as code, emitting nothing' do
      expect(render( "% # a comment\nx\n" )).to eq( "x\n" )
    end

    # One shared scope across the whole template, including across block
    # boundaries, is what lets a template compute a value once and use it later.
    it 'shares locals between percent lines and later output tags' do
      expect(render( "% prefix = 'hi'\n%[1,2].each do |i|\n- <%=prefix%><%=i%>\n%end\n" )).to eq( "- hi1\n- hi2\n" )
    end

    it 'emits one literal percent for a doubled percent at column zero' do
      expect(render( "%% literal\n" )).to eq( "% literal\n" )
    end
  end

  describe 'output tags' do
    it 'substitutes an expression' do
      expect(render( "value: <%= 1 + 1 %>\n" )).to eq( "value: 2\n" )
    end

    it 'converts a non-string expression with to_s' do
      expect(render( "value <%= :sym %>\n" )).to eq( "value sym\n" )
    end

    it 'emits nothing for a comment tag' do
      expect(render( "a<%# ignored %>b\n" )).to eq( "ab\n" )
    end

    it 'executes a bare code tag without emitting it' do
      expect(render( "a<% 1 + 1 %>b\n" )).to eq( "ab\n" )
    end

    it 'handles several tags on one line' do
      expect(render( "x<%=1%> and <%=2%>\n" )).to eq( "x1 and 2\n" )
    end

    # The bullseye template ends its coverage lines with a literal percent sign.
    # Only a percent in column zero is special.
    it 'leaves a percent elsewhere on the line as literal text' do
      expect(render( "50% done\nBRANCHES: <%=7%>%\n" )).to eq( "50% done\nBRANCHES: 7%\n" )
    end

    # The default template uses a tag whose whole purpose is emitting a newline.
    it 'emits a newline from a tag that produces one' do
      expect(render( 'a' + "\n" + '<%="\n"%>' + "\n" + 'b' + "\n" )).to eq( "a\n\nb\n" )
    end
  end

  describe 'newline trimming' do
    # A line whose first tag opens it and whose last tag closes it contributes no
    # newline of its own. Text in the middle does not matter, only the two ends.
    # Ceedling's templates depend on this to control blank lines in reports.
    it 'drops the newline when the line both opens and closes with a tag' do
      expect(render( "<%=1%>\n<%=2%>\n" )).to eq( "12" )
    end

    it 'drops the newline even when text sits between the opening and closing tags' do
      expect(render( "<%=1%> and <%=2%>\nrest\n" )).to eq( "1 and 2rest\n" )
    end

    it 'keeps the newline when text follows the last tag' do
      expect(render( "<%=1%>x\n" )).to eq( "1x\n" )
    end

    it 'keeps the newline when text precedes the first tag' do
      expect(render( "x<%=1%>\n" )).to eq( "x1\n" )
    end

    it 'preserves a blank line' do
      expect(render( "a\n\nb\n" )).to eq( "a\n\nb\n" )
    end
  end

  describe 'line endings' do
    # ERB emitted a bare newline after a tag-terminated line rather than echoing the
    # carriage return it matched, while leaving a plain line's own ending alone.
    # Reproduced so a template checked out with Windows line endings renders
    # identically to one checked out with Unix endings.
    it 'normalizes a carriage return on a tag-terminated line but not on a plain line' do
      expect(render( "a\r\nb <%=1%>\r\n<%=2%>\r\n" )).to eq( "a\r\nb 1\n2" )
    end

    it 'does not invent a trailing newline where the template has none' do
      expect(render( "a\nb" )).to eq( "a\nb" )
      expect(render( "% x = 1\n<%=x%>" )).to eq( "1" )
    end
  end

  describe 'malformed templates' do
    # ERB treated an unterminated tag as though the rest of the template were Ruby
    # and silently produced garbage rather than failing. A template author is better
    # served by an error naming the line.
    it 'raises naming the line number for an unterminated tag' do
      expect {
        render( "fine\nalso fine\nbroken <% oops\n" )
      }.to raise_error( CeedlingException, /line 3/ )
    end

    # ERB accepted a tag spanning lines. Ceedling's own templates contain none, and
    # the documented template language is one tag per line, so this is refused
    # rather than silently supported.
    it 'raises for a tag spanning multiple lines' do
      expect {
        render( "<%= 1 +\n 1 %>\n" )
      }.to raise_error( CeedlingException, /line 1/ )
    end
  end

  describe 'error reporting' do
    # A template error has to point at the template line that caused it, otherwise a
    # plugin author has nothing to go on.
    it 'reports a Ruby syntax error against the template' do
      expect {
        render( "a\nb\n% if true\n" )
      }.to raise_error( SyntaxError, /\(ceedling template\)/ )
    end

    it 'reports an undefined reference against the template line' do
      expect {
        render( "line one\nline two\n<%=nope%>\n" )
      }.to raise_error( NameError, /\(ceedling template\):3/ )
    end
  end

  describe 'evaluation context' do
    it 'evaluates against the binding it is given' do
      caller_local = 'from the caller'
      expect(@templateinator.render( "<%=caller_local%>\n", binding )).to eq( "from the caller\n" )
    end

    # Proves the template is evaluated in the caller's scope rather than inside
    # Templateinator, where render's own parameter name would resolve.
    it 'does not expose its own locals to the template' do
      expect {
        @templateinator.render( "<%=context_binding%>\n", binding )
      }.to raise_error( NameError, /context_binding/ )
    end
  end
end
