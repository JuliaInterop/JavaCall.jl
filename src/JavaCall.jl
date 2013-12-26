module JavaCall
export JavaObject, JClass, JString, jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble, JObject, 
	   @jvimport, jcall, deleteref

# using Debug
using Memoize

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
jprimitive = Union(jboolean, jchar, jshort, jfloat, jdouble, jint, jlong)

# typealias JObject Ptr{Void}


function findjvm()
	javahomes = {}
	libpaths = {}

	try 
		push!(libpath, ENV["JAVA_LIB"])
	catch 
		try 
			push!(javahomes, ENV["JAVA_HOME"])
		end
		@osx_only try 
			push!(javahomes, chomp(readall(`/usr/libexec/java_home`)))
		end
		@unix_only push!(javahomes, "/usr")

		libpaths = {""}
		for n in javahomes
			push!(libpaths, joinpath(n, "lib"))
			push!(libpaths, joinpath(n, "jre", "lib"))
			push!(libpaths, joinpath(n, "jre", "lib", "server"))
			@linux_only if WORD_SIZE==64; push!(libpaths, joinpath(n, "jre", "lib", "amd64", "server")); end
			@linux_only if WORD_SIZE==32; push!(libpaths, joinpath(n, "jre", "lib", "i386", "server")); end

		end
	end
	for n in libpaths
		try 
			global libjvm = dlopen(joinpath(n, "libjvm"))
			println("Found libjvm @ $n")
			return
		end
	end
	error ("Cannot find libjvm in: $(libpaths)To override the search, set the JAVA_LIB environment variable to the directory containing libjvm.{so,dll,dylib}")
end

findjvm()

create = dlsym(libjvm, :JNI_CreateJavaVM)

immutable JavaVMOption 
	optionString::Ptr{Uint8}
	extraInfo::Ptr{Void}
end

immutable JavaVMInitArgs
	version::Cint
	nOptions::Cint
	options::Ptr{JavaVMOption}
	ignoreUnrecognized::Cchar
end

include("jnienv.jl")


immutable JClass{T}
	ptr::Ptr{Void}
end

JClass(T, ptr) = JClass{T}(ptr)

type JavaObject{T}
	ptr::Ptr{Void}

	function JavaObject(ptr)
		j=new(ptr)
		finalizer(j, deleteref)
		return j
	end 

	JavaObject(argtypes::Tuple, args...) = jnew(T, argtypes, args...)

end

JavaObject(T, ptr) = JavaObject{T}(ptr)

typealias JString JavaObject{symbol("java.lang.String")}
typealias JObject JavaObject{symbol("java.lang.Object")}

function JString(str::String)
	jstring = ccall(jnifunc.NewStringUTF, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, utf8(str))
	if jstring == C_NULL
		get_error()
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

convert{T<:String}(::Type{JString}, str::T) = JString(str)
convert{T<:String}(::Type{JObject}, str::T) = convert(JObject, JString(str))
#Cast java object from S to T 
function convert{T,S}(::Type{JavaObject{T}}, obj::JavaObject{S}) 
	if (ccall(jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, getMetaClass(S).ptr, getMetaClass(T).ptr ) == JNI_TRUE)   #Safe static cast
			return JavaObject{T}(obj.ptr)
	end 
	realClass = ccall(jnifunc.GetObjectClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void} ), penv, obj.ptr)
	if (ccall(jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, realClass, getMetaClass(T).ptr ) == JNI_TRUE)  #dynamic cast
			return JavaObject{T}(obj.ptr)
	end 
	error("Cannot cast java object from $S to $T")
end

macro jvimport(class)
	if isa(class, Expr)
		juliaclass=sprint(Base.show_unquoted, class)
	elseif  isa(class, Symbol)
		juliaclass=string(class)
	elseif isa(class, String) 
		juliaclass=class
	else 
		error("Macro parameter is of type $(typeof(class))!!")
	end
	quote 
	   JavaObject{(Base.symbol($juliaclass))}
	end

end

function jnew(T::Symbol, argtypes::Tuple, args...) 
	sig = getMethodSignature(Void, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, getMetaClass(T).ptr, utf8("<init>"), sig)
	if (jmethodId == C_NULL) 
		error("No constructor for $typ with signature $sig")
	end 
	return  _jcall(getMetaClass(T), jmethodId, jnifunc.NewObjectA, JavaObject{T}, argtypes, args...)
end

@memoize function getMetaClass(class::Symbol)
	jclass=javaclassname(class)
	jclassptr = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, jclass)
	if jclassptr == C_NULL; error("Class Not Found $jclass"); end
	return JClass(class, jclassptr)
end

getMetaClass{T}(::Type{JavaObject{T}}) = getMetaClass(T)
getMetaClass{T}(::JavaObject{T}) = getMetaClass(T)

javaclassname(class::Symbol) = utf8(replace(string(class), '.', '/'))

