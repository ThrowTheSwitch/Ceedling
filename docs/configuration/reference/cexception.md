# `:cexception` Configure CException's features

* `:defines`:

  List of symbols used to configure CException's features in its source and header files 
  at compile time.
  
  See [Using Unity, CMock & CException](../../testing-guide/frameworks.md) for much more on
  configuring and making use of these frameworks in your build.
  
  To manage overall command line length, these symbols are only added to compilation when
  a CException C source file is compiled.
  
  No symbols must be set unless CException's defaults are inappropriate for your 
  environment and needs.
  
  Note CException must be enabled for it to be added to a release or test build and for 
  these symbols to be added to a build of CException (see link referenced earlier for more).
  
  **Default**: `[]` (empty)
