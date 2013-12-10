module JavaCall
export JObject, JClass, JString, jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
	   @jvimport, jcall

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

# typealias jobject Ptr{Void}


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

# libjvm=dlopen("/Library/Java/JavaVirtualMachines/jdk1.7.0_45.jdk/Contents/Home/jre/lib/server/libjvm")
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


function destroy()
	if (!isdefined(JavaCall, :penv) || penv == C_NULL) ; error("Called destroy without initialising Java VM"); end
	res = ccall(jvmfunc.DestroyJavaVM, Cint, (Ptr{Void},), pjvm)
	if res < 0; error("Unable to destroy Java VM"); end
	global penv=C_NULL; global pjvm=C_NULL; 
end

immutable JClass{T}
	ptr::Ptr{Void}
end

JClass(T, ptr) = JClass{T}(ptr)

immutable JObject{T}
	ptr::Ptr{Void}
	metaclass::JClass{T}

	function JObject(ptr)
		new(ptr, getMetaClass(T))
	end 

	JObject(argtypes::Tuple, args...) = jnew(T, argtypes, args...)

end

JObject(T, ptr) = JObject{T}(ptr)

typealias JString JObject{:java!lang!String}

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


global const METACLASS_CACHE = Dict{Type, JClass}()

macro jvimport(clazz)
	juliaClazz = utf8(replace(clazz, '.', '!'))
	quote 
	   JObject{(Base.symbol($juliaClazz))}
	end

end

function jnew(T::Symbol, argtypes::Tuple, args...) 
	sig = getMethodSignature(Void, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, getMetaClass(T).ptr, utf8("<init>"), sig)
	if (jmethodId == C_NULL) 
		error("No constructor for $typ with signature $sig")
	end 
	return  _jcall(getMetaClass(T), jmethodId, jnifunc.NewObjectA, JObject{T}, argtypes, args...)
end

@memoize function getMetaClass(class::Symbol)
	jclass=javaclassname(class)
	jclassptr = ccall(JavaCall.jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, jclass)
	if jclassptr == C_NULL; error("Class Not Found $jclass"); end
	return JClass(class, jclassptr)
end

javaclassname(class::Symbol) = utf8(replace(string(class), '!', '/'))

function get_error()
	isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

	if isexception == JNI_TRUE
		#ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv )
		jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Void}, (Ptr{JNIEnv},), penv)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
	 	jclass = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv},Ptr{Uint8}), penv, "java/lang/Throwable")
		if jclass==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		jmethodId=ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, jclass, "toString", "()Ljava/lang/String;")
		if jmethodId==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		res = ccall(jnifunc.CallObjectMethod, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, jthrow, jmethodId)
		if res==C_NULL; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		msg = bytestring(JString(res))
		ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv )
		ccall(jnifunc.ExceptionClear, Void, (Ptr{JNIEnv},), penv )

		error(string("Error calling Java: ",msg))
	else 
		error("Error calling Java, but no exception details could be retrieved from the JVM")
	end
end


callMethod(rettype::Type{Array}) = jnifunc.CallObjectMethodA
callMethod(rettype::Type{jint}) = jnifunc.CallIntMethodA
callMethod(rettype::Type{jlong}) = jnifunc.CallLongMethodA
callMethod(rettype::Type{jshort}) = jnifunc.CallShortMethodA
callMethod(rettype::Type{jfloat}) = jnifunc.CallFloatMethodA
callMethod(rettype::Type{jdouble}) = jnifunc.CallDoubleMethodA
callMethod(rettype::Type{jchar}) = jnifunc.CallCharMethodA
callMethod(rettype::Type{jboolean}) = jnifunc.CallByteMethodA
callMethod{T}(rettype::Type{JObject{T}}) = jnifunc.CallObjectMethodA

