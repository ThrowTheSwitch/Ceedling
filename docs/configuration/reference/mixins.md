# `:mixins` Configuring mixins to merge

This section of a project configuration file is documented in the
[discussion of project files and mixins][mixins-config-section].

**_Notes:_**

* A `:mixins` section is only recognized within a base project configuration 
  file. Any `:mixins` sections within mixin files are ignored.
* A `:mixins` section in a Ceedling configuration is entirely filtered out of
  the resulting configuration. That is, it is unavailable for use by plugins
  and will not be present in any output from `ceedling dumpconfig`.
* A `:mixins` section supports [inline Ruby string expansion][inline-ruby-string-expansion].
  See the full documetation on Mixins for details.

[mixins-config-section]: ../../configuration-loading.md
[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion
