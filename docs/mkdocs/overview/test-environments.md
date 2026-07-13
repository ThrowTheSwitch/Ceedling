# Test Suite Execution Environments

**All your sweet, sweet test suite options**

Ceedling, Unity, and CMock help you create and run test suites using any 
of the following approaches. For more on this topic, please see this 
[handy dandy article][tts-which-build] and/or follow the links for each 
item listed below.

[tts-which-build]: https://throwtheswitch.org/build/which

1. **[Native][tts-build-native].** This option builds and runs code on your 
   host system.
    * In the simplest case this means you are testing code that is intended
      to run on the same sort of system as the test suite. Your test 
      compiler toolchain is the same as your release compiler toolchain.
    * However, a native build can also mean your test compiler is different
      than your release compiler. With some thought and effort, code for
      another platform can be tested on your host system. This is often
      the best approach for embedded and other specialized development.
1. **[Emulator][tts-build-cross].** In this option, you build your test code with your target's
   toolchain, and then run the test suite using an emulator provided for
   that target. This is a good option for embedded and other specialized
   development — if an emulator is available.
1. **[On target][tts-build-cross].** The Ceedling bundle of tools can create test suites that
   run on a target platform directly. Particularly in embedded development
   — believe it or not — this is often the option of last resort. That is,
   you should probably go with the other options in this list.

[tts-build-cross]: https://throwtheswitch.org/build/cross
[tts-build-native]: https://throwtheswitch.org/build/native

<br/><br/>
