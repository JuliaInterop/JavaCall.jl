module JavaCall
export JavaObject, JavaMetaClass, JString, jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble, JObject, 
	   @jimport, jcall, isnull

# using Debug
using Memoize
using Compat

import Base.bytestring, Base.convert

if VERSION < v"0.4.0-dev+656"
	import Compat.isnull
else 
	import Base.isnull
end

const JNI_VERSION_1_1 =  convert(Cint, 0x00010001)
const JNI_VERSION_1_2 =  convert(Cint, 0x00010002)
const JNI_VERSION_1_4 =  convert(Cint, 0x00010004)
const JNI_VERSION_1_6 =  convert(Cint, 0x00010006)
const JNI_VERSION_1_8 =  convert(Cint, 0x00010008)

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

@unix_only global const libname = "libjvm"
@windows_only global const libname = "jvm"
function findjvm()
    javahomes = Any[]
    libpaths = Any[]

    if haskey(ENV,"JAVA_HOME")
        push!(javahomes,ENV["JAVA_HOME"])
    end
    if isexecutable("/usr/libexec/java_home")
        push!(javahomes,chomp(readall(`/usr/libexec/java_home`)))
    end

    if isdir("/usr/lib/jvm/default-java/")
        push!(javahomes, "/usr/lib/jvm/default-java/")
    end

    push!(libpaths,pwd())
    for n in javahomes
        @windows_only push!(libpaths, joinpath(n, "jre", "bin", "server"))
        @linux_only if WORD_SIZE==64; push!(libpaths, joinpath(n, "jre", "lib", "amd64", "server")); end
        @linux_only if WORD_SIZE==32; push!(libpaths, joinpath(n, "jre", "lib", "i386", "server")); end
        push!(libpaths, joinpath(n, "jre", "lib", "server"))
    end
    
    ext = "."*@windows? "dll":@osx? "dylib":"so"
    try 
        for n in libpaths
            libpath = joinpath(n,libname*ext);
            if isreadable(libpath) 
                global libjvm = Libdl.dlopen(libpath)
                println("Loaded $libpath")
                return
            end
        end
    end

    errorMsg =
    [ 
        "Cannot find java library $libname$ext\n",
        "Search Path:"
    ];
    for path in libpaths
       push!(errorMsg,"\n   $path")
    end
    error(reduce(*,errorMsg));
end

findjvm()

create = Libdl.dlsym(libjvm, :JNI_CreateJavaVM)

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


immutable JavaMetaClass{T}
	ptr::Ptr{Void}
end

#The metaclass, sort of equivalent to a java.lang.Class<T>
JavaMetaClass(T, ptr) = JavaMetaClass{T}(ptr)

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
		geterror()
	else 
		return JString(jstring)
	end
end
# Convert a reference to a java.lang.String into a Julia string. Copies the underlying byte buffer
function bytestring(jstr::JString)  #jstr must be a jstring obtained via a JNI call
	if isnull(jstr); return ""; end #Return empty string to keep type stability. But this is questionable
	pIsCopy = Array(jboolean, 1)
	buf::Ptr{Uint8} = ccall(jnifunc.GetStringUTFChars, Ptr{Uint8}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean}), penv, jstr.ptr, pIsCopy)
	s=bytestring(buf)
	ccall(jnifunc.ReleaseStringUTFChars, Void, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}), penv, jstr.ptr, buf)
	return s
end

convert{T<:String}(::Type{JString}, str::T) = JString(str)
convert{T<:String}(::Type{JObject}, str::T) = convert(JObject, JString(str))

#Cast java object from S to T . Needed for polymorphic calls
function convert{T,S}(::Type{JavaObject{T}}, obj::JavaObject{S}) 
	if (ccall(jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, metaclass(S), metaclass(T) ) == JNI_TRUE)   #Safe static cast
			return JavaObject{T}(obj.ptr)
	end 
	if isnull(obj) ; error("Cannot convert NULL"); end
	realClass = ccall(jnifunc.GetObjectClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void} ), penv, obj.ptr)
	if (ccall(jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, realClass, metaclass(T) ) == JNI_TRUE)  #dynamic cast
			return JavaObject{T}(obj.ptr)
	end 
	error("Cannot cast java object from $S to $T")
end

