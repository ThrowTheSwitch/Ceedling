# Ownership

`OwnershipLedger` records which tests own each artifact. A delta build removes leftovers by that record and never by inference. The ledger never removes a file it did not record.

## Contents

- [Entries](#entries) covers what the ledger records, when, and where it saves.
- [Leftovers](#leftovers) covers which artifacts a build removes, and when.
- [Clean and clobber](#clean-and-clobber) covers the tasks that empty the build tree.
- [Code](#code) lists the file and the interface.

## Entries

An entry maps a placement to its identity, its owners and the stage that writes it. The ledger holds one entry per artifact.

- **Recorded first.** Each stage records its planned artifacts before it writes them, and the ledger saves then. A run that stops partway leaves no artifact unrecorded.
- **Saved** with the dependency cache, one ledger per build context.
- **Several owners.** An entry may list several owners, and it stays while any owner remains.
- **Plugin hooks** receive each mock's placement from the build plan, so they always see the current mocks.

## Leftovers

A leftover is an artifact that no identity in this build owns. The ledger removes it before any later stage can search it.

- **When.** Once a test's plan for an artifact kind is complete, the ledger removes each artifact of that kind the test owned last build and no longer plans. Mocks, Partials, runners and the header copies stage 5 plans complete at stage 5. Objects, source copies, the header copies stage 14 plans, and results complete at stage 14.
- **Stand-ins.** Stage 4's rounds search the stand-ins that earlier rounds wrote, so their removal can't wait for stage 4's plan to complete. When stage 4 runs for a test, it starts by removing every stand-in the test owned last build, and each round writes the stand-ins it plans.
- **Owners that leave.** When the ledger loads, an owner whose test file is no longer in the test collection leaves every entry. An entry with no owner left is removed.
- **Exact names.** A rerun removes a test's results by their placements, never by a glob.
- **Only its own.** The ledger removes only files it recorded. A file it never recorded stays until a clobber.

## Clean and clobber

`ceedling clean` removes every recorded artifact and empties the ledger. A clobber removes the build root, the ledger included. It also empties `:cmock` ↳ `:mock_path` when that sits outside the build root, since every overlay root lies below it. Files an earlier release wrote were never recorded, so an upgrade needs one clobber.

## Code

- `lib/ceedling/paths/ownership_ledger.rb` holds `OwnershipLedger`, a record that saves through the dependency cache store.
- `record( identities, stage: )`, `remove_leftovers( owner, kind, planned )` and `leave( owners )` are its interface.
- Specs: `spec/units/paths/ownership_ledger_spec.rb`. The contract rows of area `DELTA` build real projects across builds.
