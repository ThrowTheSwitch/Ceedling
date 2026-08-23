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

  /* Regression coverage for a compound `#if defined(A) && defined(B)` condition
   * in fallback mode. NEVER_DEFINED_FEATURE is never defined by any test config
   * for this fixture. A misparse that evaluates only the first macro name (A)
   * instead of falling through to the conservative "complex expression ->
   * active" treatment would read this line as `defined(NEVER_DEFINED_FEATURE)`
   * alone -- always false -- and wrongly exclude this call from the partial. */
#if defined(NEVER_DEFINED_FEATURE) && defined(CONDITIONAL_FEATURE)
  OptionalDep_DoWork();
#endif
#endif
}
