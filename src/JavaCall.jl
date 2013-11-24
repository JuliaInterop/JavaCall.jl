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

immutable JavaVMInitArgs
	version::Cint
	nOptions::Cint
	options::Ptr{Void}
	ignoreUnrecognized::Cchar
end


immutable JavaVMOption 
	optionString::Ptr{Uint8}
	extraInfo::Ptr{Void}
end

include("jnienv.jl")


function init{T<:String}(opts::Array{T, 1}) 
	opt = Array(Ptr{Void}, length(opts))
	for i in 1:length(opts)
		opt[i]=pointer_from_objref(JavaVMOption(convert(Ptr{Uint8}, opts[i]), C_NULL))
	end
	ppjvm=Array(Ptr{JavaVM},1)
	ppenv=Array(Ptr{JNIEnv},1)
	vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, length(opts)), pointer_from_objref(opt), JNI_TRUE)

	res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv, &vm_args)
	if res < 0; error("Unable to initialise Java VM"); end
	global penv = ppenv[1]
	global pjvm = ppjvm[1]
	jnienv=unsafe_load(penv)
	jvm = unsafe_load(pjvm)
	global jvmfunc = unsafe_load(jvm.JNIInvokeInterface_)
	global jnifunc = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
	@assert ccall(jnifunc.GetVersion, Cint, (Ptr{JNIEnv},), penv) == JNI_VERSION_1_6
end

function destroy()
	if (!isdefined(JavaCall, :penv) || penv == C_NULL) ; error("Called destroy without initialising Java VM"); end
	res = ccall(jvmfunc.DestroyJavaVM, Cint, (Ptr{Void},), pjvm)
	if res < 0; error("Unable to destroy Java VM"); end
	global penv=C_NULL; global pjvm=C_NULL; 
end

immutable JClass{T}
	name::UTF8String
	ptr::Ptr{Void}
end

JClass(T, name, ptr) = JClass{T}(name,ptr)

abstract JObject

immutable JString <: JObject
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
# Convert a reference to a java.lang.String into a Julia string. Copies the underlying byte buffer
function bytestring(jstr::JString)  #jstr must be a jstring obtained via a JNI call
	pIsCopy = Array(jbyte, 1)
	buf::Ptr{Uint8} = ccall(jnifunc.GetStringUTFChars, Ptr{Uint8}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jbyte}), penv, jstr.ptr, pIsCopy)
	s=bytestring(buf)
	ccall(jnifunc.ReleaseStringUTFChars, Void, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}), penv, jstr.ptr, buf)
	return s
end


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

function jnew{T<:JObject} (typ::Type{T}, argtype::Tuple, args...) 
	sig = getMethodSignature(Void, argtypes...)
	jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, METACLASS_CACHE[typ].ptr, utf8("<init>"), sig)
	
	_jcall(obj, jmethodId, "NewObject", T, argtypes, args...)

end


function javaerror()
	isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

	if isexception == JNI_TRUE
		ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv )
		jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Void}, (Ptr{JNIEnv},), penv)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved"); end
		jclass = ccall(jnifunc.GetObjectClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}), penv, jthrow)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved");end
		msg = jcall(jthrow, "getMessage", JString, ())
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


# Call static methods
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

# Call instance methods
function jcall(obj::JObject, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, obj.ptr, utf8(method), sig)
	callMethod = callStaticMethod(rettype)

	_jcall(obj, jmethodId, callmethod, rettype, argtypes, args...)
end

function _jcall(obj, jmethodId, callmethod, rettype, argtypes, args...)
	sargtypes = [symbol(string(real_jtype(x))) for x in argtypes]
	argtuple = Expr(:tuple, :Ptr{JNIEnv}, :Ptr{Void}, :Ptr{Void}, sargtypes...)
	realArgs = convert_args(argtypes, args...)
	realret = real_rettype(rettype)
	# result = eval( :(ccall(callMethod, $(realret), (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void} ), $(penv), $(obj.ptr), $(jmethodId), $(realArgs))))
	result = eval( :(ccall(callMethod, $(realret), $(argtuple), $(penv), $(obj.ptr), $(jmethodId), $(realArgs...))))

	return jv_convert_result(rettype, result)

end

# Get the JNI/C type for a particular Java type
function real_jtype(rettype)
	if issubtype(rettype, JObject) || issubtype(rettype, JString) || issubtype(rettype, Array) || issubtype(rettype, JClass)
		realret = Ptr{Void}
	else 
		realret = rettype
	end
	return realret
end

function convert_args(argtypes::Tuple, args...)
	convertedArgs = {convert(argtypes[i], args[i]) for i in 1:length(args)}
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
