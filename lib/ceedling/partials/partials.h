#ifndef CEEDLING_PARTIALS_H
#define CEEDLING_PARTIALS_H

// Stringification and tokenization helper macros
#define __PARTIALS_STRINGIFY(x) __PARTIALS_STR(x)
#define __PARTIALS_STR(x) #x
#define __PARTIALS_EXPAND(x) x

// Create a unique namespaced variable name
#define PARTIAL_LOCAL_VAR(namespace, var) partial_##namespace##_##var

//
// NOTE: These macros expect symbols CMOCK_MOCK_PREFIX and CEEDLING_PARTIALS_PREFIX to be defined at compilation
//

// Partials directive macros encoding gross configuration
#define TEST_PARTIAL_PUBLIC_MODULE(module) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CEEDLING_PARTIALS_PREFIX)__PARTIALS_EXPAND(module)__PARTIALS_EXPAND(_impl.h))
#define TEST_PARTIAL_PRIVATE_MODULE(module) TEST_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition
#define MOCK_PARTIAL_PUBLIC_MODULE(module) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CMOCK_MOCK_PREFIX)__PARTIALS_EXPAND(CEEDLING_PARTIALS_PREFIX)__PARTIALS_EXPAND(module)__PARTIALS_EXPAND(_interface.h))
#define MOCK_PARTIAL_PRIVATE_MODULE(module) MOCK_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition

// Partials directive macros needing configuration
#define TEST_PARTIAL_MODULE(file) TEST_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition
#define MOCK_PARTIAL_MODULE(file) MOCK_PARTIAL_PUBLIC_MODULE(module) // Deduplicate macro definition

// Partials configuration macros
// The parameter construction ensures at least two arguments
#define TEST_PARTIAL_CONFIG(module, func1, ...)
#define MOCK_PARTIAL_CONFIG(module, func1, ...)

#endif /* CEEDLING_PARTIALS_H */
