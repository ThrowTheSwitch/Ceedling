# `cipher_quest`

:material-incognito: An imagined spy's command line string manipulation
toolkit. This project can be run both as a test suite and as a release build.

## Exporting

```shell
ceedling example cipher_quest [destination]
```

## About

`cipher_quest` simulates a command line toolkit for encoding and decoding
secret messages. Unlike the other example projects, it supports both a test
build and a release build, demonstrating Ceedling's dual build capabilities.

After exporting, run `ceedling test:all` from the project root to execute the
full test suite, or `ceedling release` to produce a release binary.

### Release build note

The release build requires symbol definitions not active in the default project
configuration. These can be set by editing the
[`:defines` section of the example project file](../../configuration/reference/defines.md)
or making use of
[Mixins](../../configuration/loading.md#applying-mixins-to-base-configuration).

<br/><br/>
