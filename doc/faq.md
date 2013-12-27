---
layout: default
---

#Troubleshooting and Frequently Asked Questions

### ERROR: jnifunc not defined

You are attempting to call Java methods without initialising the JVM. Call `JavaCall.init(...)` first. 


###  Cannot find libjvm in: 

The JVM dynamic library cannot be found. It is called `libjvm.so`, `libjvm.dylib` or `jvm.dll` depending on your system. Check that you have `JAVA_HOME` environment variable defined. If you do, verify the search logic in the code, and please file a pull request with an amemded version that can find your library. As a workaround, you can set the `JAVA_LIB` environment variable to point to the location of the library file. 