staticCallMethod(rettype::Type{Array}) = jnifunc.CallStaticObjectMethodA
staticCallMethod(rettype::Type{jint}) = jnifunc.CallStaticIntMethodA
staticCallMethod(rettype::Type{jlong}) = jnifunc.CallStaticLongMethodA
staticCallMethod(rettype::Type{jshort}) = jnifunc.CallStaticShortMethodA
staticCallMethod(rettype::Type{jfloat}) = jnifunc.CallStaticFloatMethodA
staticCallMethod(rettype::Type{jdouble}) = jnifunc.CallStaticDoubleMethodA
staticCallMethod(rettype::Type{jchar}) = jnifunc.CallStaticCharMethodA
staticCallMethod(rettype::Type{jboolean}) = jnifunc.CallStaticByteMethodA
staticCallMethod{T}(rettype::Type{JObject{T}}) = jnifunc.CallStaticObjectMethodA


arrayCallMethod(rettype::Type{Array}) = jnifunc.GetObjectArrayElement
arrayCallMethod(rettype::Type{jint}) = jnifunc.GetIntArrayElement
arrayCallMethod(rettype::Type{jlong}) = jnifunc.GetLongArrayElement
arrayCallMethod(rettype::Type{jshort}) = jnifunc.GetShortArrayElement
arrayCallMethod(rettype::Type{jfloat}) = jnifunc.GetFloatArrayElement
arrayCallMethod(rettype::Type{jdouble}) = jnifunc.GetDoubleArrayElement
arrayCallMethod(rettype::Type{jchar}) = jnifunc.GetCharArrayElement
arrayCallMethod(rettype::Type{jboolean}) = jnifunc.GetByteArrayElement
arrayCallMethod{T}(rettype::Type{JObject{T}}) = jnifunc.GetObjectArrayElement


# Call static methods
function jcall{T}(typ::Type{JObject{T}}, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)

	jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, getMetaClass(T).ptr, utf8(method), sig)
	if jmethodId==C_NULL; get_error(); end
	callmethod = staticCallMethod(rettype)

	_jcall(getMetaClass(T), jmethodId, callmethod, rettype, argtypes, args...)

end

# Call instance methods
function jcall(obj::JObject, method::String, rettype::Type, argtypes::Tuple, args... )
	sig = getMethodSignature(rettype, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, obj.metaclass.ptr, utf8(method), sig)
	if jmethodId==C_NULL; get_error(); end
	callmethod = callMethod(rettype)

	_jcall(obj, jmethodId, callmethod, rettype, argtypes, args...)
end

function _jcall(obj, jmethodId, callmethod, rettype, argtypes, args...)
	# sargtypes = [symbol(string(real_jtype(x))) for x in argtypes]
	
	@assert obj.ptr != C_NULL
	@assert jmethodId != C_NULL
	@assert callmethod != C_NULL
	sargtypes = Array(Any, length(argtypes))
	for i in 1:length(argtypes)
		s=real_jtype(argtypes[i])
		if is(s, Ptr{Void})
			sargtypes[i]=:(Ptr{Void})
		else 
			sargtypes[i] = symbol(string(s))
		end
	end
	argtuple = Expr(:tuple, :(Ptr{JNIEnv}), :(Ptr{Void}), :(Ptr{Void}), sargtypes...)
	realArgs = convert_args(argtypes, args...)
	realret = real_jtype(rettype)
	# println(callmethod); println(realret); dump(argtuple); println(realArgs);

	#result = eval( :(ccall( $(callmethod), $(realret), $(argtuple), $(penv), $(obj.ptr), $(jmethodId), $(realArgs...))))

	#result = ccall(callmethod, realret, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, realArgs)

	# result = eval( :(ccall( $(callmethod), $(realret), (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), $(penv), $(obj.ptr), $(jmethodId), $(realArgs))))
	result = __jcall(obj, callmethod, realret, jmethodId, realArgs)
	if result==C_NULL; get_error(); end
	return jv_convert_result(rettype, result)

end

for i in (:jboolean, :jchar, :jshort, :jint, :jlong, :jfloat, :jdouble)
	m = quote
		__jcall(obj, callmethod::Ptr{Void}, realret::Type{$(i)}, jmethodId::Ptr{Void}, realArgs::Array{Int64, 1} ) =  
				ccall(callmethod, $i , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, realArgs)
	end
	eval(m)
end

__jcall(obj, callmethod::Ptr{Void}, realret::Type{Ptr{Void}}, jmethodId::Ptr{Void}, realArgs::Array{Int64, 1} ) =  
				ccall(callmethod, Ptr{Void} , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, realArgs)

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(int(v))

