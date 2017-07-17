---
layout: default
---

#Troubleshooting and Frequently Asked Questions

### "ERROR: jnifunc not defined"

You are attempting to call Java methods without initialising the JVM. Call `JavaCall.init(...)` first.


###  "Cannot find libjvm" 

The JVM dynamic library cannot be found. It is called `libjvm.so`, `libjvm.dylib` or `jvm.dll` depending on your system. Check that you have `JAVA_HOME` environment variable defined. If you do, verify the search logic in the code, and please file a pull request with an amemded version that can find your library. As a workaround, you can set the `JAVA_LIB` environment variable to point to the location of the library file.

### Segault on OSX

Upon initialising JavaCall on OSX, you get an immediate segfault message, while execution carries on normally.  
```
signal (11): Segmentation fault: 11
unknown function (ip: 0x31960c2b4)
```
This message is usually benign. It is due to the way the JVM uses signals for its regular operations. Julia on OSX installs a signal handler, which generates the above message. However, since the signal is eventually caught and handled by the JVM, execution carries on normally. If the message troubles you for any reason, please start julia with the `--handle-signals=no` option. In this case, Julia's signal handler will be disabled, and you will no longer see the above message. However, this may cause issues with handling `^C` in Julia programs.

_References:_

* http://stackoverflow.com/questions/27241575/why-does-java-app-crash-in-gdb-but-runs-normally-in-real-life
* http://www.oracle.com/technetwork/java/javase/signals-139944.html#gbzbl


### "No Java runtime present, requesting install." message on OSX

Unfortunately, Java on the Mac has a [known bug](https://bugs.openjdk.java.net/browse/JDK-7131356), wherein attempting to load a JVM via JNI fails unless the old OSX system Java 6 libraries are installed on the machine. This is strictly not necessary to run any Java programs, but is required due to a bug. This is scheduled to be fixed only in Java 9. In the meantime, the only option is to download and install the Apple Java 6 libraries from this url: [https://support.apple.com/kb/dl1572?locale=en_US](https://support.apple.com/kb/dl1572?locale=en_US)


### "java.lang.NoSuchMethodError"

1. Make sure the signature of the method is what you expect it to be. See `listmethods()` function from [Reflection API](reflection.html). 

2. Make sure `JavaObject{T}` has an expected type parameter `T`. To call a Java method, `jcall` uses `T` as the name of a class to call the method on, even if actual object class is different. See **Inspecting classes** section from [Reflection API](reflection.html).
