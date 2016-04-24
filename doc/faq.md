---
layout: default
---

#Troubleshooting and Frequently Asked Questions

### ERROR: jnifunc not defined

You are attempting to call Java methods without initialising the JVM. Call `JavaCall.init(...)` first.


###  Cannot find libjvm in:

The JVM dynamic library cannot be found. It is called `libjvm.so`, `libjvm.dylib` or `jvm.dll` depending on your system. Check that you have `JAVA_HOME` environment variable defined. If you do, verify the search logic in the code, and please file a pull request with an amemded version that can find your library. As a workaround, you can set the `JAVA_LIB` environment variable to point to the location of the library file.

### Segault on OSX

Upon initialising JavaCall on OSX, you get an immediate segfault message, while execution carries on normally.  
```
signal (11): Segmentation fault: 11
unknown function (ip: 0x31960c2b4)
```
This message is usually benign. It is due to the way the JVM uses signals for its regular operations. Julia on OSX installs a signal handler, which generates the above message. However, since the signal is eventually caught and handled by the JVM, execution carries on normally. If the message troubles you for any reason, please start julia with the `--handle-signals=no` option. In this case, Julia's signal handler will be disabled, and you will no longer see the above message. However, this may cause issues with handling `^C` in Julia programs.

_References:_
http://stackoverflow.com/questions/27241575/why-does-java-app-crash-in-gdb-but-runs-normally-in-real-life
http://www.oracle.com/technetwork/java/javase/signals-139944.html#gbzbl
