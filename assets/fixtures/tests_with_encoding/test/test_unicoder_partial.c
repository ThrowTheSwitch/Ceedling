/* =========================================================================
 * Partials Test — © 2024 Ünïcödé Corp. Tous droits réservés.
 * Tests unicoder module directly via Ceedling Partials (no mock).
 * unicoder.c is compiled into this test build as a partial module,
 * exercising Ceedling's encoding-safe partial source preprocessing path.
 * ========================================================================= */

#include "unity.h"
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(unicoder)

/* Verify that the real unicoder_greet() returns the expected value — no mock. */
void test_unicoder_greet_is_five_via_partials(void)
{
    TEST_ASSERT_EQUAL(5, unicoder_greet());
}
