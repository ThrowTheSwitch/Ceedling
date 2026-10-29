# File Trees

Ceedling copies trees of files whose types it must not misjudge. `FileTree` walks and copies those trees without `lstat`. It lists each directory with `Dir.children` and classifies each entry with `File.stat`. It brings a copy up to date file by file, writes each file whole, and replaces any entry of the wrong type. This is best effort. It removes the dependence on `lstat`, and trusts `stat` in its place, which no filesystem guarantees.

This document is for developers and coding agents changing code that walks or copies trees. It begins with orientation and ends with detail. The orientation explains the problem, where Ceedling copies trees, the rules the code follows, and the invariants a change must keep. Later sections trace each rule to its methods, then cover limits, platforms, and testing.

Statements of fact carry an evidence label where the evidence is not the code itself.

| Label | Meaning |
| --- | --- |
| **[verified]** | Run and observed, as the testing section describes |
| **[sourced]** | Taken from vendor documentation, not reproduced here |
| **[inferred]** | Reasoned from sources, not confirmed |
| **[unverified]** | A hypothesis awaiting a run on the platform in question |

## Orientation

### The problem

`stat` and `lstat` both report a path's type. `stat` follows a link and reports its target. `lstat` reports the link itself. Code that must not follow links, such as a recursive copy or a recursive delete, classifies entries with `lstat`. Ruby's `FileUtils.cp_r` and `FileUtils.rm_rf` do.

On some filesystems `lstat` reports a regular file as a directory while `stat` reports it correctly. Windows reparse points are the known case. A reparse point is a file or directory carrying a tag that a filesystem filter interprets. Some tags make an entry a link to another name, such as a symbolic link or a junction. These are name surrogates. Others mark a transparent storage optimization, such as Data Deduplication (`0x80000013`) or Windows Overlay Filter compression (`0x80000017`). These are not links, and reading such a file returns its contents as usual **[sourced]**. Ruby on Windows can report a non-link reparse point as a directory from `lstat` **[inferred]**. A file on a deduplicated network share has been observed to do so, `stat` reporting it as a file **[sourced]**.

A copy that classifies by `lstat` then makes a directory where the file belongs, and fails reading the file as a directory **[verified]**. The stray directory remains, and every later copy collides with it. Retrying cannot help, because the misreport and the leftover both persist.

A glob is no safer a walk. `Dir.glob( '**/*' )` lists a linked directory without descending into it **[verified]**. It reads `[`, `{`, `*`, and `?` in a pattern as syntax. How it decides an entry's type on Windows is unknown **[unverified]**.

### Where Ceedling copies trees

| Copy | Path through the code | When |
| --- | --- | --- |
| Unity, CMock, and CException into `build/vendor/` | `ConfiguratorSetup#vendor_frameworks_and_support_files` → `FileWrapper#sync_tree` → `FileTree.sync` | Before build tasks, for a test or release build only |
| `ceedling.h` and the gdb backtrace script | `ConfiguratorSetup#vendor_test_support_files` → `FileWrapper#sync_file` → `FileTree.sync_file` | Before test build tasks, when Partials or gdb backtraces are on |
| Ceedling into a project's `vendor/ceedling/`, examples, and docs | `Actionator#copy_directory` → `FileWrapper#tree_files` → `FileTree.each_file` | `ceedling new --local`, `upgrade`, `example`, and `--docs` |

### The rules

1. **Classify by `stat`.** Every source entry is classified with `File.stat`. A destination entry is checked with `File.directory?`, `File.file?`, and `File.exist?`, which follow links as `stat` does.
2. **List with `Dir.children`.** A directory's names are read as names, never as a pattern, and sorted.
3. **Follow links.** A link's target is copied, so a copy holds only regular files and directories. A link loop, a dangling link, a special file such as a socket, or an entry that cannot be read or listed raises a `CeedlingException` naming it.
4. **Write whole.** A file is written to a temporary name beside its destination and renamed over it. A reader sees the old file or the new one, never part of either.
5. **Write only what differs.** A destination file matching its source in size and content is left alone, and keeps its modification time.
6. **Replace the wrong type.** A directory where a file belongs, or a file or dangling link where a directory belongs, is removed and logged before the copy goes on.
7. **Retry only what clears.** A file's whole sync, from its type check to its write, is retried after each of a series of delays when it fails with `EACCES`, `EBUSY`, `EPERM`, or `EINTR`. Any other error fails at once.

### Code organization

| File | Module or class | Role |
| --- | --- | --- |
| `file_tree.rb` | `FileTree` | The walk, the sync, healing, and retries. A pure module, used by `lib/` and `bin/` alike |
| `file_wrapper.rb` | `FileWrapper` | `#sync_tree`, `#sync_file`, and `#tree_files` give `FileTree` Ceedling's publish step, retry delays, and logging |
| `../config/configurator_setup.rb` | `ConfiguratorSetup` | Choosing which frameworks a build vendors, and when |
| `../../../bin/actionator.rb` | `Actionator` | Copying trees for the command line, with its own status lines and skip rules |

