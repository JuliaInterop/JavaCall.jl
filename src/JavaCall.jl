module JavaCall
export JavaObject, JavaMetaClass,
       jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
       JObject, JClass, JMethod, JString,
       @jimport, jcall, jfield, isnull,
       getname, listmethods, getreturntype, getparametertypes

# using Debug
using Memoize
using Compat

import Base.bytestring, Base.convert

if VERSION < v"0.4.0-dev+656"
	import Compat.isnull
else
	import Base.isnull
end

if VERSION < v"0.4-"
	using Dates
else
	using Base.Dates
end

if VERSION < v"0.4-"
	const unsafe_convert = Base.convert
else
	const unsafe_convert = Base.unsafe_convert
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
