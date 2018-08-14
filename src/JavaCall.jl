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
import Libdl
using Dates

@static if Sys.iswindows()
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
