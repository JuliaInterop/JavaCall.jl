# JavaCall.jl

![master GHA CI](https://github.com/JuliaInterop/JavaCall.jl/actions/workflows/CI.yml/badge.svg)

Call Java programs from [Julia](https://julialang.org).

## Documentation

Documentation is available at http://juliainterop.github.io/JavaCall.jl

## Quick Start Example Usage

```julia
$ JULIA_NUM_THREADS=1 JULIA_COPY_STACKS=1 julia

julia> using Pkg; Pkg.activate(; temp = true)
  Activating new project at `/tmp/jl_e6uPja`

julia> using JavaCall
 │ Package JavaCall not found, but a package named JavaCall is available from a
 │ registry. 
 │ Install package?
 │   (jl_e6uPja) pkg> add JavaCall 
 └ (y/n) [y]: y

...

julia> JavaCall.addClassPath(pwd()) # Set appropriate classpath

julia> JavaCall.addOpts("-Xmx1024M") # Use 1 GB of memory
OrderedCollections.OrderedSet{String} with 1 element:
  "-Xmx1024M"

julia> JavaCall.addOpts("-Xrs") # Disable signal handling in the JVM, reducing performance but enhancing compatability
OrderedCollections.OrderedSet{String} with 2 elements:
  "-Xmx1024M"
  "-Xrs"

julia> JavaCall.init() # Call before using `jcall` or `jfield`. Do not use this in package `__init__()` to allow other packages to add classpaths or options.

julia> jls = @jimport java.lang.System
JavaObject{Symbol("java.lang.System")}

julia> out = jfield(jls, "out", @jimport java.io.PrintStream) # Third arg is optional, but helps type stability.
JavaObject{Symbol("java.io.PrintStream")}(JavaCall.JavaLocalRef(Ptr{Nothing} @0x0000000003ecda38))

julia> jcall(out, "println", Nothing, (JString,), "Hello World")
Hello World
```

## Julia version compatibility

The CI tests for Julia 1.6 as `min`, Julia LTS, and the latest stable release.

## macOS and Linux

For Julia 1.3 onwards, please set the environment variable `JULIA_COPY_STACKS = 1`.
For Julia 1.11 onwards, please also set `JULIA_NUM_THREADS = 1`

Multithreaded access to the JVM is supported as JavaCall version `0.8.0`, but doesn't work in recent Julia versions.

## Windows

Do not set the environmental variable `JULIA_COPY_STACKS` or set the variable to `0`.

To use `jcall` with `@async`, start Julia in the following way:

```
$ julia -i -e "using JavaCall; JavaCall.init()"
```

Windows currently lacks support for multithreaded access to the JVM.

## Other Operating Systems

JavaCall has not been tested on operating systems other than macOS, Windows, or Linux.
You should probably set the environment variable `JULIA_COPY_STACKS = 1` and `JULIA_NUM_THREADS = 1`.
If you have success using JavaCall on another operating system than listed above,
please create an issue or pull request to let us know about compatability.
