#include "blanks.h"
void helloBlanks(void) {


  return;  // Must be the reported hit line -- the whole point of this fixture
}

// Lines 3-4 above are deliberately blank -- standing in for a stripped
// multi-line comment. They must never absorb the hit that belongs to
// `return` on line 5; see gcov_partials_coverage_blank_lines_in_function_body.