macro jimport(class)
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
	sig = method_signature(Void, argtypes...)
	jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, metaclass(T), utf8("<init>"), sig)
	if (jmethodId == C_NULL) 
		error("No constructor for $T with signature $sig")
	end 
	return  _jcall(metaclass(T), jmethodId, jnifunc.NewObjectA, JavaObject{T}, argtypes, args...)
end

isnull(obj::JavaObject) = obj.ptr == C_NULL
isnull(obj::JavaMetaClass) = obj.ptr == C_NULL

@memoize function metaclass(class::Symbol)
	jclass=javaclassname(class)
	jclassptr = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, jclass)
	if jclassptr == C_NULL; error("Class Not Found $jclass"); end
	return JavaMetaClass(class, jclassptr)
end

metaclass{T}(::Type{JavaObject{T}}) = metaclass(T)
metaclass{T}(::JavaObject{T}) = metaclass(T)

javaclassname(class::Symbol) = utf8(replace(string(class), '.', '/'))

function geterror(allow=false)
	isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

	if isexception == JNI_TRUE
		jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Void}, (Ptr{JNIEnv},), penv)
		if jthrow==C_NULL ; error ("Java Exception thrown, but no details could be retrieved from the JVM"); end
		ccall(jnifunc.ExceptionDescribe, Void, (Ptr{JNIEnv},), penv ) #Print java stackstrace to stdout
		ccall(jnifunc.ExceptionClear, Void, (Ptr{JNIEnv},), penv )
	 	jclass = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv},Ptr{Uint8}), penv, "java/lang/Throwable")
		if jclass==C_NULL; error("Java Exception thrown, but no details could be retrieved from the JVM"); end
		jmethodId=ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, jclass, "toString", "()Ljava/lang/String;")
		if jmethodId==C_NULL; error("Java Exception thrown, but no details could be retrieved from the JVM"); end
		res = ccall(jnifunc.CallObjectMethodA, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, jthrow, jmethodId,C_NULL)
		if res==C_NULL; error("Java Exception thrown, but no details could be retrieved from the JVM"); end
		msg = bytestring(JString(res))
                ccall(jnifunc.DeleteLocalRef, Void, (Ptr{JNIEnv}, Ptr{Void}), penv, jthrow)
		error(string("Error calling Java: ",msg))
	else
		if allow==false
			return #No exception pending, legitimate NULL returned from Java
		else
			error("Null from Java. Not known how")
		end
	end
end

if VERSION < v"0.4-"
	const unsafe_convert = Base.convert
else
	const unsafe_convert = Base.unsafe_convert
end
unsafe_convert(::Type{Ptr{Void}}, cls::JavaMetaClass) = cls.ptr

# Call static methods
function jcall{T}(typ::Type{JavaObject{T}}, method::String, rettype::Type, argtypes::Tuple, args... )
	try
		gc_enable(false)
		sig = method_signature(rettype, argtypes...)

		jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, metaclass(T), utf8(method), sig)
		if jmethodId==C_NULL; geterror(true); end

		_jcall(metaclass(T), jmethodId, C_NULL, rettype, argtypes, args...)
	finally
		gc_enable(true)
	end

end

# Call instance methods
function jcall(obj::JavaObject, method::String, rettype::Type, argtypes::Tuple, args... )
	try
		gc_enable(false)
		sig = method_signature(rettype, argtypes...)
		jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, metaclass(obj), utf8(method), sig)
		if jmethodId==C_NULL; geterror(true); end
		_jcall(obj, jmethodId, C_NULL, rettype,  argtypes, args...)
	finally
		gc_enable(true)
	end
end



