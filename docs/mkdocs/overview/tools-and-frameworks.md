# So Many Tools and Acronyms

**Hold on. Back up. Unity? CMock? CException? Ruby? Rake? YAML?**

## Ceedling suite frameworks

### Unity

[Unity] is a [unit test framework][unit-testing] for C. It provides facilities
for test assertions, executing tests, and collecting / reporting test
results. Unity derives its name from its implementation in a single C
source file (plus two C header files) and from the nature of its
implementation - Unity will build in any C toolchain and is configurable
for even the very minimalist of processors.

[Unity]: http://github.com/ThrowTheSwitch/Unity
[unit-testing]: http://en.wikipedia.org/wiki/Unit_testing

### CMock

[CMock]<sup>†</sup> is a tool written in Ruby able to generate [function mocks & stubs][test-doubles] 
in C code from a given C header file. Mock functions are invaluable in 
[interaction-based unit testing][interaction-based-tests].
CMock's generated C code uses Unity.

<sup>†</sup> Through a [plugin][FFF-plugin], Ceedling also supports
[FFF], _Fake Function Framework_, for [fake functions][test-doubles] as an
alternative to CMock's mocks and stubs.

[CMock]: http://github.com/ThrowTheSwitch/CMock
[test-doubles]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da
[FFF]: https://github.com/meekrosoft/fff
[FFF-plugin]: ../plugins/fff.md
[interaction-based-tests]: http://martinfowler.com/articles/mocksArentStubs.html

### CException

[CException] is a C source and header file that provide a simple
[exception mechanism][exn] for C by way of wrapping up the
[setjmp / longjmp][setjmp] standard library calls. Exceptions are a much
cleaner and preferable alternative to managing and passing error codes
up your return call trace.

[CException]: http://github.com/ThrowTheSwitch/CException
[exn]: http://en.wikipedia.org/wiki/Exception_handling
[setjmp]: http://en.wikipedia.org/wiki/Setjmp.h

## Core tools

### Ruby

[Ruby] is a handy scripting language like Perl or Python. It's a modern, 
full featured language that happens to be quite handy for accomplishing 
tasks like code generation or automating one's workflow while developing 
in a compiled language such as C.

[Ruby]: http://www.ruby-lang.org/en/

### Rake

!!! warning "Migrating away from Rake"
    Ceedling would not exist today if not for the help Rake provided to
    get off the ground. As Ceedling matured it became apparent that 
    Rake had become a limitation. The project is slowly removing its
    dependency on Rake.

[Rake] is a utility written in Ruby for accomplishing dependency 
tracking and task automation common to building software. It's a modern, 
more flexible replacement for [Make].

Rakefiles are Ruby files, but they contain build targets similar
in nature to that of Makefiles (but you can also run Ruby code in
your Rakefile).

[Rake]: http://rubyrake.org/
[Make]: http://en.wikipedia.org/wiki/Make_(software)

### YAML

[YAML] is a "human friendly data serialization standard for all
programming languages." It's kinda like a markup language but don't
call it that. With a YAML library, you can [serialize] data structures
to and from the file system in a textual, human readable form. Ceedling
uses a serialized data structure as its configuration input.

YAML has some advanced features that can greatly 
[reduce duplication][yaml-anchors-aliases] in a configuration file 
needed in complex projects. YAML anchors and aliases are beyond the scope
of this document but may be of use to advanced Ceedling users. Note that 
Ceedling does anticipate the use of YAML aliases. It proactively flattens 
YAML lists to remove any list nesting that results from the convenience of
aliasing one list inside another.

[YAML]: http://en.wikipedia.org/wiki/Yaml
[serialize]: http://en.wikipedia.org/wiki/Serialization
[yaml-anchors-aliases]: https://blog.daemonl.com/2016/02/yaml.html

---

## Dependencies and Bundled Tools

* By using the preferred installation options of the Ruby Ceedling gem or 
  the prepackaged Docker images, all Ceedling dependencies will be installed 
  for you. (See [installation section](../getting-started/installation.md).)

* Regardless of installation method, Unity, CMock, and CException are bundled 
  with Ceedling. Ceedling is designed to glue them all together for your 
  project as seamlessly as possible.

* YAML support is included with Ruby. It requires no special installation
  or configuration. If your project file contains properly formatted YAML
  with the recognized names and options (see later sections), you are good 
  to go.

<br/><br/>
