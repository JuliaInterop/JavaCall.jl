convert{T<:AbstractString}(::Type{JString}, str::T) = JString(str)
convert{T<:AbstractString}(::Type{JObject}, str::T) = convert(JObject, JString(str))

#Cast java object from S to T . Needed for polymorphic calls
function convert{T,S}(::Type{JavaObject{T}}, obj::JavaObject{S})
    if isConvertible(T, S)   #Safe static cast
        ptr = ccall(jnifunc.NewLocalRef, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}), penv, obj.ptr)
        if ptr === C_NULL geterror() end
        return JavaObject{T}(ptr)
    end
    if isnull(obj) ; error("Cannot convert NULL"); end
    realClass = ccall(jnifunc.GetObjectClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void} ), penv, obj.ptr)
    if isConvertible(T, realClass)  #dynamic cast
        ptr = ccall(jnifunc.NewLocalRef, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}), penv, obj.ptr)
        if ptr === C_NULL geterror() end
        return JavaObject{T}(ptr)
    end
    error("Cannot cast java object from $S to $T")
end

#Is java type convertible from S to T.
isConvertible(T, S) = (ccall(jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, metaclass(S), metaclass(T) ) == JNI_TRUE)
isConvertible(T, S::Ptr{Void} ) = (ccall(jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Void}), penv, S, metaclass(T) ) == JNI_TRUE)

unsafe_convert(::Type{Ptr{Void}}, cls::JavaMetaClass) = cls.ptr

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

convert_result{T<:JString}(rettype::Type{T}, result) = unsafe_string(JString(result))
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
            jl_arr::Array = unsafe_wrap(Array, arr, (@compat Int(sz)), false)
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

#The second term in this addition is due to the fact that Java converts all times to local time
convert(::Type{DateTime}, x::@jimport(java.util.Date)) = isnull(x)?Dates.DateTime(1970,1,1,0,0,0):
            (Dates.unix2datetime(jcall(x, "getTime", jlong, ())/1000) +
                    Second(round(div(Dates.value(now() - now(Dates.UTC)),1000)/900)*(900)))

function convert(::Type{DateTime}, x::JavaObject)
    if isnull(x); return Dates.DateTime(1970,1,1,0,0,0); end
    JDate = @jimport(java.util.Date)
    if isConvertible(JDate, x)
        return convert(DateTime, convert(JDate, x))
    elseif isConvertible(@jimport(java.util.Calendar), x)
        return convert(DateTime, jcall(x, "getTime", JDate, ()))
    end
end

function convert(::Type{@jimport(java.util.Properties)}, x::Dict)
    Properties = @jimport(java.util.Properties)
    p = Properties(())
    for (n,v) in x
        jcall(p, "setProperty", @jimport(java.lang.Object), (JString, JString), n, v)
    end
    return p
end

function convert{X,Y}(::Type{@jimport(java.util.HashMap)}, K::Type{JavaObject{X}}, V::Type{JavaObject{Y}}, x::Dict)
    Hashmap = @jimport(java.util.HashMap)
    p = Hashmap(())
    for (n,v) in x
        jcall(p, "put", @jimport(java.lang.Object), (JObject, JObject), n, v)
    end
    return p
end

convert{X,Y}(::Type{@jimport(java.util.Map)}, K::Type{JavaObject{X}}, V::Type{JavaObject{Y}}, x::Dict) = convert(@jimport(java.util.Map), convert(@jimport(java.util.HashMap), K, V, x))

function convert{X}(::Type{@jimport(java.util.ArrayList)}, x::Vector, V::Type{JavaObject{X}}=JObject)
    ArrayList = @jimport(java.util.ArrayList)
    a = ArrayList(())
    for v in x
        jcall(a, "add", jboolean, (JObject,), convert(V, v))
    end
    return a
end

convert{X}(::Type{@jimport(java.util.List)}, x::Vector, V::Type{JavaObject{X}}=JObject) = convert(@jimport(java.util.ArrayList), x, V)

