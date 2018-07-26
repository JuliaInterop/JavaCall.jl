
# jni_md.h
const jint = Cint
#ifdef _LP64 /* 64-bit Solaris */
# typedef long jlong;
const jlong = Clonglong
const jbyte = Cchar

# jni.h

const jboolean = Cuchar
const jchar = Cushort
const jshort = Cshort
const jfloat = Cfloat
const jdouble = Cdouble
const jsize = jint
jprimitive = Union{jboolean, jchar, jshort, jfloat, jdouble, jint, jlong}

struct JavaMetaClass{T}
    ptr::Ptr{Nothing}
end

#The metaclass, sort of equivalent to a the
JavaMetaClass(T, ptr) = JavaMetaClass{T}(ptr)

mutable struct JavaObject{T}
    ptr::Ptr{Nothing}

    #This below is ugly. Once we stop supporting 0.5, this can be replaced by
    # function JavaObject{T}(ptr) where T
    function JavaObject{T}(ptr) where T
        j = new{T}(ptr)
        finalizer(deleteref, j)
        return j
    end

    #replace with: JavaObject{T}(argtypes::Tuple, args...) where T
    JavaObject{T}(argtypes::Tuple, args...) where {T} = jnew(T, argtypes, args...)
end

JavaObject(T, ptr) = JavaObject{T}(ptr)

function deleteref(x::JavaObject)
    if x.ptr == C_NULL; return; end
    if (penv==C_NULL); return; end
    #ccall(:jl_,Nothing,(Any,),x)
    ccall(jnifunc.DeleteLocalRef, Nothing, (Ptr{JNIEnv}, Ptr{Nothing}), penv, x.ptr)
    x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize
    return
end


"""
```
isnull(obj::JavaObject)
```
Checks if the passed JavaObject is null or not

### Args
* obj: The object of type JavaObject

### Returns
true if the passed object is null else false
"""
isnull(obj::JavaObject) = obj.ptr == C_NULL

"""
```
isnull(obj::JavaMetaClass)
```
Checks if the passed JavaMetaClass is null or not

### Args
* obj: The object of type JavaMetaClass

### Returns
true if the passed object is null else false
"""
isnull(obj::JavaMetaClass) = obj.ptr == C_NULL

const JClass = JavaObject{Symbol("java.lang.Class")}
const JObject = JavaObject{Symbol("java.lang.Object")}
const JMethod = JavaObject{Symbol("java.lang.reflect.Method")}
const JThread = JavaObject{Symbol("java.lang.Thread")}
const JClassLoader = JavaObject{Symbol("java.lang.ClassLoader")}
const JString = JavaObject{Symbol("java.lang.String")}

function JString(str::AbstractString)
    jstring = ccall(jnifunc.NewStringUTF, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{UInt8}), penv, String(str))
    if jstring == C_NULL
        geterror()
    else
        return JString(jstring)
    end
end

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = Int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(Int(v))


function _jimport(juliaclass) 
    for str ∈ [" ", "(", ")"]
        juliaclass = replace(juliaclass, str=>"")
    end
    :(JavaObject{Symbol($juliaclass)})
end

macro jimport(class::Expr)
    juliaclass = sprint(Base.show_unquoted, class)
    _jimport(juliaclass)
end
macro jimport(class::Symbol)
    juliaclass = string(class)
    _jimport(juliaclass)
end
macro jimport(class::AbstractString)
    _jimport(class)
end


function jnew(T::Symbol, argtypes::Tuple, args...)
    sig = method_signature(Nothing, argtypes...)
    jmethodId = ccall(jnifunc.GetMethodID, Ptr{Nothing},
                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), penv, metaclass(T),
                      String("<init>"), sig)
    if jmethodId == C_NULL
        throw(JavaCallError("No constructor for $T with signature $sig"))
    end
    return  _jcall(metaclass(T), jmethodId, jnifunc.NewObjectA, JavaObject{T}, argtypes, args...)
end

# Call static methods
function jcall(typ::Type{JavaObject{T}}, method::AbstractString, rettype::Type, argtypes::Tuple,
               args... ) where T
    sig = method_signature(rettype, argtypes...)
    jmethodId = ccall(jnifunc.GetStaticMethodID, Ptr{Nothing},
                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), penv, metaclass(T),
                      String(method), sig)
    jmethodId==C_NULL && geterror(true)
    _jcall(metaclass(T), jmethodId, C_NULL, rettype, argtypes, args...)
