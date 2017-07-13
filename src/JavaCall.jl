module JavaCall
export JavaObject, JavaMetaClass,
       jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
       JObject, JClass, JMethod, JString,
       @jimport, jcall, jfield, isnull,
       getname, listmethods, getreturntype, getparametertypes, classforname

using Base.Dates

import DataStructures: OrderedSet

@static if is_windows()
    using WinReg
end


import Base.convert, Base.isnull, Base.unsafe_convert, Base.unsafe_string


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
