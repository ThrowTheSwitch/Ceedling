#include "counter.h"
int helloCounter(void) {
  static int count;  // Promoted to module scope and replaced with a no-op by Partials

  count++;  // Must independently report as hit

  return count;  // Must independently report as hit
}

// Lines 4 and 6 above are deliberately blank; they must never absorb the
// hits that belong to `count++;` (line 5) and `return count;` (line 7);
// see gcov_partials_coverage_function_scope_static_promotion.
