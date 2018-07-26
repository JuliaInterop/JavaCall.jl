module JavaCall
export JavaObject, JavaMetaClass,
       jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
       JObject, JClass, JMethod, JString,
       @jimport, jcall, jfield, isnull,
       getname, getclass, listmethods, getreturntype, getparametertypes, classforname,
       narrow

using Compat, Compat.Dates

using Compat.Sys: iswindows, islinux, isunix, isapple

import DataStructures: OrderedSet

if VERSION < v"0.7-"
    using Compat: @warn
    import Base: isnull
    Base.finalizer(f::Function, o) = Base.finalizer(o, f)
else
    using Libdl
end

@static if iswindows()
    using WinReg
end


import Base: convert, unsafe_convert, unsafe_string


include("jnienv.jl")
include("jvm.jl")
include("core.jl")
include("convert.jl")
include("reflect.jl")

function __init__()
	findjvm()
	global create = Libdl.dlsym(libjvm, :JNI_CreateJavaVM)
end


end # module
