# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partials'

describe Partials::Rename do
  describe ".identifiers" do
    it "replaces a single token-bounded occurrence" do
      result = Partials::Rename.identifiers("count = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count = 0;")
    end

    it "replaces all occurrences throughout the text (gsub)" do
      result = Partials::Rename.identifiers("count = count + 1;", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count = partial_foo_count + 1;")
    end

    it "does not replace left-bounded substrings" do
      result = Partials::Rename.identifiers("recount = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("recount = 0;")
    end

    it "does not replace right-bounded substrings" do
      result = Partials::Rename.identifiers("count_down = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("count_down = 0;")
    end

    it "does not replace interior substrings" do
      result = Partials::Rename.identifiers("recount_down = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("recount_down = 0;")
    end

    it "replaces identifier in parentheses context" do
      result = Partials::Rename.identifiers("foo(count)", { "count" => "partial_foo_count" })
      expect(result).to eq("foo(partial_foo_count)")
    end

    it "replaces pointer dereference context" do
      result = Partials::Rename.identifiers("*count = 0;", { "count" => "partial_foo_count" })
      expect(result).to eq("*partial_foo_count = 0;")
    end

    it "replaces array subscript context" do
      result = Partials::Rename.identifiers("count[0]", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count[0]")
    end

    it "replaces comparison context without spaces" do
      result = Partials::Rename.identifiers("count==5", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count==5")
    end

    it "replaces compound assignment without spaces" do
      result = Partials::Rename.identifiers("count+=1", { "count" => "partial_foo_count" })
      expect(result).to eq("partial_foo_count+=1")
    end

    it "replaces address-of context" do
      result = Partials::Rename.identifiers("&count", { "count" => "partial_foo_count" })
      expect(result).to eq("&partial_foo_count")
    end

    it "returns empty string unchanged" do
      result = Partials::Rename.identifiers("", { "count" => "partial_foo_count" })
      expect(result).to eq("")
    end

    it "returns unchanged text when old_name not present" do
      text   = "value = 5;"
      result = Partials::Rename.identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq(text)
    end

    # A literal's text is data the program uses, and a comment's is prose
    it "leaves the name alone inside a string literal, a character literal or a comment" do
      text   = "printf(\"count=%d\", count); c = 'count'; /* count */ // count\ncount++;"
      result = Partials::Rename.identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq("printf(\"count=%d\", partial_foo_count); c = 'count'; /* count */ // count\npartial_foo_count++;")
    end

    # A member and a tag live apart from variables, so they keep a name a variable shares
    it "leaves a member or a tag that shares the name alone" do
      text   = "struct count *p = &count; p->count = s.count; union count u; enum count e; f(.count = count);"
      result = Partials::Rename.identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq("struct count *p = &partial_foo_count; p->count = s.count; union count u; enum count e; f(.count = partial_foo_count);")
    end

    # C23 digit separators would otherwise open a character literal
    it "renames past a number written with digit separators" do
      result = Partials::Rename.identifiers("m = 1'000 + count + 2'000;", { "count" => "partial_foo_count" })
      expect(result).to eq("m = 1'000 + partial_foo_count + 2'000;")
    end

    # An asm template refers to a named operand inside its string, and the name must follow
    it "renames an asm template's references to an operand named after the variable" do
      text   = '__asm__ volatile ("mov %[count], %w[count]" : [count] "+r" (count));'
      result = Partials::Rename.identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq('__asm__ volatile ("mov %[partial_foo_count], %w[partial_foo_count]" : [partial_foo_count] "+r" (partial_foo_count));')
    end

    # A body in the function is local to it, so a name it holds is renamed everywhere, member
    # access included, and its members and their uses keep agreeing. That holds for a member
    # declared any way and for a name the body only uses.
    it "renames a name a local struct or union body holds everywhere, member access included" do
      text   = "struct { int count; } s = {0}; union u { int count; } v; struct lc { int count; } t = { .count = count }; s.count = ++count; p->count = 1;"
      result = Partials::Rename.identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq("struct { int partial_foo_count; } s = {0}; union u { int partial_foo_count; } v; struct lc { int partial_foo_count; } t = { .partial_foo_count = partial_foo_count }; s.partial_foo_count = ++partial_foo_count; p->partial_foo_count = 1;")
    end

    it "finds the names a body holds past attributes, function-pointer members and braces in comments" do
      renames = { "hist" => "partial_foo_hist", "handler" => "partial_foo_handler", "size" => "partial_foo_size" }
      text    = "struct __attribute__((packed)) tag { char c[sizeof(hist[0])]; void (*handler)(void); /* { */ char q[sizeof(\"}\")]; } s; s.handler = handler; x.size = size;"
      result  = Partials::Rename.identifiers(text, renames)
      expect(result).to eq("struct __attribute__((packed)) tag { char c[sizeof(partial_foo_hist[0])]; void (*partial_foo_handler)(void); /* { */ char q[sizeof(\"}\")]; } s; s.partial_foo_handler = partial_foo_handler; x.size = partial_foo_size;")
    end

    # A macro may open an asm template, so its string is recognized by the reference alone
    it "renames an operand reference in a template a macro opens" do
      text   = '__asm__ __volatile__( LOCK_PREFIX "incl %[count]" : [count] "+m" (count) );'
      result = Partials::Rename.identifiers(text, { "count" => "partial_foo_count" })
      expect(result).to eq('__asm__ __volatile__( LOCK_PREFIX "incl %[partial_foo_count]" : [partial_foo_count] "+m" (partial_foo_count) );')
    end

    # A head may hold a C23 attribute, a macro or a comment ahead of the body's brace
    it "finds a body past a C23 attribute, a macro or a comment in its head" do
      text   = "struct [[gnu::packed]] { int a; } x; struct PACKED_ALIGN(4) { int b; } y; struct /* wire */ { int c; } z; x.a = a; y.b = b; z.c = c;"
      result = Partials::Rename.identifiers(text, { "a" => "p_a", "b" => "p_b", "c" => "p_c" })
      expect(result).to eq("struct [[gnu::packed]] { int p_a; } x; struct PACKED_ALIGN(4) { int p_b; } y; struct /* wire */ { int p_c; } z; x.p_a = p_a; y.p_b = p_b; z.p_c = p_c;")
    end

    it "renames every name it maps in one pass" do
      result = Partials::Rename.identifiers("a = b + ab;", { "a" => "x_a", "b" => "x_b" })
      expect(result).to eq("x_a = x_b + ab;")
    end
  end

  # Promotion renames each statement's text and the function around it apart, so it hands the
  # rename the names its local bodies hold and the tags it renames
  describe ".identifiers with names and tags given" do
    it "renames a member a body elsewhere holds" do
      result = Partials::Rename.identifiers( "s.count = 1;", { "count" => "partial_f_count" }, shared: Set["count"] )
      expect( result ).to eq( "s.partial_f_count = 1;" )
    end

    it "renames a tag it's given, wherever the tag is used" do
      result = Partials::Rename.identifiers( "struct st *p = &st;", { "st" => "partial_f_st" }, tags: { "st" => "ceedling_partial_m_f_st_t" } )
      expect( result ).to eq( "struct ceedling_partial_m_f_st_t *p = &partial_f_st;" )
    end

    it "leaves a member that shares a renamed tag's name alone" do
      result = Partials::Rename.identifiers( "p->st = 0;", {}, tags: { "st" => "ceedling_partial_m_f_st_t" } )
      expect( result ).to eq( "p->st = 0;" )
    end
  end
end