### Invariants

Every change to this code must keep these invariants. Specs pin each one.

- No walk classifies by `lstat`. A copy uses it only on the destination: `FileUtils.rm_r` on a directory with contents, and `File.symlink?` to find a link.
- A copy holds only regular files and directories.
- A file that matches its source is never written.
- A destination file is never visible half-written.
- A walk ends. A link loop raises rather than recursing.
- An error that retrying cannot clear surfaces at once.

## Walking: `FileTree.each_file` and `.each_entry`

`each_entry( root, skip: )` yields each directory and regular file below `root`, a directory ahead of its contents, as its path relative to `root`, its full path, and whether it is a directory. `each_file( root, skip: )` yields only the files, as relative and full paths. Without a block, it returns an Enumerator. `skip`, when given, is a callable given each entry's name. An entry it accepts is neither yielded nor entered, nor even stat'd.

Each directory's names come from `Dir.children` and are sorted. A directory that cannot be listed raises "could not be listed". The walk stats each entry. A directory is descended, a regular file is yielded, and anything else raises a `CeedlingException` naming the entry and its type. An entry `stat` cannot read raises "could not be read".

`ENOENT` or `ELOOP` from `stat` means a link points nowhere, and raises "is a dangling or unresolvable link". Before descending, the walk resolves the directory with `File.realpath` and compares it to the real paths of the directories above it. A match raises "Link loop". A directory whose real path cannot be resolved stands for itself, so the walk goes on without that safeguard rather than stopping. A root that is not a directory raises at once.

## Copying: `FileTree.sync` and `.sync_file`

`sync( source, destination, publish:, retry_delays:, sleep:, log: )` brings every file below `source` up to date below `destination`. It returns a `Result` counting files `copied`, `unchanged`, and `healed`. `sync_file( source, destination_dir, … )` does the same for one regular file.

`publish` is a callable given a source and a destination path. It does the writing, so the caller decides how a file is written and checked. `retry_delays` lists seconds to wait between attempts. `sleep` and `log` are seams for specs and for Ceedling's logging. `log` receives a message, a `Verbosity` level, and a `LogLabels` value.

### Directories

A destination directory that exists is kept. A file or a dangling link in its place is removed, counted as healed, and logged. Then `FileUtils.mkdir_p` makes the directory, so empty source directories appear in the copy too.

### Files

A destination directory in a file's place is removed. A link to a directory is unlinked, `Dir.rmdir` removes an empty directory, and `FileUtils.rm_r` one with contents. Any error removing it reaches the retries. Another run may heal the same entry first. `ENOENT` means it removed the directory, and `ENOTDIR` that it already published the file there. This run then counts no heal, and publishes over that file rather than deleting it, so a reader always finds one. A destination file of the same size and the same bytes, by `FileUtils.compare_file`, is counted unchanged and left alone. Otherwise `publish` writes the file.

### Retries

A file's sync raising one of `TRANSIENT_ERRORS` at any step waits the next delay and tries the file again. A scanner or sync client can hold the destination open as well as the file being written. Once the delays are spent, the failure is logged and raised as a `CeedlingException` naming the file and the number of retries. Any other error propagates at once, unchanged. Its message names the path.

### Log messages

| Event | Verbosity, label | Message |
| --- | --- | --- |
| A directory replaced by a file | COMPLAIN, NOTICE | `Replaced a directory where the file '<path>' belongs` |
| A file replaced by a directory | COMPLAIN, NOTICE | `Replaced a file where the directory '<path>' belongs` |
| A retry | DEBUG | `Retrying copy to '<path>' after a transient error: <message>` |
| Retries spent | ERRORS | `Failed to copy to '<path>' after <n> retries ⏩️ <message>`, then advice to delete `build/` or reinstall the gem |

## FileWrapper's part

`#sync_tree` and `#sync_file` pass `FileTree` four things:
- `#replace_file` as the publish step;
- `TRANSIENT_IO_RETRY_DELAYS`, four delays totalling 0.37 s;
- `sleep`;
- the Loginator.

`#replace_file` copies the source to `.<name>.<pid>.<thread id>.tmp` beside the destination and renames it into place. It checks that temporary path's length against the platform's limit first. It makes the copy owner-writable, and a read-only destination file too, since Windows refuses to rename over a read-only file. A destination link is replaced, and the file it names keeps its mode. Execute bits carry over from the source.

