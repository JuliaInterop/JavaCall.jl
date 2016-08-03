module JavaCall
export JavaObject, JavaMetaClass,
       jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
       JObject, JClass, JMethod, JString,
       @jimport, jcall, jfield, isnull,
       getname, listmethods, getreturntype, getparametertypes

using Base.Dates
using Compat
import Compat.String

@static if is_windows()
    using WinReg
end


import Base.convert, Base.isnull, Base.unsafe_convert

# if VERSION < v"0.5.0-dev+4612"
# 	const unsafe_string = Base.bytestring
# else
# 	const unsafe_string = Base.unsafe_string
# end

if VERSION < v"0.5.0-dev+4612"
    import Compat.unsafe_string
else
    import Base.unsafe_string
end


include("jvm.jl")
include("jnienv.jl")
include("core.jl")
include("convert.jl")
include("reflect.jl")

function __init__()
	findjvm()
	global create = Libdl.dlsym(libjvm, :JNI_CreateJavaVM)
end


end # module
