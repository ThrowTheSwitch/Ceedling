/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "widget.h"

/* (a) Conditional include gated on a project-level :defines macro. */
#ifdef PROJECT_FLAG
#include "project_flag_extra.h"
#endif

#define LOCAL_FLAG (1)

/* (b) Conditional include gated on a macro #define'd earlier in this same file. */
#if LOCAL_FLAG
#include "local_flag_extra.h"
#endif

/* (c) Reached only transitively, via nested_wrapper.h's own #include -- never
 * itself named directly by this file. Must not appear as a duplicate,
 * spuriously-promoted top-level #include in generated output. */
#include "nested_wrapper.h"

/* (e) An #include whose own target is a macro, not a literal filename -- there
 * is no filename anywhere in this file's text until a real preprocessor
 * expands WIDGET_COMPUTED_HEADER, so only the gcc-based bare pass can resolve
 * this; the literal text-scan half of "bare" (added for issue #1223) cannot,
 * by design. This is why that gcc pass is still run at all rather than
 * replaced outright by the simpler text scan -- each half of "bare" covers a
 * gap the other structurally can't. */
#define WIDGET_COMPUTED_HEADER "macro_target_extra.h"
#include WIDGET_COMPUTED_HEADER

static int Widget__FromProjectFlag(void)
{
#ifdef PROJECT_FLAG
    return PROJECT_FLAG_MACRO;
#else
    return 0;
#endif
}

static int Widget__FromLocalFlag(void)
{
    return LOCAL_FLAG_MACRO;
}

static int Widget__FromNested(void)
{
    return NESTED_MACRO;
}

static int Widget__FromMacroInclude(void)
{
    return MACRO_TARGET_VALUE;
}

int Widget_FromProjectFlag(void)  { return Widget__FromProjectFlag(); }
int Widget_FromLocalFlag(void)    { return Widget__FromLocalFlag(); }
int Widget_FromNested(void)       { return Widget__FromNested(); }
int Widget_FromMacroInclude(void) { return Widget__FromMacroInclude(); }