end

# Call instance methods
function jcall(obj::JavaObject, method::AbstractString, rettype::Type, argtypes::Tuple, args... )
    sig = method_signature(rettype, argtypes...)
    jmethodId = ccall(jnifunc.GetMethodID, Ptr{Nothing},
                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), penv, metaclass(obj),
                      String(method), sig)
    jmethodId==C_NULL && geterror(true)
    _jcall(obj, jmethodId, C_NULL, rettype,  argtypes, args...)
end

function jfield(typ::Type{JavaObject{T}}, field::AbstractString, fieldType::Type) where T
    jfieldID  = ccall(jnifunc.GetStaticFieldID, Ptr{Nothing},
                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), penv, metaclass(T),
                      String(field), signature(fieldType))
    jfieldID==C_NULL && geterror(true)
    _jfield(metaclass(T), jfieldID, fieldType)
end

function jfield(obj::JavaObject, field::AbstractString, fieldType::Type)
    jfieldID  = ccall(jnifunc.GetFieldID, Ptr{Nothing},
                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), penv, metaclass(obj),
                      String(field), signature(fieldType))
    jfieldID==C_NULL && geterror(true)
    _jfield(obj, jfieldID, fieldType)
end

for (x, y, z) in [(:jboolean, :(jnifunc.GetBooleanField), :(jnifunc.GetStaticBooleanField)),
                  (:jchar, :(jnifunc.GetCharField), :(jnifunc.GetStaticCharField)),
                  (:jbyte, :(jnifunc.GetByteField), :(jnifunc.GetStaticBypeField)),
                  (:jshort, :(jnifunc.GetShortField), :(jnifunc.GetStaticShortField)),
                  (:jint, :(jnifunc.GetIntField), :(jnifunc.GetStaticIntField)),
                  (:jlong, :(jnifunc.GetLongField), :(jnifunc.GetStaticLongField)),
                  (:jfloat, :(jnifunc.GetFloatField), :(jnifunc.GetStaticFloatField)),
                  (:jdouble, :(jnifunc.GetDoubleField), :(jnifunc.GetStaticDoubleField)) ]

    m = quote
        function _jfield(obj, jfieldID::Ptr{Nothing}, fieldType::Type{$(x)})
            callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
            result = ccall(callmethod, $x, (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}), penv, obj.ptr,
                           jfieldID)
            result==C_NULL && geterror()
            return convert_result(fieldType, result)
        end
    end
    eval(m)
end

function _jfield(obj, jfieldID::Ptr{Nothing}, fieldType::Type)
    callmethod = ifelse( typeof(obj)<:JavaObject, jnifunc.GetObjectField , jnifunc.GetStaticObjectField )
    result = ccall(callmethod, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}), penv, obj.ptr,
                   jfieldID)
    result==C_NULL && geterror()
    return convert_result(fieldType, result)
end

#Generate these methods to satisfy ccall's compile time constant requirement
#_jcall for primitive and Nothing return types
for (x, y, z) in [ (:jboolean, :(jnifunc.CallBooleanMethodA), :(jnifunc.CallStaticBooleanMethodA)),
                  (:jchar, :(jnifunc.CallCharMethodA), :(jnifunc.CallStaticCharMethodA)),
                  (:jbyte, :(jnifunc.CallByteMethodA), :(jnifunc.CallStaticByteMethodA)),
                  (:jshort, :(jnifunc.CallShortMethodA), :(jnifunc.CallStaticShortMethodA)),
                  (:jint, :(jnifunc.CallIntMethodA), :(jnifunc.CallStaticIntMethodA)),
                  (:jlong, :(jnifunc.CallLongMethodA), :(jnifunc.CallStaticLongMethodA)),
                  (:jfloat, :(jnifunc.CallFloatMethodA), :(jnifunc.CallStaticFloatMethodA)),
                  (:jdouble, :(jnifunc.CallDoubleMethodA), :(jnifunc.CallStaticDoubleMethodA)),
                  (:Nothing, :(jnifunc.CallVoidMethodA), :(jnifunc.CallStaticVoidMethodA)) ]
    m = quote
        function _jcall(obj, jmethodId::Ptr{Nothing}, callmethod::Ptr{Nothing}, rettype::Type{$(x)},
                        argtypes::Tuple, args...)
            if callmethod == C_NULL #!
                callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
            end
            @assert callmethod != C_NULL
            @assert jmethodId != C_NULL
            isnull(obj) && throw(JavaCallError("Attempt to call method on Java NULL"))
            savedArgs, convertedArgs = convert_args(argtypes, args...)
            result = ccall(callmethod, $x , (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}), penv, obj.ptr, jmethodId, convertedArgs)
            result==C_NULL && geterror()
            result == nothing && (return)
            return convert_result(rettype, result)
        end
    end
    eval(m)