function get_error()
	isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

	if isexception == JNI_TRUE
		jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Void}, (Ptr{JNIEnv},), penv)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
	 	jclass = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv},Ptr{Uint8}), penv, "java/lang/Throwable")
		if jclass==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		jmethodId=ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, jclass, "toString", "()Ljava/lang/String;")
		if jmethodId==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		res = ccall(jnifunc.CallObjectMethod, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, jthrow, jmethodId)
		if res==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		msg = bytestring(JString(res))
		ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv ) #Print java stackstrace to stdout
		ccall(jnifunc.ExceptionClear, Void, (Ptr{JNIEnv},), penv )

		error(string("Error calling Java: ",msg))
	else 
		error("Error calling Java, but no exception details could be retrieved from the JVM")
	end
end


# Call static methods
function jcall{T}(typ::Type{JavaObject{T}}, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)

	jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, getMetaClass(T).ptr, utf8(method), sig)
	if jmethodId==C_NULL; get_error(); end

	_jcall(getMetaClass(T), jmethodId, C_NULL, rettype, argtypes, args...)

end

# Call instance methods
function jcall(obj::JavaObject, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, getMetaClass(obj).ptr, utf8(method), sig)
	if jmethodId==C_NULL; get_error(); end

	_jcall(obj, jmethodId, C_NULL, rettype,  argtypes, args...)
end



#Generate these methods to satisfy ccall's compile time constant requirement
for (x, y, z) in [ (:jboolean, :(jnifunc.CallBooleanMethodA), :(jnifunc.CallStaticBooleanMethodA)),
					(:jchar, :(jnifunc.CallCharMethodA), :(jnifunc.CallStaticCharMethodA)),
					(:jshort, :(jnifunc.CallShortMethodA), :(jnifunc.CallStaticShortMethodA)),
					(:jint, :(jnifunc.CallIntMethodA), :(jnifunc.CallStaticShortMethodA)), 
					(:jlong, :(jnifunc.CallLongMethodA), :(jnifunc.CallStaticLongMethodA)),
					(:jfloat, :(jnifunc.CallFloatMethodA), :(jnifunc.CallStaticFloatMethodA)),
					(:jdouble, :(jnifunc.CallDoubleMethodA), :(jnifunc.CallStaticDoubleMethodA)) ]
	m = quote
		function _jcall(obj,  jmethodId::Ptr{Void}, callmethod::Ptr{Void}, rettype::Type{$(x)}, argtypes::Tuple, args... ) 
			 	if callmethod == C_NULL
			 		callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
			 	end
			 	@assert callmethod != C_NULL
			 	@assert obj.ptr != C_NULL
				@assert jmethodId != C_NULL
				result = ccall(callmethod, $x , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, convert_args(argtypes, args...))
				if result==C_NULL; get_error(); end
				return convert_result(rettype, result)
		end
	end
	eval(m)
end

function _jcall(obj,  jmethodId::Ptr{Void}, callmethod::Ptr{Void}, rettype::Type, argtypes::Tuple, args... ) 
		if callmethod == C_NULL
			callmethod = ifelse( typeof(obj)<:JavaObject, jnifunc.CallObjectMethodA , jnifunc.CallStaticObjectMethodA )
		end
		@assert callmethod != C_NULL
		@assert obj.ptr != C_NULL
		@assert jmethodId != C_NULL
		result = ccall(callmethod, Ptr{Void} , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, convert_args(argtypes, args...))
		if result==C_NULL; get_error(); end
		return convert_result(rettype, result)
end

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(int(v))

# Get the JNI/C type for a particular Java type
function real_jtype(rettype)
	if issubtype(rettype, JavaObject) || issubtype(rettype, Array) || issubtype(rettype, JClass)
		jnitype = Ptr{Void}
	else 
		jnitype = rettype
	end
	return jnitype
end


function convert_args(argtypes::Tuple, args...)
	convertedArgs = Array(Int64, length(args))
	for i in 1:length(args)
		convertedArgs[i] = jvalue(convert_arg(argtypes[i], args[i]))
	end
	return convertedArgs
end

convert_arg(argtype::Type{JString}, arg) = convert(JString, arg).ptr
convert_arg(argtype::Type, arg) = convert(argtype, arg)
convert_arg{T<:JavaObject}(argtype::Type{T}, arg) = convert(T, arg).ptr

