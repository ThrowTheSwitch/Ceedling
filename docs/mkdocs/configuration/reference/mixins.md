# `:mixins` Configuring Mixins to merge

Mixins allow you to merge configuration with your project configuration
just after the base project file is loaded.

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

[mixins-config-section]: ../loading.md#applying-mixins-to-your-base-project-configuration
[inline-ruby-string-expansion]: ../project-file.md#inline-ruby-string-expansion
