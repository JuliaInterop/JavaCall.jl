module JavaCall
export JavaObject, JavaMetaClass,
       jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
       JObject, JClass, JMethod, JString,
       @jimport, jcall, jfield, isnull,
       getname, getclass, listmethods, getreturntype, getparametertypes, classforname,
       narrow

# using Compat, Compat.Dates

# using Sys: iswindows, islinux, isunix, isapple

import DataStructures: OrderedSet
using Dates

@static if Sys.iswindows()
    using WinReg
end


import Base: convert, unsafe_convert, unsafe_string

JULIA_COPY_STACKS = false

include("JNI.jl")
using .JNI
include("jvm.jl")
include("core.jl")
include("convert.jl")
include("reflect.jl")

function __init__()
    global JULIA_COPY_STACKS = get(ENV, "JULIA_COPY_STACKS", "") ∈ ("1", "yes")
    if ! Sys.iswindows()
        # On Windows, JULIA_COPY_STACKS is not needed and causes crash
        if VERSION ≥ v"1.1-" && VERSION < v"1.3-"
            @warn("JavaCall does not work correctly on Julia v$VERSION. \n" *
                    "Either use Julia v1.0.x, or v1.3.0 or higher.\n"*
                    "For 1.3 onwards, please also set the environment variable `JULIA_COPY_STACKS` to be `1` or `yes`")
        end
        if VERSION ≥ v"1.3-" && ! JULIA_COPY_STACKS
            @warn("JavaCall needs the environment variable `JULIA_COPY_STACKS` to be `1` or `yes`.\n"*
                  "Calling the JVM may result in undefined behavior.")
        end
    end
end


end # module