for (x, y, z) in [ (:jboolean, :(jnifunc.NewBooleanArray), :(jnifunc.SetBooleanArrayRegion)),
					(:jchar, :(jnifunc.NewCharArray), :(jnifunc.SetCharArrayRegion)),
					(:jshort, :(jnifunc.NewShortArray), :(jnifunc.SetShortArrayRegion)),
					(:jint, :(jnifunc.NewIntArray), :(jnifunc.SetShortArrayRegion)), 
					(:jlong, :(jnifunc.NewLongArray), :(jnifunc.SetLongArrayRegion)),
					(:jfloat, :(jnifunc.NewFloatArray), :(jnifunc.SetFloatArrayRegion)),
					(:jdouble, :(jnifunc.NewDoubleArray), :(jnifunc.SetDoubleArrayRegion)) ]
 	m = quote 
  		function convert_arg(argtype::Type{Array{$x,1}}, arg)
			carg = convert(argtype, arg)
			sz=length(carg)
			arrayptr = ccall($y, Ptr{Void}, (Ptr{JNIEnv}, jint), penv, sz)
			ccall($z, Void, (Ptr{JNIEnv}, Ptr{Void}, jint, jint, Ptr{$x}), penv, arrayptr, 0, sz, carg)
			return arrayptr
		end
	end
	eval( m)
end

function convert_arg{T<:JavaObject}(argtype::Type{Array{T,1}}, arg)
	carg = convert(argtype, arg)
	sz=length(carg)
	init=carg[1]
	arrayptr = ccall(jnifunc.NewObjectArray, Ptr{Void}, (Ptr{JNIEnv}, jint, Ptr{Void}, Ptr{Void}), penv, sz, getMetaClass(T).ptr, init.ptr)
	for i=2:sz 
		ccall(jnifunc.SetObjectArrayElement, Void, (Ptr{JNIEnv}, Ptr{Void}, jint, Ptr{Void}), penv, arrayptr, i-1, carg[i].ptr)
	end
	return arrayptr
end

convert_result{T<:JString}(rettype::Type{T}, result) = bytestring(JString(result))
convert_result{T<:JavaObject}(rettype::Type{T}, result) = T(result)
convert_result(rettype, result) = result

for (x, y, z) in [ (:jboolean, :(jnifunc.GetBooleanArrayElements), :(jnifunc.ReleaseBooleanArrayElements)),
					(:jchar, :(jnifunc.GetCharArrayElements), :(jnifunc.ReleaseCharArrayElements)),
					(:jshort, :(jnifunc.GetShortArrayElements), :(jnifunc.ReleaseShortArrayElements)),
					(:jint, :(jnifunc.GetIntArrayElements), :(jnifunc.ReleaseIntArrayElements)), 
					(:jlong, :(jnifunc.GetLongArrayElements), :(jnifunc.ReleaseLongArrayElements)),
					(:jfloat, :(jnifunc.GetFloatArrayElements), :(jnifunc.ReleaseFloatArrayElements)),
					(:jdouble, :(jnifunc.GetDoubleArrayElements), :(jnifunc.ReleaseDoubleArrayElements)) ]
	m=quote
		function convert_result(rettype::Type{Array{$(x),1}}, result)
			sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, result)
			arr = ccall($(y), Ptr{$(x)}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean} ), penv, result, C_NULL ) 
			jl_arr::Array = pointer_to_array(arr, int(sz), false)
			jl_arr = deepcopy(jl_arr)
			ccall($(z), Void, (Ptr{JNIEnv},Ptr{Void}, Ptr{$(x)}, jint), penv, result, arr, 0)  
			return jl_arr
		end
	end
	eval(m)
end

function convert_result{T}(rettype::Type{Array{JavaObject{T},1}}, result) 
	sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, result)

	ret = Array(JavaObject{T}, sz)

	for i=1:sz
		a=ccall(jnifunc.GetObjectArrayElement, Ptr{Void}, (Ptr{JNIEnv},Ptr{Void}, jint), penv, result, i-1)
		ret[i] = JavaObject{T}(a)
	end 
	return ret
end


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
	elseif issubtype(arg, Array) 
		return string("[", getSignature(eltype(arg)))
	end
end

getSignature{T}(arg::Type{JavaObject{T}}) = string("L", javaclassname(T), ";")
immutable JavaVMAttachArgs 
    version::Cint      #/* must be JNI_VERSION_1_2 */
    name::Ptr{Void}   #/* the name of the thread as a modified UTF-8 string, or NULL */
    group::Ptr{Void}   #;/* global ref of a ThreadGroup object, or NULL */
end

function deleteref(x::JavaObject)
	if x.ptr == C_NULL; return; end
	if (penv==C_NULL); return; end
	ccall(jnifunc.DeleteLocalRef, Void, (Ptr{JNIEnv}, Ptr{Void}), penv, x.ptr)
	x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize 
	return
end 

# Pointer to pointer to pointer to pointer alert! Hurrah for unsafe load
function init{T<:String}(opts::Array{T, 1}) 
	opt = Array(JavaVMOption, length(opts))
	for i in 1:length(opts)
		opt[i]=JavaVMOption(convert(Ptr{Uint8}, opts[i]), C_NULL)
	end
	ppjvm=Array(Ptr{JavaVM},1)
	ppenv=Array(Ptr{JNIEnv},1)
	vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, length(opts)), convert(Ptr{JavaVMOption},opt), JNI_TRUE)

	res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv, &vm_args)
	if res < 0; error("Unable to initialise Java VM: $(res)"); end
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



end # module
