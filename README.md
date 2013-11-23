# JavaCall

Call Java programs from Julia. 

Work in progress, only static methods with primitive arguments and primitive return values are callable now. 

Also, only a low level interface is available. The `jcall` interface is modelled on julia's `ccall`. A high level interface using reflection will eventually be built. 

```jlcon
julia> using JavaCall

julia> JavaCall.initjava(["-Xmx 128M"])

julia> jlm = @jvimport "java.lang.Math"
jv_java_lang_Math (constructor with 2 methods)

julia> jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
1.0

```

[![Build Status](https://travis-ci.org/aviks/JavaCall.jl.png)](https://travis-ci.org/aviks/JavaCall.jl)
