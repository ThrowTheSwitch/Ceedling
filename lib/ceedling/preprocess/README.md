# Preprocessing in Ceedling

## Summary

Ceedling’s preprocessing system provides the basis for C code extraction and transformation capabilities for test builds. It operates in two primary modes utilitizing GCC’s preprpocessor output:

1. **Includes Extraction** — Extracts and categorizes `#include` directives (user vs. system headers).
2. **Code Expansion** — Fully expands macros and preprocessor directives to generate simplified C files (both test and source files). Reconstructing C code from this expansion is dependent on (1).

Ceedling’s preprocessing system runs GCC’s preprocessor in multiple modes to extract includes and expand C code. It employs cacheing and conditional strategies to minimize preprocessing tool execution across test runs.

---

## Includes Extraction

### Overview

Includes extraction identifies all `#include` directives in a C file and categorizes them as either user includes (`#include "header.h"`) or system includes (`#include <header.h>`). This process can operate independently of code expansion for use in Ceedling build steps. The same process is relied upon to provide the include directives needed for reconstructing expanded C files.

### Three-Way Intersection Technique

Ceedling uses a three-way intersection approach to accurately extract and categorize includes:

#### 1. Bare Includes Extraction

The preprocessor runs in **dependencies mode** (`-MM -MG -MP`) with:
- All project symbols defined.
- **Only** the Ceedling vendor path in search paths (no project paths). This ensures no header files are opened apart from Ceedling’s internal _partials.h_.

This configuration causes the preprocessor to:
- Conditionally evaluate all `#ifdef`, `#ifndef`, and `#if defined()` directives.
- Assume any unresolved includes will be generated (via `-MG` flag). This encompasses mocks but also avoids any include guard complications since no headers are actually opened.
- Extract all includes that would be processed given the current symbol definitions.

**Result:** A complete list of all includes that would be processed but without distinguishing user vs. system includes.

#### 2. User Includes Extraction

The preprocessor runs in **directives-only mode** (`-E -dD -fdirectives-only`) with full symbols and search paths, which:
- Outputs only preprocessor directives and line markers.
- Preserves the original `#include` statements.
- Generates line markers showing file entry/exit points.

Ceedling parses the line markers to identify:
- All user includes via tracing which headers were entered (flag `1` in line markers).
- Which files are user headers (_absence_ of flag `3` in line markers).

**Result:** A list of all user includes associated with the processed file. Note that because of nesting includes and include guards this list cannot be used to determine the top-level (i.e. depth 0) includes in the way bare includes extraction can.

**Note:** The directives-only mode requires that all files referenced in `#include` directives exist in search paths. Ceedling addresses this need by generating blank “stand-in” files for mocks and partials to allow the preprocessor to succeed. These files are replaced by the actual generated content in later build steps.

#### 3. System Includes Extraction

Using the same directives-only preprocessor output as used for user includes, Ceedling identifies:
- Includes marked with the system header flag (`3`).
- Includes limited to a practical depth (typically 5 levels) to avoid excessive noise from deeply nested internal system includes.

**Result:** A list of system includes associated with the processed file. Note that because of nesting includes and include guards this list cannot be used to determine the top-level (i.e. depth 0) includes in the way bare includes extraction can.

#### 4. Intersection and Reconciliation

The three lists are reconciled using `Includes.reconcile()`:
- **Bare includes** provide the authoritative list of the top-level (i.e. depth 0) includes but with no distinction of user and system includes.
- **User includes** from line markers distinguishes user headers.
- **System includes** from line markers distinguishes system headers.
- Any include appearing in bare includes but not in user/system lists is ignored.

The final list is sanitized to:
- Remove self-references (a file referencing itself).
- Remove any includes that have been mocked (e.g., `mock_header.h` supersedes `header.h`).
- Sort such that system includes are first in the resulting list (a C best practice).

### Benefits of This Approach

- **Conditional accuracy:** Respects `#ifdef` and other conditional compilation directives.
- **No include guard issues:** Never opens actual header files during bare includes extraction, ensuring a list of top-level (i.e. depth 0) include directives.
- **Handles generated files:** Assumes missing files will be generated (mocks, etc.).
- **Proper categorization:** Distinguishes user vs. system includes for correct build ordering.