`#tree_files( dir, skip: )` returns every regular file below `dir` as a full path, sorted as one list. Sorting the full paths puts `a.c` ahead of `a/b.c`, the same order a sorted glob listing gives.

## Actionator's part

`#copy_directory` copies each file `FileWrapper#tree_files` lists, in that order. It passes `skip: Actionator::HIDDEN`, so entries named with a leading dot are never listed or entered, and nothing inside a hidden directory can stop a copy. It leaves out the junk files its exclude pattern matches too. It compares, forces, and reports each file as it always does, so its status lines match Thor's.

## Limits

- **`stat` is trusted.** The design assumes `stat` reports a type correctly wherever `lstat` does not. That is the observation behind it, not a guarantee.
- **`lstat` remains on the destination.** `FileUtils.rm_r` classifies by `lstat` when it removes a destination directory with contents, and never follows a link out of it. `File.symlink?` asks `lstat` whether a destination entry is a link. Both work on the destination, which Ceedling creates, not on a source a filesystem may misreport.
- **Special files raise.** A socket, a FIFO, or a device in a source tree stops the copy.
- **Extra files stay.** A copy never removes destination files its source lacks.
- **Every file is read.** Comparing a file reads both copies on every build. Vendored trees hold a few hundred small files, so this costs little. Comparing by modification time would cost less, but would trust timestamps.
- **Timestamps.** A written file takes the time of writing. A skipped file keeps its own. Source times are not preserved, and nothing in Ceedling depends on them.
- **Concurrent builds.** Each file is renamed into place whole, so two builds sharing one `build/vendor/` never read a partial file. A heal never deletes a file another build already published, and publishes over it instead. A spec simulates that race. No spec runs two processes.

## Platforms

- **Windows.**
  - Reparse points are the case this design exists for.
  - A junction is a link to a directory. Whether `File.symlink?` reports one is unknown, and the walk descends it either way **[unverified]**.
  - `File.rename` replaces an existing file. Windows refuses to replace a read-only one, though Ruby may clear the attribute itself **[inferred]**. `#replace_file` clears it first either way.
  - Names cannot hold `*` or `?`.
  - Paths stop near 260 characters. The temporary name adds about 20 characters beyond the destination's, and `check_path_length` warns as a path nears the limit.
- **macOS and Linux.**
  - Symlinks are followed.
  - `rename` over a read-only file succeeds, since a directory's permissions govern it.
  - On Linux, `Dir.glob` makes no stat-family calls of its own, reading types from the directory instead **[verified]**.
- **FAT filesystems.**
  - FAT has no links, refuses `*` and `?` in names, and keeps time to 2 s.
  - The specs skip what FAT cannot hold.

## Testing and coverage

### Approach

The specs test the shape of the problem rather than the infrastructure that produces it. Real network shares and real Data Deduplication are too heavy for CI, and unnecessary once the failure is expressed as `lstat` misreporting a type.

### The stand-in

`spec/support/file_tree_helper.rb` defines a `LyingStat`, a stat result that claims a directory. `lie_about_lstat( pattern )` stubs `File.lstat` through RSpec to return one for each path matching `pattern`. `FileUtils` classifies entries by calling `File.lstat` from Ruby, so the stub reaches it **[verified]**. RSpec removes the stub after each example. A global patch of `File` would leak between examples.

Three kinds of example stub `File.lstat`. The control and the survival examples use the stand-in, and the guard a stricter stub.

1. **The control.** `FileUtils.cp_r` fails under the stand-in, making a directory where the file belongs **[verified]**. This shows the stand-in reproduces the failure. If a later Ruby stops failing here, review the control rather than deleting it.
2. **Survival.** `FileTree.sync` copies every file as a file while every entry lies, and `FileTree.each_file` lists every file **[verified]**.
3. **The guard.** With `File.lstat` stubbed to raise on any call, a sync that heals an empty stray directory still succeeds **[verified]**.

The stand-in proves `FileTree` never classifies by `lstat`. It does not prove a real filesystem behaves as the stand-in does, or that `stat` is right everywhere. It exercises the symptom, not the cause.

### Real trees

`spec/units/filesystem/file_tree_spec.rb` builds real trees in a temporary directory and covers:
- nested trees, dotfiles, and empty directories;
- names holding glob metacharacters;
- an unchanged file keeping its modification time, and a changed file replaced, even at the same size;
- extra destination files left alone;
- each kind of healing, the destination root, a dangling link, and a link to a directory included, and a heal another run made first;
- links: a linked root, a linked file, a linked directory, a loop, and a dangling link;
- retries on each transient error, on a destination that cannot yet be read, and on each kind of heal, retries spent, and errors that fail at once;
- entries `skip` names, directories that cannot be listed, entries that cannot be read, and real paths that cannot be resolved;
- `.sync_file`.

