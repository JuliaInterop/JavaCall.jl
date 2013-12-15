# JavaCall

Call Java programs from Julia. Uses JNI into an in-process JVM.
 

Static and instance methods with primitive, String or Object arguments and return values are callable now. One dimensional Array arguments and return values are also supported. Since Java uses Array-of-Arrays, unlike Julia's true multidimensional arrays, supporting them is a non-trivial, though eventually feasible, excercise.  

Currently, only a low level interface is available. The `jcall` interface is modelled on julia's `ccall`. As a result, this package is best suited for writing libraries that wrap around existing java packages. Writing user code will be a bit tedious at present, though significantly simpler than using native jni, since this package converts argument types automatically. 

A high level interface using reflection will eventually be built. 

```jlcon julia> using JavaCall

julia> JavaCall.initjava(["-Xmx 128M"])

julia> jlm = @jvimport java.lang.Math
JObject{:java.lang.Math} (constructor with 2 methods))

julia> jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
1.0

julia> jnu = @jvimport java.net.URL
JObject{:java.net.URL} (constructor with 2 methods)

julia> gurl = jnu((JString,), "http://www.google.com")
JObject{:java.net.URL}(Ptr{Void} @0x0000000108ae2aa8,JClass{:java.net.URL}(Ptr{Void} @0x0000000108ae2a90))

julia> jcall(gurl, "getHost", JString,())
"www.google.com"

julia> j_u_arrays = @jvimport java.util.Arrays
JObject{:java.util.Arrays} (constructor with 2 methods)

julia> jcall(j_u_arrays, "binarySearch", jint, (Array{jint,1}, jint), [10,20,30,40,50,60], 40)
3

```

[![Build Status](https://travis-ci.org/aviks/JavaCall.jl.png)](https://travis-ci.org/aviks/JavaCall.jl)
