module JavaCall

export JObject, JClass, JString, jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
	   @jvimport, jcall

import Base.bytestring, Base.convert

const JNI_VERSION_1_1 =  convert(Cint, 0x00010001)
const JNI_VERSION_1_2 =  convert(Cint, 0x00010002)
const JNI_VERSION_1_4 =  convert(Cint, 0x00010004)
const JNI_VERSION_1_6 =  convert(Cint, 0x00010006)

const JNI_TRUE = convert(Cchar, 1)
const JNI_FALSE = convert(Cchar, 0)

# Return Values
const JNI_OK           = convert(Cint, 0)               #/* success */
const JNI_ERR          = convert(Cint, -1)              #/* unknown error */
const JNI_EDETACHED    = convert(Cint, -2)              #/* thread detached from the VM */
const JNI_EVERSION     = convert(Cint, -3)              #/* JNI version error */
const JNI_ENOMEM       = convert(Cint, -4)              #/* not enough memory */
const JNI_EEXIST       = convert(Cint, -5)              #/* VM already created */
const JNI_EINVAL       = convert(Cint, -6)              #/* invalid arguments */

# jni_md.h
typealias jint Cint
#ifdef _LP64 /* 64-bit Solaris */
# typedef long jlong;
typealias jlong Clonglong
typealias jbyte Cchar
 
# jni.h

typealias jboolean Cuchar
typealias jchar Cushort
typealias jshort Cshort
typealias jfloat Cfloat
typealias jdouble Cdouble
typealias jsize jint
typealias jobject Ptr{Void}


libjvm=dlopen("/Library/Java/JavaVirtualMachines/jdk1.7.0_45.jdk/Contents/Home/jre/lib/server/libjvm")
create = dlsym(libjvm, :JNI_CreateJavaVM)

# typedef struct JavaVMInitArgs {
#     jint version;

#     jint nOptions;
#     JavaVMOption *options;
#     jboolean ignoreUnrecognized;
# } JavaVMInitArgs;

immutable JavaVMInitArgs
	version::Cint
	nOptions::Cint
	options::Ptr{Void}
	ignoreUnrecognized::Cchar
end

# typedef struct JavaVMOption {
#     char *optionString;
#     void *extraInfo;
# } JavaVMOption;

immutable JavaVMOption 
	optionString::Ptr{Uint8}
	extraInfo::Ptr{Void}
end

include("jnienv.jl")


