#include "tally.h"
int tally(void) {
  static struct {
    int count;
  } state;  // A type and its variable, promoted together from three lines

  state.count++;  // Must independently report as hit

  return state.count;  // Must independently report as hit
}

// Lines 6 and 8 above are deliberately blank; they must never absorb the hits
// that belong to lines 7 and 9; see gcov_partials_coverage_promoted_type.
