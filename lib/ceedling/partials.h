#ifndef CEEDLING_PARTIALS_H
#define CEEDLING_PARTIALS_H

// Define mock prefix via command line symbol definition
#ifndef CEEDLING_MOCK_PREFIX
#define CEEDLING_MOCK_PREFIX mock_
#endif

// Stringification and tokenization helper macros
#define __PARTIALS_STRINGIFY(x) __PARTIALS_STR(x)
#define __PARTIALS_STR(x) #x
#define __PARTIALS_EXPAND(x) x

// Create a unique namespaced variable name
#define PARTIAL_LOCAL_VAR(namespace, var) partial_##namespace##_##var

#define TEST_PARTIAL_MODULE(file, ...) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_impl.h))
#define MOCK_PARTIAL_MODULE(file, ...) __PARTIALS_STRINGIFY(__PARTIALS_EXPAND(CEEDLING_MOCK_PREFIX)__PARTIALS_EXPAND(partial_)__PARTIALS_EXPAND(file)__PARTIALS_EXPAND(_interface.h))

#endif /* CEEDLING_PARTIALS_H */
