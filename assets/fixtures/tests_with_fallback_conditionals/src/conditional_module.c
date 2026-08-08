/* =========================================================================
 * Conditional Module implementation — © 2024 résumé.
 * ========================================================================= */

#include "conditional_module.h"

/* Include optional dependency only when feature enabled — naïve guard. */
#ifdef CONDITIONAL_FEATURE
#include "optional_dep.h"
#endif

void ConditionalModule_Init(void)
{
  /* Call optional dep only when feature active — Ünïcödé-safe comment. */
#ifdef CONDITIONAL_FEATURE
  OptionalDep_DoWork();
#endif
}
