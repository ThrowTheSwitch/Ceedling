# `cipher_quest`

An imagined intelligence agent’s command line string manipulation toolkit.
This project can be run both as a test suite and as a release build.

See the [project README](../../snapshot/examples/cipher_quest/README.md) 
for full details. The README is linked here for convenience but is also 
exported with the example project.

## Exporting

```shell
ceedling example cipher_quest [destination]
```

After exporting, run `ceedling test:all` from the project root to execute the
full test suite, or `ceedling release` to produce a release binary. Note that
the release build requires configuration from you to provide needed symbols.

## About

`cipher_quest` simulates a command line toolkit for encoding and decoding
secret messages. Unlike the other example projects, it supports both a test
build and a release build, demonstrating Ceedling’s dual build capabilities.

## Release builds

The release build requires symbol definitions not active in the default project
configuration. That is, without specifying at least one symbol corresponding to
a feature set, the release build will fail. The test build is configured such
that each set of tests enables the symbol needed by the source under test.

Symbols needed by the release build can be provided by:

1. Editing the [`:defines` section](../../configuration/reference/defines.md)
   of the example project file.
2. Making use of [Mixins](../../configuration/mixins.md)
   to selectively enable the needed symbols. The example project includes 
   mixin files, and the project README provides examples of enacting all 
   availble Mixin features.

<br/><br/>
