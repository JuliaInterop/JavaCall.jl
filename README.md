# JavaCall

<!-- [![Build Statusi v0.7](https://travis-ci.com/JuliaInterop/JavaCall.jl.png?branch=v0.7)](https://travis-ci.com/github/JuliaInterop/JavaCall.jl) -->
<!-- [![Build Status master](https://travis-ci.com/JuliaInterop/JavaCall.jl.svg)](https://travis-ci.com/github/JuliaInterop/JavaCall.jl) -->
[![Build status](https://ci.appveyor.com/api/projects/status/qeu6ul9o9s6t5tiw?svg=true)](https://ci.appveyor.com/project/aviks/javacall-jl-6c24s)
[![Gitter](https://badges.gitter.im/JavaCall-jl/community.svg)](https://gitter.im/JavaCall-jl/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)


Call Java programs from Julia.

## Documentation

Documentation is available at http://juliainterop.github.io/JavaCall.jl

## Versions

* 0.7 branch is currently being maintained for bug fixes only.
* master branch is currently proposed to be v0.8.0.

## Non-Windows Operating Systems

_JavaCall and its derivatives do not work correctly on Julia 1.1 and Julia 1.2. On Julia 1.3, please set the environment variable `JULIA_COPY_STACKS`. On 1.1 and 1.2, and on 1.3 without `JULIA_COPY_STACKS` set, you may see segfaults or incorrect results. This is typically due to stack corruption. The Julia 1.0.x continues to work correctly as before._

For Julia pre-1.5, consider the [RootTaskRepl.jl](https://github.com/mkitti/RootTaskREPL.jl) package. With RootTaskREPL.jl, JavaCall is able to execute fine without the need of `JULIA_COPY_STACKS=1` with the exception of `@async` calls. Starting with the Julia 1.5, the REPL backend now runs on the root Task by default.

## Windows Operating System

Do not set the environmental variable `JULIA_COPY_STACKS`. To use `jcall` with `@async` start Julia in the following way:

```
$ julia -i -e "using JavaCall; JavaCall.init()"
```