function initjava{T<:String}(opts::Array{T, 1}) 
	opt = Array(Ptr{Void}, 1)
	opt[1]=pointer_from_objref(JavaVMOption(convert(Ptr{Uint8}, "-Djava.class.path=/Users/aviks/dev"), C_NULL))
	ppjvm=Array(Ptr{Void},1)
	ppenv=Array(Ptr{JNIEnv},1)
	vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, 1), pointer_from_objref(opt), JNI_TRUE)

	ccall(create, Cint, (Ptr{Ptr{Void}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv, &vm_args)
	global penv = ppenv[1]
	global pjvm = ppjvm[1]
	jnienv=unsafe_load(penv)
	global jnifunc = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
	@assert ccall(jnifunc.GetVersion, Cint, (Ptr{JNIEnv},), penv) == JNI_VERSION_1_6
end


immutable JString
	ptr::Ptr{Void}
end

function JString(str::String)
	jstring = ccall(jnifunc.NewStringUTF, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, utf8(str))
	if jstring == C_NULL
		javaerror()
	else 
		return JString(jstring)
	end
end


immutable JClass{T}
	name::UTF8String
	ptr::Ptr{Void}
end

JClass(T, name, ptr) = JClass{T}(name,ptr)

abstract JObject


# function JClass(clazz::String)
# 	modifiedClazz = utf8(replace(clazz, '.', '/'))
# 	jclass = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, modifiedClazz)
# 	return JClass(modifiedClazz, jclass)
# end

# new{T<:JClass}(clazz::T, argtypes::Tuple, args...) = jcall(clazz, "<init>", Void, argtypes, args...)
global const METACLASS_CACHE = Dict{Type, JClass}()

macro jvimport(clazz)
	modifiedClazz = utf8(replace(string(clazz), '.', '/'))
	juliaClazz = string("jv_",replace(modifiedClazz, '/', '_'))
	if juliaClazz in JavaCall.METACLASS_CACHE
		return
	end 

	quote
		immutable $(symbol(juliaClazz)) <: JObject
			metaclass::JClass
			ptr::Ptr{Void}
		end

		$(esc(symbol(juliaClazz)))(argtypes::Tuple, args...) = jnew($(esc(symbol(juliaClazz))), argtypes, args...)

		jclass = eval(Expr(:ccall, :(JavaCall.jnifunc.FindClass), :(Ptr{Void}), :(Ptr{JavaCall.JNIEnv},Ptr{Uint8}), :(JavaCall.penv), $modifiedClazz))  
		if (jclass == C_NULL); error(string("Unable to create java class ", $(modifiedClazz))); end 
		METACLASS_CACHE[$(esc(symbol(juliaClazz)))] = JClass($(esc(symbol(juliaClazz))), $(modifiedClazz), jclass)
		$(esc(symbol(juliaClazz)))
	end

end

jnew{T<:JObject} (typ::Type{T}, argtype::Tuple, args...) = jcall(typ, "<init>", Ptr{Void}, argtypes, args...)	


# Convert a reference to a java.lang.String into a Julia string. Copies the underlying byte buffer
function bytestring(jstr::JString)  #jstr must be a jstring obtained via a JNI call
	pIsCopy = Array(jbyte, 1)
	buf::Ptr{Uint8} = ccall(jnifunc.GetStringUTFChars, Ptr{Uint8}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jbyte}), penv, jstr.ptr, pIsCopy)
	s=bytestring(buf)
	ccall(jnifunc.ReleaseStringUTFChars, Void, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}), penv, jstr.ptr, buf)
	return s
end

function javaerror()
	isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

	if isexception == JNI_TRUE
		ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv )
		jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Void}, (Ptr{JNIEnv},), penv)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved"); end
		jclass = ccall(jnifunc.GetObjectClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}), penv, jthrow)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved");end
		msg = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, jclass, utf8("getMessage"), utf8("()Ljava/lang/String;"))
		ccall(jnifunc.ExceptionClear, Void, (Ptr{JNIEnv},), penv )

		error(string("Error calling Java: ",bytestring(JString(msg))))
	else 
		error("Error calling Java, but no exception details could be retrieved")
	end
end


callMethod(rettype::Type{Array}) = jnifunc.CallObjectMethod
callMethod(rettype::Type{jint}) = jnifunc.CallIntMethod
callMethod(rettype::Type{jlong}) = jnifunc.CallLongMethod
callMethod(rettype::Type{jshort}) = jnifunc.CallShortMethod
callMethod(rettype::Type{jfloat}) = jnifunc.CallFloatMethod
callMethod(rettype::Type{jdouble}) = jnifunc.CallDoubleMethod
callMethod(rettype::Type{jchar}) = jnifunc.CallCharMethod
callMethod(rettype::Type{jboolean}) = jnifunc.CallByteMethod
callMethod(rettype::Type{JObject}) = jnifunc.CallObjectMethod

staticCallMethod(rettype::Type{Array}) = jnifunc.CallStaticObjectMethod
staticCallMethod(rettype::Type{jint}) = jnifunc.CallStaticIntMethod
staticCallMethod(rettype::Type{jlong}) = jnifunc.CallStaticLongMethod
staticCallMethod(rettype::Type{jshort}) = jnifunc.CallStaticShortMethod
staticCallMethod(rettype::Type{jfloat}) = jnifunc.CallStaticFloatMethod
staticCallMethod(rettype::Type{jdouble}) = jnifunc.CallStaticDoubleMethod
staticCallMethod(rettype::Type{jchar}) = jnifunc.CallStaticCharMethod
staticCallMethod(rettype::Type{jboolean}) = jnifunc.CallStaticByteMethod
staticCallMethod(rettype::Type{JObject}) = jnifunc.CallStaticObjectMethod


