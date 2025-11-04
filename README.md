# JavaCall.jl

![master GHA CI](https://github.com/JuliaInterop/JavaCall.jl/actions/workflows/CI.yml/badge.svg)

Call Java programs from Julia.

## Documentation

Documentation is available at http://juliainterop.github.io/JavaCall.jl

## Quick Start Example Usage

```julia
$ JULIA_COPY_STACKS=1 julia

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

Julia 1.3.0 through Julia 1.6.2 are tested and guaranteed to work on Linux, macOS, and Windows via continuous integration. Julia 1.6.2 and newer should work on Linux and Windows. The `JULIA_COPY_STACKS` environment variable should be set to `1` on macOS and Linux, but not Windows.

For Julia pre-1.5, consider the [RootTaskRepl.jl](https://github.com/mkitti/RootTaskREPL.jl) package. With RootTaskREPL.jl, JavaCall is able to execute fine without the need of `JULIA_COPY_STACKS=1` with the exception of `@async` calls. Starting with the Julia 1.5, the REPL backend now runs on the root Task by default.

JavaCall and its dependents do not work correctly on Julia 1.1 and Julia 1.2.  On Julia 1.1 and 1.2, you may see segfaults or incorrect results. This is typically due to stack corruption.

JavaCall should continue to work with Julia 1.0.x (formerly a long term support version of Julia).

## Apple macOS

JavaCall works on Julia 1.0 and Julia 1.3 to Julia 1.6.2. Please set the environment variable `JULIA_COPY_STACKS = 1`. 

As of Julia 1.6.3, JavaCall fails on macOS due to a fatal segmentation fault, signal (11). See [JavaCall#151](https://github.com/JuliaInterop/JavaCall.jl/issues/151) and [JuliaLang/julia#40056](https://github.com/JuliaLang/julia/pull/40056).

The current developers of JavaCall do not posess current Apple hardware to debug this issue. [Help is needed.](https://github.com/JuliaInterop/JavaCall.jl/issues/151)

Julia 1.0 and Julia 1.6.2 are tested via Github Actions continuous integration on macOS.

## Windows Operating System

Do not set the environmental variable `JULIA_COPY_STACKS` or set the variable to `0`.

To use `jcall` with `@async`, start Julia in the following way:

```
$ julia -i -e "using JavaCall; JavaCall.init()"
```

Windows currently lacks support for multithreaded access to the JVM.

Julia 1.0, 1.6, 1 (latest release), and nightly are tested on Windows via Github Actions continuous integration.
x86 compatability is also tested on the latest Julia 1 release.

## Linux

On Julia 1.3 and newer, please set the environment variable `JULIA_COPY_STACKS = 1`.

Multithreaded access to the JVM is supported as JavaCall version `0.8.0`.

Julia 1.0, 1.6, 1 (latest release), and nightly are tested on Linux via Github Actions continuous integration.

## Other Operating Systems

JavaCall has not been tested on operating systems other than macOS, Windows, or Linux.
You should probably set the environment variable `JULIA_COPY_STACKS = 1`.
If you have success using JavaCall on another operating system than listed above,
please create an issue or pull request to let us know about compatability.
