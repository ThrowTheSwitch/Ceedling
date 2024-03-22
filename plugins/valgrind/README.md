ceedling-valgrind
=============

# Plugin Overview

Plugin for integrating Valgrind tool into Ceedling projects.

This plugin currently uses the compiled test executables as the target
executables to be executed under Valgrind. The normal test task _must_ be
run first for Valgrind to succeed.

## Installation

Valgrind can be installed by either building from source, which can be
obtained from [here](https://valgrind.org/downloads/), or by installing
the Valgrind package included in your Linux distribution.

## Example Usage

```sh
ceedling valgrind:all
```
