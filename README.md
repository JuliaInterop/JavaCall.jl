# JavaCall

Call Java programs from Julia. 

Work in progress. Static and instance methods with primitive, String or Object arguments and return values are callable now. Array arguments and return values are yet to be done.  

Also, only a low level interface is available. The `jcall` interface is modelled on julia's `ccall`. A high level interface using reflection will eventually be built. 

```jlcon
julia> using JavaCall

julia> JavaCall.initjava(["-Xmx 128M"])

julia> jlm = @jvimport "java.lang.Math"
jv_java_lang_Math (constructor with 2 methods)

julia> jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
1.0

julia> jnu = @jvimport "java.net.URL"
jv_java_net_URL (constructor with 2 methods)

julia> gurl = jnu((JString,), "http://www.google.com")
jv_java_net_URL(JClass{jv_java_net_URL}("java/net/URL",Ptr{Void} @0x0000000109c097d0),Ptr{Void} @0x0000000109c097e0)

julia> jcall(gurl, "getHost", JString,())
"www.google.com"

```

[![Build Status](https://travis-ci.org/aviks/JavaCall.jl.png)](https://travis-ci.org/aviks/JavaCall.jl)