---

## Code Expansion

### Overview

Code expansion transforms C source and header files by fully expanding all preprocessor directives, macros, and conditional compilation statements. This produces simplified files suitable for extracting test case names, C function definitions (for Partials), and more as needed by Ceedling’s advanced features.

Code expansion via the preprocessor is “too good.” It expands all include directives, macros, etc. These details are needed by various build steps and text extraction. As such, after code expansion, Ceedling reconstructs the expanded code file to inject include directives and certain macros.

### Full Preprocessing Mode

The preprocessor runs in **full expansion mode** (`-E`) with:
- All project symbols defined.
- Complete search paths (project, vendor, system).
- All header files opened and processed.

This generates output where:
- All macros are expanded to their final values.
- All `#ifdef`/`#ifndef` blocks are resolved.
- All `#include` directives are replaced with file contents.
- Line markers indicate the source of each line.

### File Reconstruction

Expanded files are reconstructed to maintain a usable structure:

#### 1. Header Reconstruction

For each expanded header file:
1. Extract the original includes list (using the includes extraction process discussed in preceding sections).
2. Create a new file with:
   - Original `#include` directives at the top (user and system headers).
   - Fully expanded macros, function declarations, and function definitions.

#### 2. Source File Reconstruction

For each expanded source file:
1. Extract the original includes list.
2. Create a new file with:
   - Original `#include` directives at the top.
   - Fully expanded code with all macros resolved.
   - All conditional compilation resolved.

### Directives-Only Output Usage

The directives-only preprocessor output serves multiple purposes in reconstruction:

1. **Include:** Used by includes extraction to inject includes into reconstructed files.
2. **Macro Preservation (Optional):** Can extract `#define` directives for inclusion in reconstructed C files. Key “marker” macros like `TEST_SOURCE_FILE()` must be preserved for text scanning steps that provide the details of the marker needed in later build steps.

### Dependency on Includes Extraction

Code expansion **requires** includes extraction because:
- Reconstructed files need original `#include` directives at the top, but these are expanded inline during preprocessing.
- Mock generation requires knowing which mocks a test author referenced in a test file.

Without accurate includes extraction, reconstructed files would lack proper header dependencies and fail to compile or provide necessary build details to later build steps.

---

## Efficiencies and Caching

### Shared Directives-Only Output

**Problem:** Multiple preprocessing steps need the same directives-only preprocessor output.

**Solution:** Generate the directives-only output once and pass its filepath to all consumers:

**Benefits:**
- Reduces preprocessor invocations from N to 1 per file.
- Eliminates redundant file I/O.
- Ensures consistency across extraction steps.

### Shared Directives-Only Output

**Problem:** Preprocessing is expensive and often repeated unnecessarily.

**Solution:** Cache extracted includes lists as YAML files and rely on file timestamps to determine if cached includes are up to date and can be used in place of running the preprocessor multiple times.

**Benefits:**
- Skips expensive preprocessing on unchanged files.
- Preserves full includes information across runs.

---

## Fallback

If executing the preprocessor fails for any reason — a mode not supported by the toolchain available in the environment or some oddball quirk of symbols and paths — automatic fallback options are executed.

In fallback modes, in place of relying on the preprocessor, Ceedling relies on simple text scanning of the original file. Of course, this cannot be resilient to conditional compilation, etc. that preprocessing handles. But, this can often be good enough or bring a test build to a sufficient point of completion to allow a test author to more easily determine the failure scenario at hand.

---

## Implementation Details

**Key Classes**
- `Preprocessinator` - Main preprocessing orchestrator.
- `PreprocessinatorIncludesHandler` - Manages includes extraction workflows.
- `PreprocessinatorLineMarkerIncludesExtractor` - Parses line markers from directives-only output.
- `PreprocessinatorBareIncludesExtractor` - Parses make-style dependency output.
- `PreprocessinatorReconstructor` — Recreates C code files from fully expanded output, include lists, and optionally preserved directives.
- `Include` objects and derivatives — Encapsulates include directive details.
- `Includes` - Various utilities for processing includes lists.
- `IncludeFactory` - Manufactures `UserInclude` and `SystemInclude` objects.