**The canary.** One example shows `Dir.glob( '**/*' )` skipping a linked directory's contents. It characterizes Ruby, not `FileTree`. If it ever fails, Ruby changed, and rule 2's reasoning deserves another look.

Examples needing links skip themselves where links cannot be made. The glob-name examples write only names the filesystem accepts.

Specs elsewhere cover the callers:
- `spec/units/filesystem/file_wrapper_spec.rb` covers retries through `#sync_tree`, `#replace_file`'s writable bits and linked destinations, and `#tree_files`.
- `spec/integration/vendor_copy_transient_io_retry_spec.rb` vendors real trees through `ConfiguratorSetup`: a stray directory at any file, a misreporting `lstat`, read-only files, and faults that clear, persist, or cannot clear.
- `spec/integration/actionator_file_operations_spec.rb` covers sorted status lines, hidden entries and the hidden directories never entered, glob-named directories, linked directories, and a misreporting `lstat`.

### Windows reparse points

`spec/units/filesystem/file_tree_windows_spec.rb` runs only on Windows.
- **Junction.** The first example makes a junction with `mklink /J` and copies through it.
- **WOF canary.** The second compresses a file with `compact /exe:lzx`, confirms its reparse tag is `0x80000017`, and prints what `lstat` and `stat` report, without asserting either. It then asserts the copy is a regular file of full size.
- Each skips when its runner cannot make the reparse point.
- Whether Ruby misreports a WOF file is unknown **[unverified]**. The canary answers it on its first run.

### Other filesystems

Every `FileTree` spec carries `filesystem: true`, so `rspec spec/units/filesystem --tag filesystem` selects them. `CEEDLING_TEST_FS_ROOT` names a directory on another filesystem, and the specs build their trees there instead of the system temporary directory.

| Filesystem | What differs | Where it runs | Status |
| --- | --- | --- | --- |
| APFS | Case-insensitive by default | macOS test legs, and locally | **[verified]** |
| ext4 | The Linux baseline | Linux test legs, and locally in Docker | **[verified]** |
| tmpfs | Memory-backed | The Linux Ruby 3.3 leg, with `CEEDLING_TEST_FS_ROOT=/dev/shm` | **[verified]** locally in Docker |
| NTFS | The Windows baseline | Windows test legs | **[unverified]** |
| UNC administrative share | Reaches the local drive through the SMB client | The Filesystem Substrates job | **[unverified]** |
| VHD-backed NTFS volume | A separate volume made with `diskpart` | The Filesystem Substrates job | **[unverified]** |
| Loopback FAT image | No links, restricted names, 2 s timestamps | The Filesystem Substrates job | **[unverified]** |

The Filesystem Substrates job is advisory. A step that cannot set up its filesystem warns, names why, and skips. Each step runs whatever the others did. The UNC step first enables Windows' evaluation of links on a share that name places on a share. The CI summary leaves the job out of its verdict.

### Proof the specs can fail

**Mutations.** `FileTree` was broken on purpose, one change at a time **[verified]**:
- `File.stat` changed to `File.lstat` in the walk made 7 examples fail;
- `Dir.children` changed to `Dir.glob` in the walk made 5 fail.

**Seed sweeps.** 100 random orderings of the spec file pass on APFS, ext4, and tmpfs **[verified]**.

### Coverage

| Scenario | Layer | Linux | macOS | Windows |
| --- | --- | --- | --- | --- |
| `lstat` misreports a file | Stand-in | yes | yes | yes |
| No walk or copy calls `File.lstat` | Stand-in guard | yes | yes | yes |
| Tree shapes, glob names, unchanged and changed files | Real trees | yes | yes | yes |
| Healing entries of the wrong type | Real trees | yes | yes | yes |
| Links | Real trees, skipping without links | yes | yes | where permitted |
| Junctions | Windows real trees | n/a | n/a | planned |
| WOF reparse points | Windows real trees, canary | n/a | n/a | planned |
| Retries and failures | Injected faults | yes | yes | yes |
| Other filesystems | `CEEDLING_TEST_FS_ROOT` | tmpfs, FAT | none | UNC, VHD |

### Not covered

- A real network share whose `lstat` answers change from call to call, and real Data Deduplication.
- Antivirus and cloud-sync software holding files open.
- Two Ceedling processes copying into one `build/vendor/` at once.
- Windows paths near 260 characters with the temporary name's suffix.
- `stat` misreporting a type. The design assumes it does not.

## Sources

- Microsoft, [Reparse Tags](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/c8e77b37-3909-4fe6-a4ea-2b9d423b1ee4) (MS-FSCC 2.1.2.1), for tag values and name surrogates.
- Microsoft, [Data Deduplication overview](https://learn.microsoft.com/en-us/windows-server/storage/data-deduplication/overview), for how optimized files are stored.
