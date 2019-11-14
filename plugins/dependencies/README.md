ceedling-dependencies
=====================

Plugin for supporting release dependencies. It's rare for an embedded project to 
be built completely free of other libraries and modules. Some of these may be 
standard internal libraries. Some of these may be 3rd party libraries. In either 
case, they become part of the project's ecosystem.

This plugin is intended to make that relationship easier. It allows you to specify
a source for dependencies. If required, it will automatically grab the appropriate
version of that dependency.

Most 3rd party libraries have a method of building already in place. While we'd
love to convert the world to a place where everything downloads with a test suite 
in Ceedling, that's not likely to happen anytime soon. Until then, this plugin 
will allow the developer to specify what calls Ceedling should make to oversee
the build process of those third party utilities. Are they using Make? CMake? A
custom series of scripts that only a mad scientist could possibly understand? No
matter. Ceedling has you covered. Just specify what should be called, and Ceedling
will make it happen whenever it notices that the output artifacts are missing.

Output artifacts? Sure! Things like static and dynamic libraries, or folders 
containing header files that might want to be included by your release project.

So how does all this magic work?

First, you need to add the `:dependencies` plugin to your list. Then, we'll add a new 
section called :dependencies. There, you can list as many dependencies as you desire. Each 
has a series of fields which help Ceedling to understand your needs. Many of them are
optional. If you don't need that feature, just don't include it! In the end, it'll look 
something like this:

```
:dependencies:  
  :libraries:
    - :name: WolfSSL
      :working_path: third_party/wolfssl 
      :fetch:
        :method: :zip
        :source: \\shared_drive\third_party_libs\wolfssl\wolfssl-4.2.0.zip
      :environment:
        CFLAGS: -DWOLFSSL_DTLS_ALLOW_FUTURE
      :build:
        - "autoreconf -i"
        - "./configure --enable-tls13 --enable-singlethreaded"
        - make
        - make install
      :artifacts:
        :static_libraries:
          - lib/wolfssl.a
        :dynamic_libraries:
          - lib/wolfssl.so
        :includes:
          - include/
```

Let's take a deeper look at each of these features.

The Starting Dash & Name
------------------------

Yes, that opening dash tells the dependencies plugin that the rest of these fields
belong to our first dependency. If we had a second dependency, we'd have another 
dash, lined up with the first, and followed by all the fields indented again. 

By convention, we use the `:name` field as the first field for each tool. Ceedling 
honestly doesn't care which order the fields are given... but as humans, it makes
it easier for us to see the name of each dependency with starting dash. 

The name field is only used to print progress while we're running Ceedling. You may
call the name of the field whatever you wish.

Working Folder
--------------

The `:working_path` item allows us to specify where the dependencies are stored. 
By default, each dependency will be built in `dependencies\dep_name` where `dep_name`
is the name specified in `:name` above (with special characters removed). It's best,
though, if you specify exactly where you want your libraries to live.

If the dependency is directly included in your project, this is where Ceedling 
should look for it. If you're doing one of the methods of fetching from another source,
then this is where Ceedling will be placing the fetched code.

Fetching Dependencies
---------------------


Building Dependencies
---------------------


Artifacts
---------