#Generate these methods to satisfy ccall's compile time constant requirement
#_jcall for primitive and Void return types
for (x, y, z) in [ (:jboolean, :(jnifunc.CallBooleanMethodA), :(jnifunc.CallStaticBooleanMethodA)),
					(:jchar, :(jnifunc.CallCharMethodA), :(jnifunc.CallStaticCharMethodA)),
					(:jbyte, :(jnifunc.CallByteMethodA), :(jnifunc.CallStaticByteMethodA)),
					(:jshort, :(jnifunc.CallShortMethodA), :(jnifunc.CallStaticShortMethodA)),
					(:jint, :(jnifunc.CallIntMethodA), :(jnifunc.CallStaticIntMethodA)), 
					(:jlong, :(jnifunc.CallLongMethodA), :(jnifunc.CallStaticLongMethodA)),
					(:jfloat, :(jnifunc.CallFloatMethodA), :(jnifunc.CallStaticFloatMethodA)),
					(:jdouble, :(jnifunc.CallDoubleMethodA), :(jnifunc.CallStaticDoubleMethodA)),
					(:Void, :(jnifunc.CallVoidMethodA), :(jnifunc.CallStaticVoidMethodA)) ]
	m = quote
		function _jcall(obj,  jmethodId::Ptr{Void}, callmethod::Ptr{Void}, rettype::Type{$(x)}, argtypes::Tuple, args... ) 
			 	if callmethod == C_NULL #!
			 		callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
			 	end
			 	@assert callmethod != C_NULL
				@assert jmethodId != C_NULL
				if(isnull(obj)); error("Attempt to call method on Java NULL"); end
				savedArgs, convertedArgs = convert_args(argtypes, args...)
				result = ccall(callmethod, $x , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, convertedArgs)
				if result==C_NULL; geterror(); end
				if result == nothing; return; end
				return convert_result(rettype, result)
		end
	end
	eval(m)
end

#_jcall for Object return types
#obj -- reciever - Class pointer or object prointer
#jmethodId -- Java method ID
#callmethod -- the C method pointer to call
function _jcall(obj,  jmethodId::Ptr{Void}, callmethod::Ptr{Void}, rettype::Type, argtypes::Tuple, args... ) 
		if callmethod == C_NULL
			callmethod = ifelse( typeof(obj)<:JavaObject, jnifunc.CallObjectMethodA , jnifunc.CallStaticObjectMethodA )
		end
		@assert callmethod != C_NULL
		@assert jmethodId != C_NULL
		if(isnull(obj)); error("Attempt to call method on Java NULL"); end
		savedArgs, convertedArgs = convert_args(argtypes, args...)
		result = ccall(callmethod, Ptr{Void} , (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}, Ptr{Void}), penv, obj.ptr, jmethodId, convertedArgs)
		if result==C_NULL; geterror(); end
		return convert_result(rettype, result)
end

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = @compat Int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(@compat Int(v))

# Get the JNI/C type for a particular Java type
function real_jtype(rettype)
	if issubtype(rettype, JavaObject) || issubtype(rettype, Array) || issubtype(rettype, JavaMetaClass)
		jnitype = Ptr{Void}
	else 
		jnitype = rettype
	end
	return jnitype
end


function convert_args(argtypes::Tuple, args...)
	convertedArgs = Array(Int64, length(args))
	savedArgs = Array(Any, length(args))
	for i in 1:length(args)
		r = convert_arg(argtypes[i], args[i])
		savedArgs[i] = r[1]
		convertedArgs[i] = jvalue(r[2])
	end
	return savedArgs, convertedArgs
end

function convert_arg(argtype::Type{JString}, arg) 
	x = convert(JString, arg)
	return x, x.ptr
end

function convert_arg(argtype::Type, arg) 
	x = convert(argtype, arg)
	return x,x
end
function convert_arg{T<:JavaObject}(argtype::Type{T}, arg) 
    x = convert(T, arg)::T
    return x, x.ptr
end

