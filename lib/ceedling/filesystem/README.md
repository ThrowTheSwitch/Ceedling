# Files and Paths

This directory holds the code that spells, compares, collects, places, and finds paths, and the code that reads, writes, and copies files. Everything else in Ceedling reaches the filesystem through it.

The pure modules depend on no DIY object or configuration, so the launcher in `bin/` uses them too. The DIY objects are built from `lib/ceedling/objects.yml`, and the launcher builds `FileWrapper` from `bin/objects.yml`. Code requires any file here as `ceedling/filesystem/<name>`. Unit specs mirror this directory in `spec/units/filesystem/`.

Two design documents sit beside the code. [PATH_HANDLING.md](PATH_HANDLING.md) covers path spelling, containment, and build file placement. [FILE_TREE.md](FILE_TREE.md) covers walking and copying file trees without `lstat`.

## Path spelling and placement

Pure modules with no state beyond memos.

| File | Module | Role |
| --- | --- | --- |
| [`project_paths.rb`](project_paths.rb) | `ProjectPaths` | One spelling for every path. Absolute, relative, and canonical forms, and containment by whole directories |
| [`build_subpath.rb`](build_subpath.rb) | `BuildSubpath` | A build file's place from its source's path from the project root, with the `_up_`, `_abs_`, `_unc_`, and `_ceedling_` markers, and back |
| [`path_spellings.rb`](path_spellings.rb) | `PathSpellings` | A place's listed and real spellings, and how far one place lies below another |
| [`path_exclusions.rb`](path_exclusions.rb) | `PathExclusions` | What collection leaves out: `-:` entries, excluded places, and reserved places |
| [`path_mirror.rb`](path_mirror.rb) | `PathMirror` | A file's subdirectory below the most specific configured root that contains it |
| [`path_matcher.rb`](path_matcher.rb) | `PathMatcher` | Resolving `..` in a query, and matching a query's trailing segments against a collection |
| [`destination_collision.rb`](destination_collision.rb) | `DestinationCollision` | Stopping a build when two inputs map to one output |

## Path services

DIY objects that apply the modules above to a project's configuration.

| File | Class | Role |
| --- | --- | --- |
| [`file_path_utils.rb`](file_path_utils.rb) | `FilePathUtils` | Test names and the path of every build file |
| [`file_path_collection_utils.rb`](file_path_collection_utils.rb) | `FilePathCollectionUtils` | Collecting `:paths` directories and `:files` revisions, with exclusions applied |
| [`file_finder.rb`](file_finder.rb) | `FileFinder` | Finding a build file's input from the build file's own path |
| [`file_finder_helper.rb`](file_finder_helper.rb) | `FileFinderHelper` | Resolving a query against a collection: its one match, the first of several with a notice, or a report of none |

## File I/O

| File | Module or class | Role |
| --- | --- | --- |
| [`file_wrapper.rb`](file_wrapper.rb) | `FileWrapper` | The DIY object most code uses to read, write, list, and copy files. It checks path lengths, retries transient I/O errors, and replaces files whole; this class is mocked for unit testing against |
| [`file_tree.rb`](file_tree.rb) | `FileTree` | A pure module that walks a tree classifying entries by `stat`, and brings a copy up to date, replacing entries of the wrong type. See [FILE_TREE.md](FILE_TREE.md) |
| [`file_system_wrapper.rb`](file_system_wrapper.rb) | `FileSystemWrapper` | Changing the working directory for the length of a block |