# Convert a reference to a java.lang.String into a Julia string. Copies the underlying byte buffer
function unsafe_string(jstr::JString)  #jstr must be a jstring obtained via a JNI call
    if isnull(jstr); return ""; end #Return empty string to keep type stability. But this is questionable
    pIsCopy = Array(jboolean, 1)
    buf::Ptr{UInt8} = ccall(jnifunc.GetStringUTFChars, Ptr{UInt8}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean}), penv, jstr.ptr, pIsCopy)
    s=unsafe_string(buf)
    ccall(jnifunc.ReleaseStringUTFChars, Void, (Ptr{JNIEnv}, Ptr{Void}, Ptr{UInt8}), penv, jstr.ptr, buf)
    return s
end

#This is necessary to properly deprecate bytestring in 0.5, while ensuring
# callers don't need to change for 0.4.
function Base.bytestring(jstr::JString)  #jstr must be a jstring obtained via a JNI call
    if VERSION >= v"0.5.0-dev+4612"
        Base.depwarn("bytestring(jstr::JString) is deprecated. Use unsafe_string(jstr) instead", :bytestring )
    end
    return JavaCall.unsafe_string(jstr)
end




for (x, y, z) in [ (:jboolean, :(jnifunc.GetBooleanArrayElements), :(jnifunc.ReleaseBooleanArrayElements)),
                  (:jchar, :(jnifunc.GetCharArrayElements), :(jnifunc.ReleaseCharArrayElements)),
                  (:jbyte, :(jnifunc.GetByteArrayElements), :(jnifunc.ReleaseByteArrayElements)),
                  (:jshort, :(jnifunc.GetShortArrayElements), :(jnifunc.ReleaseShortArrayElements)),
                  (:jint, :(jnifunc.GetIntArrayElements), :(jnifunc.ReleaseIntArrayElements)),
                  (:jlong, :(jnifunc.GetLongArrayElements), :(jnifunc.ReleaseLongArrayElements)),
                  (:jfloat, :(jnifunc.GetFloatArrayElements), :(jnifunc.ReleaseFloatArrayElements)),
                  (:jdouble, :(jnifunc.GetDoubleArrayElements), :(jnifunc.ReleaseDoubleArrayElements)) ]
    m=quote
        function convert(::Type{Array{$(x),1}}, obj::JObject)
            sz = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Void}), penv, obj.ptr)
            arr = ccall($(y), Ptr{$(x)}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean} ), penv, obj.ptr, C_NULL )
            jl_arr::Array = unsafe_wrap(Array, arr, (@compat Int(sz)), false)
            jl_arr = deepcopy(jl_arr)
            ccall($(z), Void, (Ptr{JNIEnv},Ptr{Void}, Ptr{$(x)}, jint), penv, obj.ptr, arr, 0)
            return jl_arr
        end
    end
    eval(m)
end


function convert{T}(::Type{Array{T, 1}}, obj::JObject)
    sz = ccall(jnifunc.GetArrayLength, jint,
               (Ptr{JNIEnv}, Ptr{Void}), penv, obj.ptr)
    ret = Array(T, sz)
    for i=1:sz
        ptr = ccall(jnifunc.GetObjectArrayElement, Ptr{Void},
                  (Ptr{JNIEnv}, Ptr{Void}, jint), penv, obj.ptr, i-1)
        ret[i] = convert(T, JObject(ptr))
    end
    return ret
end

##Iterator
Base.start(itr::JavaObject) = true
function Base.next(itr::JavaObject, state)
     o = jcall(itr, "next", @jimport(java.lang.Object), (),)
     c=jcall(o,"getClass", @jimport(java.lang.Class), ())
     t=jcall(c, "getName", JString, ())
     return (convert(JavaObject{Symbol(t)}, o), state)
end
Base.done(itr::JavaObject, state)  = (jcall(itr, "hasNext", jboolean, ()) == JNI_FALSE)
