/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Reproduces issue #1223: a conditional #include guarded by a macro defined
 * in an EARLIER #include in this same file (as opposed to a project :defines
 * macro or a same-file #define, both of which already work correctly -- see
 * widget.c). Ceedling's bare-includes extraction pass runs against an
 * isolated, sibling-free copy of this file and so never actually opens
 * feature_config.h to learn FEATURE_LEVEL's value, evaluating the #if below
 * as false and silently dropping feature_extra.h from the generated Partial
 * even though FEATURE_LEVEL is genuinely > 1. */

#include "widget_feature.h"
#include "feature_config.h"     /* defines FEATURE_LEVEL (2) */

#if FEATURE_LEVEL > 1
#include "feature_extra.h"      /* defines FEATURE_EXTRA_MACRO */
#endif

/* Same sibling-header-macro guard as above, but the target is a macro
 * invocation (issue #1267) split across a backslash continuation rather than
 * a literal filename. GCC's -fdirectives-only attributes a consumed
 * multi-line directive's own entering marker to its LAST physical line, not
 * its first -- proves the computed-include correlation fix reaches a real
 * Partials build for a multi-physical-line directive, not just the
 * single-line shape already covered at the integration tier. */
#define WF_STR2(x) #x
#define WF_STR(x) WF_STR2(x)
#define WF_PICK(name) WF_STR(name.h)

#if FEATURE_LEVEL > 1
#include \
  WF_PICK(feature_extra2)      /* defines FEATURE_EXTRA2_MACRO */
#endif

static int WidgetFeature__FromFeatureLevel(void)
{
    return FEATURE_EXTRA_MACRO + FEATURE_EXTRA2_MACRO;
}

int WidgetFeature_FromFeatureLevel(void) { return WidgetFeature__FromFeatureLevel(); }