for (x, y, z) in [ (:jboolean, :(jnifunc.NewBooleanArray), :(jnifunc.SetBooleanArrayRegion)),
					(:jchar, :(jnifunc.NewCharArray), :(jnifunc.SetCharArrayRegion)),
					(:jbyte, :(jnifunc.NewByteArray), :(jnifunc.SetByteArrayRegion)),
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
			return carg, arrayptr
		end
	end
	eval( m)
end

function convert_arg{T<:JavaObject}(argtype::Type{Array{T,1}}, arg)
	carg = convert(argtype, arg)
	sz=length(carg)
	init=carg[1]
	arrayptr = ccall(jnifunc.NewObjectArray, Ptr{Void}, (Ptr{JNIEnv}, jint, Ptr{Void}, Ptr{Void}), penv, sz, metaclass(T), init.ptr)
	for i=2:sz 
		ccall(jnifunc.SetObjectArrayElement, Void, (Ptr{JNIEnv}, Ptr{Void}, jint, Ptr{Void}), penv, arrayptr, i-1, carg[i].ptr)
	end
	return carg, arrayptr
end

convert_result{T<:JString}(rettype::Type{T}, result) = bytestring(JString(result))
convert_result{T<:JavaObject}(rettype::Type{T}, result) = T(result)
convert_result(rettype, result) = result

for (x, y, z) in [ (:jboolean, :(jnifunc.GetBooleanArrayElements), :(jnifunc.ReleaseBooleanArrayElements)),
					(:jchar, :(jnifunc.GetCharArrayElements), :(jnifunc.ReleaseCharArrayElements)),
					(:jbyte, :(jnifunc.GetByteArrayElements), :(jnifunc.ReleaseByteArrayElements)),
					(:jshort, :(jnifunc.GetShortArrayElements), :(jnifunc.ReleaseShortArrayElements)),
					(:jint, :(jnifunc.GetIntArrayElements), :(jnifunc.ReleaseIntArrayElements)), 
					(:jlong, :(jnifunc.GetLongArrayElements), :(jnifunc.ReleaseLongArrayElements)),
					(:jfloat, :(jnifunc.GetFloatArrayElements), :(jnifunc.ReleaseFloatArrayElements)),
					(:jdouble, :(jnifunc.GetDoubleArrayElements), :(jnifunc.ReleaseDoubleArrayElements)) ]
	m=quote
		function convert_result(rettype::Type{Array{$(x),1}}, result)
			sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, result)
			arr = ccall($(y), Ptr{$(x)}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean} ), penv, result, C_NULL ) 
			jl_arr::Array = pointer_to_array(arr, (@compat Int(sz)), false)
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

#get the JNI signature string for a method, given its 
#return type and argument types
function method_signature(rettype, argtypes...)
	s=IOBuffer()
	write(s, "(")
	for arg in argtypes
		write(s, signature(arg))
	end
	write(s, ")")
	write(s, signature(rettype))
	return takebuf_string(s)
end


#get the JNI signature string for a given type
function signature(arg::Type)
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
		return string("[", signature(eltype(arg)))
	end
end

signature{T}(arg::Type{JavaObject{T}}) = string("L", javaclassname(T), ";")

function deleteref(x::JavaObject)
	
	if x.ptr == C_NULL; return; end
	if (penv==C_NULL); return; end
	#ccall(:jl_,Void,(Any,),x)
	ccall(jnifunc.DeleteLocalRef, Void, (Ptr{JNIEnv}, Ptr{Void}), penv, x.ptr)
	x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize 
	return
end 

@unix_only const sep = ":"
@windows_only const sep = ";"
cp=Array(String, 0)
opts=Array(String, 0)
addClassPath(s::String) = isloaded()?warn("JVM already initialised. This call has no effect"): push!(cp, s)
addOpts(s::String) = isloaded()?warn("JVM already initialised. This call has no effect"): push!(opts, s)

init() = init(vcat(opts, reduce((x,y)->string(x,sep,y),"-Djava.class.path=$(cp[1])",cp[2:end]) ))

isloaded() = isdefined(JavaCall, :jnifunc) && isdefined(JavaCall, :penv) && penv != C_NULL 

assertloaded() = isloaded()?nothing:error("JVM not initialised. Please run init()")
assertnotloaded() = isloaded()?error("JVM already initialised"):nothing

# Pointer to pointer to pointer to pointer alert! Hurrah for unsafe load
function init{T<:String}(opts::Array{T, 1}) 
	assertnotloaded()
	opt = Array(JavaVMOption, length(opts))
	for i in 1:length(opts)
		opt[i]=JavaVMOption(pointer(opts[i]), C_NULL)
	end
	ppjvm=Array(Ptr{JavaVM},1)
	ppenv=Array(Ptr{JNIEnv},1)
	vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, length(opts)), convert(Ptr{JavaVMOption}, pointer(opt)), JNI_TRUE)

	res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv, &vm_args)
	if res < 0; error("Unable to initialise Java VM: $(res)"); end
	global penv = ppenv[1]
	global pjvm = ppjvm[1]
	jnienv=unsafe_load(penv)
	jvm = unsafe_load(pjvm)
	global jvmfunc = unsafe_load(jvm.JNIInvokeInterface_)
	global jnifunc = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
	return
end

function destroy()
	if (!isdefined(JavaCall, :penv) || penv == C_NULL) ; error("Called destroy without initialising Java VM"); end
	res = ccall(jvmfunc.DestroyJavaVM, Cint, (Ptr{Void},), pjvm)
	if res < 0; error("Unable to destroy Java VM"); end
	global penv=C_NULL; global pjvm=C_NULL; 
end



end # module
