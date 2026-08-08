#include "decorators.h"
static  // Own line -- exercises the Partials #line adjustment for stripped decorators
inline  // Own line -- same as above
void helloDecorators(void)
{

  return;  // Must be the reported hit line
}

// Line 6 above is deliberately blank; it must never absorb the hit that
// belongs to `return` on line 7; see gcov_partials_coverage_decorators_on_own_lines.
