// No corresponding header -- deliberately, so this file can only ever enter a
// test's compile/link list via a positive TEST_SOURCE_FILE() entry, never by
// the implicit header/source convention. Its own basename ("dup_gamma") also
// shares no stem with "dup", so referencing it never engages TEST_SOURCE_FILE()'s
// basename-stem override mechanism either.
int dup_value(void) { return 333; }
