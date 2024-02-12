ceedling-module-generator
=========================

## Plugin Overview

The module_generator plugin adds a pair of new commands to Ceedling, allowing
you to make or remove modules according to predefined templates. With a single call,
Ceedling can generate a source, header, and test file for a new module. If given a
pattern, it can even create a series of submodules to support specific design patterns.
Finally, it can just as easily remove related modules, avoiding the need to delete
each individually.

Let's say, for example, that you want to create a single module named `MadScience`.

```
ceedling module:create[MadScience]
```

It says we're speaking to the module plugin, and we want to create a new module. The
name of that module is between the brackets. It will keep this case, unless you have
specified a different default (see configuration). It will create three files:
`MadScience.c`, `MadScience.h`, and `TestMadScience.c`. *NOTE* that it is important that
there are no spaces between the brackets. We know, it's annoying... but it's the rules.

### Patterns

You can also create an entire pattern of files. To do that, just add a second argument
to the pattern ID. Something like this:

```
ceedling module:create[SecretLair,mch]
```

In this example, we'd create 9 files total: 3 headers, 3 source files, and 3 test files. These
files would be named `SecretLairModel`, `SecretLairConductor`, and `SecretLairHardware`. Isn't
that nice?

### Paths

But what if I don't want it to place my new files in the default location?

It can do that too! You can give it a hint as to where to find your files. The pattern matching
here is fairly basic, but it is usually sufficient. It works perfectly if your directory structure
matches a common pattern. For example, let's say you issue this command:

```
ceedling module:create[lab:SecretLair,mch]
```

Say your directory structure looks like this:

```
:paths:
  :source:
    - lab/src
    - lair/src
    - other/src
  :test:
    - lab/test
    - lair/test
    - other/test
```

In this case, the `lab:` hint would make the module generator guess you want your files here:

 - source files: `lab/src` (because it's a close match)
 - include files: `lab/src` (because no include paths were listed)
 - test files: `lab/test` (because it's a close match)

Instead, if your directory structure looks like this:

```
:paths:
  :source:
    - src/**   #this might contain subfolders lab, lair, and other
  :include:
    - inc/**   #again, this might contain subfolders lab, lair, other, and shared
  :test:
    - test
```

In this case, the `lab:` hint would make the module generator guess you want your files here:

 - source files: `src/lab` (because it's a close match)
 - include files: `inc/lab` (because it's a close match)
 - test files: `test` (because there wasn't a close match, and this was the first entry on our list)

You can see that more complicated structures will have files placed in the wrong place from time to
time... no worries... you can move the file after it's created... but if your project has any kind of 
consistent structure, the guessing engine does a good job of making it work.

Three more quick notes about the path-matching:

1. You can give multiple ordered hints that map roughly to folder nesting! `lab:secret:lair` will 
   happily match to put `lair.c` in a folder like `my/lab/secret/`.

2. Whenever the matcher fails to find a good candidate (or if it finds multiple equally good 
   candidates), it will always guess in the order you have the paths listed in your project.yml file

## Stubbing

Similarly, you can create stubs for all functions in a header file just by making a single call
to your handy `stub` feature, like this:

```
ceedling module:stub[SecretLair]
```

This call will look in `SecretLair.h` and will generate a file `SecretLair.c` that contains a stub
for each function declared in the header! Even better, if `SecretLair.c` already exists, it will
add only new functions, leaving your existing calls alone so that it doesn't cause any problems.

## Configuration

Enable the plugin in your project.yml by adding `module_generator`
to the list of enabled plugins.

Then, like much of Ceedling, you can just run as-is with the defaults, or you can override those
defaults for your own needs. For example, new source and header files will be automatically
placed in the `src/` folder while tests will go in the `test/` folder. That's great if your project
follows the default ceedling structure... but what if you have a different structure?

```
:module_generator:
  :project_root: ./
  :naming: :bumpy
  :includes: 
    - :src: []
    - :inc: []
    - :tst: []
  :boilerplates:
    - :src: ""
    - :inc: ""
    - :tst: ""
```

Now I've redirected the location where modules are going to be generated.

### Includes

You can make it so that all of your files are generated with a standard include list. This is done
by adding to the `:includes` array. For example:

```
:module_generator:
  :includes:
    :tst:
      - defs.h
      - board.h
    :src:
      - board.h
```

### Boilerplates

You can specify the actual boilerplate used for each of your files. This is the handy place to
put that corporate copyright notice (or maybe a copyleft notice, if that's your preference?)

Notice there is a separate template for source files, include files, and test files. Also, 
your boilerplates can optionally contain `%1$s` which will inject the filename into that spot.

```
:module_generator:
  :boilerplates: 
    :src: |
      /***************************
      * %1$s
      * This file is Awesome.
      * That is All.
      ***************************/
    :inc: |
      /***************************
      * Header. Woo.             *
      ***************************/
    :tst: |
      /***************************
      * My Awesome Test For %1$s
      ***************************/
```

### Test Defines

You can specify the "#ifdef TEST" at the top of the test files with a custom define.
This example will put a "#ifdef CEEDLING_TEST" at the top of the test files.  

```
:module_generator:
  :test_define: CEEDLING_TEST
```

### Naming Convention

Finally, you can force a particular naming convention. Even if someone calls the generator
with something like `MyNewModule`, if they have the naming convention set to `:caps`, it will
generate files like `MY_NEW_MODULE.c`. This keeps everyone on your team behaving the same way.

Your options for `:naming:` are as follows:

  - `:bumpy` - BumpyFilesLooksLikeSo
  - `:camel` - camelFilesAreSimilarButStartLow
  - `:snake` - snake_case_is_all_lower_and_uses_underscores
  - `:caps`  - CAPS_FEELS_LIKE_YOU_ARE_SCREAMING