end

#_jcall for Object return types
#obj -- receiver - Class pointer or object prointer
#jmethodId -- Java method ID
#callmethod -- the C method pointer to call
function _jcall(obj, jmethodId::Ptr{Nothing}, callmethod::Ptr{Nothing}, rettype::Type, argtypes::Tuple,
                args...)
    if callmethod == C_NULL
        callmethod = ifelse(typeof(obj)<:JavaObject, jnifunc.CallObjectMethodA ,
                            jnifunc.CallStaticObjectMethodA)
    end
    @assert callmethod != C_NULL
    @assert jmethodId != C_NULL
    isnull(obj) && error("Attempt to call method on Java NULL")
    savedArgs, convertedArgs = convert_args(argtypes, args...)
    result = ccall(callmethod, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
                   penv, obj.ptr, jmethodId, convertedArgs)
    result==C_NULL && geterror()
    return convert_result(rettype, result)
end


global const _jmc_cache = Dict{Symbol, JavaMetaClass}()

function _metaclass(class::Symbol)
    jclass=javaclassname(class)
    jclassptr = ccall(jnifunc.FindClass, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{UInt8}), penv, jclass)
    jclassptr == C_NULL && throw(JavaCallError("Class Not Found $jclass"))
    return JavaMetaClass(class, jclassptr)
end

function metaclass(class::Symbol)
    if !haskey(_jmc_cache, class)
        _jmc_cache[class] = _metaclass(class)
    end
    return _jmc_cache[class]
end

metaclass(::Type{JavaObject{T}}) where {T} = metaclass(T)
metaclass(::JavaObject{T}) where {T} = metaclass(T)

javaclassname(class::Symbol) = replace(string(class), "."=>"/")

function geterror(allow=false)
    isexception = ccall(jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv )

    if isexception == JNI_TRUE
        jthrow = ccall(jnifunc.ExceptionOccurred, Ptr{Nothing}, (Ptr{JNIEnv},), penv)
        jthrow==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        ccall(jnifunc.ExceptionDescribe, Nothing, (Ptr{JNIEnv},), penv ) #Print java stackstrace to stdout
        ccall(jnifunc.ExceptionClear, Nothing, (Ptr{JNIEnv},), penv )
        jclass = ccall(jnifunc.FindClass, Ptr{Nothing}, (Ptr{JNIEnv},Ptr{UInt8}), penv,
                       "java/lang/Throwable")
        jclass==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        jmethodId=ccall(jnifunc.GetMethodID, Ptr{Nothing},
                        (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}), penv, jclass, "toString",
                        "()Ljava/lang/String;")
        jmethodId==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        res = ccall(jnifunc.CallObjectMethodA, Ptr{Nothing},
                    (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}), penv, jthrow, jmethodId,
                    C_NULL)
        res==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        msg = unsafe_string(JString(res))
        ccall(jnifunc.DeleteLocalRef, Nothing, (Ptr{JNIEnv}, Ptr{Nothing}), penv, jthrow)
        throw(JavaCallError(string("Error calling Java: ",msg)))
    else
        if allow==false
            return #No exception pending, legitimate NULL returned from Java
        else
            throw(JavaCallError("Null from Java. Not known how"))
        end
    end
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
    return String(take!(s))
end


#get the JNI signature string for a given type
function signature(arg::Type)
    if arg === jboolean
        return "Z"
    elseif arg === jbyte
        return "B"
    elseif arg === jchar
        return "C"
    elseif arg === jshort
        return "S"
    elseif arg === jint
        return "I"
    elseif arg === jlong
        return "J"
    elseif arg === jfloat
        return "F"
    elseif arg === jdouble
        return "D"
    elseif arg === Nothing
        return "V"
    elseif arg <: Array
        dims = "[" ^ ndims(arg)
        return string(dims, signature(eltype(arg)))
    end
end

signature(arg::Type{JavaObject{T}}) where {T} = string("L", javaclassname(T), ";")
