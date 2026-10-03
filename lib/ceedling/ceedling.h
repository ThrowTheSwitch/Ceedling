/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _CEEDLING_SUPPORT_H_
#define _CEEDLING_SUPPORT_H_

// Stringification and tokenization helper macros
#define __PARTIALS_STRINGIFY(x) __PARTIALS_STR(x)
#define __PARTIALS_STR(x) #x
#define __PARTIALS_EXPAND(x) x

// Joins two identifiers into one before stringification. Adjacency alone is not enough
// when the pieces come from separate macro expansions: a preprocessor may insert a space
// between them to keep them distinct tokens, and GCC does, which lands a space inside the
// generated filename. Pasting produces one identifier, so the spelling is the same
// everywhere. The outer level exists so each argument expands before the paste.
#define __PARTIALS_JOIN_(a, b) a##b
#define __PARTIALS_JOIN(a, b) __PARTIALS_JOIN_(a, b)

// Create a unique namespaced variable name
#define PARTIAL_LOCAL_VAR(namespace, var) partial_##namespace##_##var

//
// NOTE: These macros expect symbols CMOCK_MOCK_PREFIX and CEEDLING_PARTIALS_PREFIX to be defined at compilation
//

// Partials directive macros encoding gross configuration
#define TEST_PARTIAL_PUBLIC_MODULE(module) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CEEDLING_PARTIALS_PREFIX)__PARTIALS_EXPAND(module)__PARTIALS_EXPAND(_impl.h))
#define TEST_PARTIAL_PRIVATE_MODULE(module) TEST_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition
#define TEST_PARTIAL_ALL_MODULE(module) TEST_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition
#define MOCK_PARTIAL_PUBLIC_MODULE(module) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CMOCK_MOCK_PREFIX)__PARTIALS_EXPAND(CEEDLING_PARTIALS_PREFIX)__PARTIALS_EXPAND(module)__PARTIALS_EXPAND(_interface.h))
#define MOCK_PARTIAL_PRIVATE_MODULE(module) MOCK_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition
#define MOCK_PARTIAL_ALL_MODULE(module) MOCK_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition

// Partials directive macros requiring configuration
#define TEST_PARTIAL_MODULE(module) TEST_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition
#define MOCK_PARTIAL_MODULE(module) MOCK_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition

// Partials configuration macros
// The parameter construction ensures at least two arguments
#define TEST_PARTIAL_CONFIG(module, func1, ...)
#define MOCK_PARTIAL_CONFIG(module, func1, ...)

//
// Directory-qualified variants, for naming one module among several sharing a basename.
//
// The directory is a qualifier Ceedling matches against trailing path segments, so only
// as much path as it takes to distinguish the module is needed. Ceedling places the
// generated Partial to match wherever the module's own header resolves.
//
// A separate directory parameter is what keeps the Partials prefix on the filename. A
// single parameter carrying the path would stringify to a filename prefixed ahead of the
// path instead. It is also why these macros accept no file extension: an extension in the
// module parameter would land in the middle of the generated filename.
//
#define TEST_PARTIAL_PUBLIC_MODULE_AT(dir, module) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(dir)/__PARTIALS_JOIN(CEEDLING_PARTIALS_PREFIX, module)__PARTIALS_EXPAND(_impl.h))
#define TEST_PARTIAL_PRIVATE_MODULE_AT(dir, module) TEST_PARTIAL_PUBLIC_MODULE_AT(dir, module) // Deduplicate macro definition
#define TEST_PARTIAL_ALL_MODULE_AT(dir, module) TEST_PARTIAL_PUBLIC_MODULE_AT(dir, module) // Deduplicate macro definition
#define TEST_PARTIAL_MODULE_AT(dir, module) TEST_PARTIAL_PUBLIC_MODULE_AT(dir, module) // Deduplicate macro definition
#define MOCK_PARTIAL_PUBLIC_MODULE_AT(dir, module) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(dir)/__PARTIALS_JOIN(__PARTIALS_JOIN(CMOCK_MOCK_PREFIX, CEEDLING_PARTIALS_PREFIX), module)__PARTIALS_EXPAND(_interface.h))
#define MOCK_PARTIAL_PRIVATE_MODULE_AT(dir, module) MOCK_PARTIAL_PUBLIC_MODULE_AT(dir, module) // Deduplicate macro definition
#define MOCK_PARTIAL_ALL_MODULE_AT(dir, module) MOCK_PARTIAL_PUBLIC_MODULE_AT(dir, module) // Deduplicate macro definition
#define MOCK_PARTIAL_MODULE_AT(dir, module) MOCK_PARTIAL_PUBLIC_MODULE_AT(dir, module) // Deduplicate macro definition

// The parameter construction ensures at least three arguments
#define TEST_PARTIAL_CONFIG_AT(dir, module, func1, ...)
#define MOCK_PARTIAL_CONFIG_AT(dir, module, func1, ...)

#endif /* _CEEDLING_SUPPORT_H_ */
