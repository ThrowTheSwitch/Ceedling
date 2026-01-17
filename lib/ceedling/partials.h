#ifndef CEEDLING_PARTIALS_H
#define CEEDLING_PARTIALS_H

// Define mock prefix via command line symbol definition
#ifndef CMOCK_MOCK_PREFIX
#define CMOCK_MOCK_PREFIX mock_
#endif

// Stringification and tokenization helper macros
#define __PARTIALS_STRINGIFY(x) __PARTIALS_STR(x)
#define __PARTIALS_STR(x) #x
#define __PARTIALS_EXPAND(x) x

// Create a unique namespaced variable name
#define PARTIAL_LOCAL_VAR(namespace, var) partial_##namespace##_##var

// Candidate eventual partials macros
// #define TEST_PARTIAL_MODULE(file, ...) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_impl.h))
// #define MOCK_PARTIAL_MODULE(file, ...) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CMOCK_MOCK_PREFIX)__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_interface.h))

// Temporary, first working version partials macros
#define TEST_PARTIAL_PUBLIC_MODULE(file) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_impl.h))
#define TEST_PARTIAL_PRIVATE_MODULE(file) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_impl.h))
#define MOCK_PARTIAL_PRIVATE_MODULE(file) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CMOCK_MOCK_PREFIX)__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_interface.h))
#define MOCK_PARTIAL_PUBLIC_MODULE(file) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CMOCK_MOCK_PREFIX)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(.h))


#endif /* CEEDLING_PARTIALS_H */
