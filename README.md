# JavaCall

[![Build Status](https://travis-ci.org/JuliaInterop/JavaCall.jl.png)](https://travis-ci.org/JuliaInterop/JavaCall.jl) [![Build status](https://ci.appveyor.com/api/projects/status/qeu6ul9o9s6t5tiw?svg=true)](https://ci.appveyor.com/project/aviks/javacall-jl-6c24s)
 [![JavaCall](http://pkg.julialang.org/badges/JavaCall_0.3.svg)](http://pkg.julialang.org/?pkg=JavaCall) [![JavaCall](http://pkg.julialang.org/badges/JavaCall_0.4.svg)](http://pkg.julialang.org/?pkg=JavaCall) [![JavaCall](http://pkg.julialang.org/badges/JavaCall_0.5.svg)](http://pkg.julialang.org/?pkg=JavaCall)
 [![JavaCall](http://pkg.julialang.org/badges/JavaCall_0.6.svg)](http://pkg.julialang.org/?pkg=JavaCall)


Call Java programs from Julia.

Documentation is available at http://juliainterop.github.io/JavaCall.jl


**JavaCall and it's derivatives do not work correctly Julia 1.1 and Julia 1.2. On Julia 1.3, please set the environment variable `JULIA_COPY_STACKS`. On 1.1 and 1.2, and on 1.3 without `JULIA_COPY_STACKS` set, you may see segfaults or incorrect results. This is typically due to stack corruption. The Julia long-term-support version of 1.0.x continues to work correctly as before. **
