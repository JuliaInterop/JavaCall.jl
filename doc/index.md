---
layout: default
---

#Call Java programs from Julia 

The JavaCall package allows calling Java programs from within Julia code. It uses the Java Native Interface ([JNI][]) to call into an in-process Java Virtual Machine (JVM). The primary entry point to Java is the `jcall` function. This is modeled on the Julia `ccall` function, and takes as input the receiver object (or class, for static methods), the method name, the output type, a tuple of the method parameter types, and the parameters themselves. 

This package has been tested using Oracle JDK 7, 8 and 9 on MacOSX and Ubuntu on 64 bit environments. It has also been shown to work with `OpenJDK` flavour of java. It has also been tested on Windows 64 bit environments. However, it does not work on 32 bit environments. It will not work with the Apple 1.6 JDK since that is a 32 bit JVM, and Julia is typically built as a 64 bit executable on OSX. 

[JNI]: http://docs.oracle.com/javase/1.5.0/docs/guide/jni/spec/jniTOC.html

##Installation

```julia
Pkg.add("JavaCall")
```

This package has a dependency on the `WinReg` package which, on Windows, is used to derive the location of the JDK automatically. 

##Usage

Static and instance methods with primitive or object arguments and return values are callable. Array arguments and return values are also supported. Primitive, string, object or array arguments are converted as required. 


```jlcon

julia> using JavaCall

julia> JavaCall.init(["-Xmx128M"])

julia> jlm = @jimport java.lang.Math
JavaObject{:java.lang.Math} (constructor with 2 methods))

julia> jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
1.0

julia> jnu = @jimport java.net.URL
JavaObject{:java.net.URL} (constructor with 2 methods)

julia> gurl = jnu((JString,), "http://www.google.com")
JavaObject{:java.net.URL}(Ptr{Void} @0x0000000108ae2aa8)

julia> jcall(gurl, "getHost", JString,())
"www.google.com"

julia> j_u_arrays = @jimport java.util.Arrays
JavaObject{:java.util.Arrays} (constructor with 2 methods)

julia> jcall(j_u_arrays, "binarySearch", jint, (Array{jint,1}, jint), [10,20,30,40,50,60], 40)
3

```

##Major TODOs and Caveats

*   Currently, only a low level interface is available, via `jcall`. As a result, this package is best suited for writing libraries that wrap around existing java packages. Writing user code direcly using this interface might be a bit tedious at present. A high level interface using reflection will eventually be built. 

*    While basic memory management has been implemented, there is the possibility of some remaining memory leaks in this system. While this is stable enough for scripting style tasks, please test yourself before deplying this to long running tasks 