function jcall{T}(class::Type{T}, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)

	jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, METACLASS_CACHE[class].ptr, utf8(method), sig)
	callMethod = staticCallMethod(rettype)

	sargtypes = [symbol(string(real_jtype(x))) for x in argtypes]
	argtuple = Expr(:tuple, :(Ptr{JNIEnv}), :(Ptr{Void}), :(Ptr{Void}), sargtypes...)
	realArgs = convert_args(argtypes, args...)
	realret = real_jtype(rettype)
	# result = eval(:(ccall( $(callMethod), $(realret), (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void} ), $(penv), $(METACLASS_CACHE[class].ptr), $(jmethodId), $(realArgs))))
	result = eval(:(ccall( $(callMethod), $(realret), $(argtuple), $(penv), $(METACLASS_CACHE[class].ptr), $(jmethodId), $(realArgs...))))

	return jv_convert_result(rettype, result)

end

function jcall(obj::JObject, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, obj.ptr, utf8(method), sig)
	callMethod = callStaticMethod(rettype)

	sargtypes = [symbol(string(real_jtype(x))) for x in argtypes]
	argtuple = Expr(:tuple, :Ptr{JNIEnv}, :Ptr{Void}, :Ptr{Void}, sargtypes...)
	realArgs = convert_args(argtypes, args...)
	realret = real_rettype(rettype)
	# result = eval( :(ccall(callMethod, $(realret), (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void} ), $(penv), $(obj.ptr), $(jmethodId), $(realArgs))))
	result = eval( :(ccall(callMethod, $(realret), $(argtuple), $(penv), $(obj.ptr), $(jmethodId), $(realArgs...))))

	return jv_convert_result(rettype, result)

end


function real_jtype(rettype)
	if issubtype(rettype, JObject) || issubtype(rettype, JString) || issubtype(rettype, Array) || issubtype(rettype, JClass)
		realret = Ptr{Void}
	else 
		realret = rettype
	end
	return realret
end

function convert_args(argtypes::Tuple, args...)
	convertedArgs = {convert(argtypes[i], args[i]) for i in length(args)}
	# realArgs = Array(Ptr{Void},length(convertedArgs))
	# fill!(realArgs, C_NULL)
	# for i in 1:length(realArgs)
	# 	if argtypes[i] <: JObject || argtypes[i] <: JClass || argtypes[i] <: JString
	# 		realArgs[i] = convertedArgs[i].ptr
	# 	else 
	# 		realArgs[i] = convertedArgs[i]
	# 	end
	# end

	# return realArgs
end




function _jcall(obj::JObject, method::Ptr{Void}, rettype::Type, argtypes::Tuple, args)
	callMethod = callStaticMethod(rettype)
	
	if isa(rettype, JObject) || isa(rettype, JString) || isa(rettype, Array) || isa(rettype, JClass)
		realret = Ptr{Void}
	else 
		realret = retType
	end

	result = ccall(callMethod, realret, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void} ), 
										penv, obj.ptr, method,realArgs)

	return jv_convert_result(rettype, result)

end

jv_convert_result{T<:JString}(rettype::Type{T}, result) = bytestring(JString(result))
jv_convert_result{T<:Array}(rettype::Type{T}, result) = result
jv_convert_result(rettype, result) = result


function getMethodSignature(rettype, argtypes...)
	s=IOBuffer()
	write(s, "(")
	for arg in argtypes
		write(s, getSignature(arg))
	end
	write(s, ")")
	write(s, getSignature(rettype))
	return takebuf_string(s)
end



function getSignature(arg::Type)
	if is(Array, arg) 
		return string("[", getType(eltype(arg)))
	end
	if is(arg, jboolean)
		return "Z"
	elseif is(arg, jbyte)
		return "B"
	elseif is(arg, jchar)
		return "C"
	elseif is(arg, jint)
		return "I"
	elseif is(arg, jlong)
		return "J"
	elseif is(arg, jfloat)
		return "F"
	elseif is(arg, jdouble)
		return "D"
	elseif is(arg, Void) 
		return "V"
	end
end


getSignature{T<:JObject}(arg::Type{T}) = return string("L", arg.clazz, ";")

end # module