# Get the JNI/C type for a particular Java type
function real_jtype(rettype)
	if issubtype(rettype, JObject) || issubtype(rettype, Array) || issubtype(rettype, JClass)
		realret = Ptr{Void}
	else 
		realret = rettype
	end
	return realret
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
convert_arg{T<:JObject}(argtype::Type{T}, arg) = convert(T, arg).ptr
function convert_arg{T, N}(argtype::Type{Array{T,N}})

end


jv_convert_result{T<:JString}(rettype::Type{T}, result) = bytestring(JString(result))
jv_convert_result{T<:JObject}(rettype::Type{T}, result) = T(result)
jv_convert_result(rettype, result) = result
function jv_convert_result{T<:jprimitive,N}(rettype::Type{Array{T,1}}, result) 
	sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, d)
	arraymethod = arrayCallMethod(T)
	release_arraymethod = arrayReleaseCallMethod(T)
	jtype = real_jtype(T)
	r = Expr(:curly, :Ptr, symbol(string(T)))
	arr = eval( :(ccall(arraymethod, $(rettype), (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean} ), penv, result, C_NULL )) )
	jl_arr = pointer_to_array(arr, sz, false)
	jl_arr = copy(jl_arr)
	release_tuple = Expr(:tuple, :(Ptr{JNIEnv}), r, symbol(string(T)), :jint)
	eval(:(ccall($(release_arraymethod), Void, $(release_tuple), $(penv), $(arr), $(convert(Cint,0))  )))
end

function jv_convert_result{T<:JObject,N}(rettype::Type{Array{T,N}}, result) 
	sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, d)

	d=result
	s={}
	for i=1:N
		if d==C_NULL 
			push!(s,int64(0))
			continue
		else 
			sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, d)
			push!(s, int64(sz))
		end 
		d=ccall(jnifunc.GetObjectArrayElement, Ptr{Void}, (Ptr{JNIEnv},Ptr{Void}, Cint), penv, d, 0)
	end
	ret = Array(T, tuple(s))


	if N == 1
		d=result 
		for i=1:s[1]
			a=ccall(jnifunc.GetObjectArrayElement, Ptr{Void}, (Ptr{JNIEnv},Ptr{Void}, Cint), penv, d, 0)
			ret[i] = convert_result(T, a)
		end 
	end 

	if N == 2
		d=result 
		for i=1:s[1]
			d=
			for j=1:s[2]
				a=ccall(jnifunc.GetObjectArrayElement, Ptr{Void}, (Ptr{JNIEnv},Ptr{Void}, Cint), penv, d, i-1)
				ret[i] = convert_result(T, a)
			end
		end 
	end

	arraymethod = arrayCallMethod(T)
	release_arraymethod = arrayReleaseCallMethod(T)
	jtype = real_jtype(T)
	r = Expr(:curly, :Ptr, symbol(string(T)))
	arr = eval( :(ccall(arraymethod, $(rettype), (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean} ), penv, result, C_NULL )) )
	jl_arr = pointer_to_array(arr, sz, false)
	jl_arr = copy(jl_arr)
	release_tuple = Expr(:tuple, :(Ptr{JNIEnv}), r, symbol(string(T)), :jint)
	eval(:(ccall($(release_arraymethod), Void, $(release_tuple), $(penv), $(arr), $(convert(Cint,0))  )))
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
	if is(Array, arg) 
		return string("[", getSignature(eltype(arg)))
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

getSignature{T}(arg::Type{JObject{T}}) = return  is(arg, Void)?"V":string("L", javaclassname(T), ";")

# Pointer to pointer to pointer to pointer alert! Hurrah for unsafe load
function init{T<:String}(opts::Array{T, 1}) 
	opt = Array(JavaVMOption, length(opts))
	for i in 1:length(opts)
		opt[i]=JavaVMOption(convert(Ptr{Uint8}, opts[i]), C_NULL)
	end
	ppjvm=Array(Ptr{JavaVM},1)
	ppenv=Array(Ptr{JNIEnv},1)
	vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, length(opts)), convert(Ptr{JavaVMOption},opt), JNI_FALSE)

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



end # module
