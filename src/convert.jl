convert(::Type{JString}, str::AbstractString) = JString(str)
convert(::Type{JObject}, str::AbstractString) = convert(JObject, JString(str))

#Cast java object from S to T . Needed for polymorphic calls
function convert(::Type{JavaObject{T}}, obj::JavaObject{S}) where {T,S}
    if isConvertible(T, S)   #Safe static cast
        ptr = JNI.NewLocalRef(obj.ptr)
        ptr === C_NULL && geterror()
        return JavaObject{T}(ptr)
    end
    isnull(obj) && throw(ArgumentError("Cannot convert NULL"))
    realClass = JNI.GetObjectClass(obj.ptr)
    if isConvertible(T, realClass)  #dynamic cast
        ptr = JNI.NewLocalRef(obj.ptr)
        ptr === C_NULL && geterror()
        return JavaObject{T}(ptr)
    end
    throw(JavaCallError("Cannot cast java object from $S to $T"))
end

#Is java type convertible from S to T.
isConvertible(T, S) = JNI.IsAssignableFrom(metaclass(S).ptr, metaclass(T).ptr) == JNI_TRUE
isConvertible(T, S::Ptr{Nothing} ) = JNI.IsAssignableFrom(S, metaclass(T).ptr) == JNI_TRUE

unsafe_convert(::Type{Ptr{Nothing}}, cls::JavaMetaClass) = cls.ptr

# Get the JNI/C type for a particular Java type
function real_jtype(rettype)
    if rettype <: JavaObject || rettype <: Array || rettype <: JavaMetaClass
        jnitype = Ptr{Nothing}
    else
        jnitype = rettype
    end
    return jnitype
end

function convert_args(argtypes::Tuple, args...)
    convertedArgs = Array{Int64}(undef, length(args))
    savedArgs = Array{Any}(undef, length(args))
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
function convert_arg(argtype::Type{T}, arg) where T<:JavaObject
    x = convert(T, arg)::T
    return x, x.ptr
end

for (x, y, z) in [(:jboolean, :(JNI.NewBooleanArray), :(JNI.SetBooleanArrayRegion)),
                  (:jchar,    :(JNI.NewCharArray),    :(JNI.SetCharArrayRegion))   ,
                  (:jbyte,    :(JNI.NewByteArray),    :(JNI.SetByteArrayRegion))   ,
                  (:jshort,   :(JNI.NewShortArray),   :(JNI.SetShortArrayRegion))  ,
                  (:jint,     :(JNI.NewIntArray),     :(JNI.SetIntArrayRegion))    ,
                  (:jlong,    :(JNI.NewLongArray),    :(JNI.SetLongArrayRegion))   ,
                  (:jfloat,   :(JNI.NewFloatArray),   :(JNI.SetFloatArrayRegion))  ,
                  (:jdouble,  :(JNI.NewDoubleArray),  :(JNI.SetDoubleArrayRegion)) ]
    m = quote
        function convert_arg(argtype::Type{Array{$x,1}}, arg)
            carg = convert(argtype, arg)
            sz=length(carg)
            arrayptr = $y(sz)
            $z(arrayptr, 0, sz, carg)
            return carg, arrayptr
        end
    end
    eval( m)
end

function convert_arg(argtype::Type{Array{T,1}}, arg) where T<:JavaObject
    carg = convert(argtype, arg)
    sz = length(carg)
    init = carg[1]
    arrayptr = JNI.NewObjectArray(sz, metaclass(T).ptr, init.ptr)
    for i=2:sz
        JNI.SetObjectArrayElement(arrayptr, i-1, carg[i].ptr)
    end
    return carg, arrayptr
end

convert_result(rettype::Type{T}, result) where {T<:JString} = unsafe_string(JString(result))
convert_result(rettype::Type{T}, result) where {T<:JavaObject} = T(result)
convert_result(rettype, result) = result

for (x, y, z) in [(:jboolean, :(JNI.GetBooleanArrayElements), :(JNI.ReleaseBooleanArrayElements)),
                  (:jchar,    :(JNI.GetCharArrayElements),    :(JNI.ReleaseCharArrayElements))   ,
                  (:jbyte,    :(JNI.GetByteArrayElements),    :(JNI.ReleaseByteArrayElements))   ,
                  (:jshort,   :(JNI.GetShortArrayElements),   :(JNI.ReleaseShortArrayElements))  ,
                  (:jint,     :(JNI.GetIntArrayElements),     :(JNI.ReleaseIntArrayElements))    ,
                  (:jlong,    :(JNI.GetLongArrayElements),    :(JNI.ReleaseLongArrayElements))   ,
                  (:jfloat,   :(JNI.GetFloatArrayElements),   :(JNI.ReleaseFloatArrayElements))  ,
                  (:jdouble,  :(JNI.GetDoubleArrayElements),  :(JNI.ReleaseDoubleArrayElements)) ]
    m = quote
        function convert_result(rettype::Type{Array{$(x),1}}, result)
            sz = JNI.GetArrayLength(result)
            arr = $y(result, Ptr{jboolean}(C_NULL))
            jl_arr::Array = unsafe_wrap(Array, arr, Int(sz))
            jl_arr = deepcopy(jl_arr)
            $z(result, arr, Int32(0))
            return jl_arr
        end
    end
    eval(m)
end

function convert_result(rettype::Type{Array{JavaObject{T},1}}, result) where T
    sz = JNI.GetArrayLength(result)

    ret = Array{JavaObject{T}}(undef, sz)

    for i=1:sz
        a=JNI.GetObjectArrayElement(result, i-1)
        ret[i] = JavaObject{T}(a)
    end
    return ret
end


# covers return types like Vector{Vector{T}}
function convert_result(rettype::Type{Array{T,1}}, result) where T
    sz = JNI.GetArrayLength(result)

    ret = Array{T}(undef, sz)

    for i=1:sz
        a=JNI.GetObjectArrayElement(result, i-1)
        ret[i] = convert_result(T, a)
    end
    return ret
end


function convert_result(rettype::Type{Array{JavaObject{T},2}}, result) where T
    sz = JNI.GetArrayLength(result)
    if sz == 0
        return Array{T}(undef, 0,0)
    end
    a_1 = JNI.GetObjectArrayElement(result, 0)
    sz_1 = JNI.GetArrayLength(a_1)
    ret = Array{JavaObject{T}}(undef, sz, sz_1)
    for i=1:sz
        a = JNI.GetObjectArrayElement(result, i-1)
        # check that size of the current subarray is the same as for the first one
        sz_a = JNI.GetArrayLength(a)
        @assert(sz_a == sz_1, "Size of $(i)th subrarray is $sz_a, but size of the 1st subarray was $sz_1")
        for j=1:sz_1
            x = JNI.GetObjectArrayElement(a, j-1)
            ret[i, j] = JavaObject{T}(x)
        end
    end
    return ret
end


# matrices of primitive types and other arrays
function convert_result(rettype::Type{Array{T,2}}, result) where T
    sz = JNI.GetArrayLength(result)
    if sz == 0
        return Array{T}(undef, 0,0)
    end
    a_1 = JNI.GetObjectArrayElement(result, 0)
    sz_1 = JNI.GetArrayLength(a_1)
    ret = Array{T}(undef, sz, sz_1)
    for i=1:sz
        a = JNI.GetObjectArrayElement(result, i-1)
        # check that size of the current subarray is the same as for the first one
        sz_a = JNI.GetArrayLength(a)
        @assert(sz_a == sz_1, "Size of $(i)th subrarray is $sz_a, but size of the 1st subarray was $sz_1")
        ret[i, :] = convert_result(Vector{T}, a)
    end
    return ret
end


convert(::Type{jlong}, obj::JavaObject{Symbol("java.lang.Long")}) = jcall(obj, "longValue", jlong, ())
convert(::Type{jint}, obj::JavaObject{Symbol("java.lang.Integer")}) = jcall(obj, "intValue", jint, ())
convert(::Type{jdouble}, obj::JavaObject{Symbol("java.lang.Double")}) = jcall(obj, "doubleValue", jdouble, ())
convert(::Type{jfloat}, obj::JavaObject{Symbol("java.lang.Float")}) = jcall(obj, "floatValue", jfloat, ())
convert(::Type{jboolean}, obj::JavaObject{Symbol("java.lang.Boolean")}) = jcall(obj, "booleanValue", jboolean, ())


#The second term in this addition is due to the fact that Java converts all times to local time
function convert(::Type{DateTime}, x::@jimport(java.util.Date))
    if isnull(x)
        Dates.DateTime(1970,1,1,0,0,0)
    else
        Dates.unix2datetime(jcall(x, "getTime", jlong, ())/1000) +
            Second(round(div(Dates.value(now() - now(Dates.UTC)),1000)/900)*(900))
    end
end

function convert(::Type{DateTime}, x::JavaObject)
    isnull(x) && return Dates.DateTime(1970,1,1,0,0,0)
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

function convert(::Type{@jimport(java.util.HashMap)}, K::Type{JavaObject{X}}, V::Type{JavaObject{Y}},
                 x::Dict) where {X,Y}
    Hashmap = @jimport(java.util.HashMap)
    p = Hashmap(())
    for (n,v) in x
        jcall(p, "put", @jimport(java.lang.Object), (JObject, JObject), n, v)
    end
    return p
end

function convert(::Type{@jimport(java.util.Map)}, K::Type{JavaObject{X}}, V::Type{JavaObject{Y}},
                 x::Dict) where {X,Y}
    convert(@jimport(java.util.Map), convert(@jimport(java.util.HashMap), K, V, x))
end

function convert(::Type{@jimport(java.util.ArrayList)}, x::Vector, V::Type{JavaObject{X}}=JObject) where X
    ArrayList = @jimport(java.util.ArrayList)
    a = ArrayList(())
    for v in x
        jcall(a, "add", jboolean, (JObject,), convert(V, v))
    end
    return a
end

function convert(::Type{@jimport(java.util.List)}, x::Vector, V::Type{JavaObject{X}}=JObject) where X
    convert(@jimport(java.util.ArrayList), x, V)
end

# Convert a reference to a java.lang.String into a Julia string. Copies the underlying byte buffer
function unsafe_string(jstr::JString)  #jstr must be a jstring obtained via a JNI call
    if isnull(jstr); return ""; end #Return empty string to keep type stability. But this is questionable
    pIsCopy = Array{jboolean}(undef, 1)
    #buf::Ptr{UInt8} = JNI.GetStringUTFChars(jstr.ptr, pIsCopy)
    buf = JNI.GetStringUTFChars(jstr.ptr, pIsCopy)
    s = unsafe_string(buf)
    JNI.ReleaseStringUTFChars(jstr.ptr, buf)
    return s
end

for (x, y, z) in [(:jboolean, :(JNI.GetBooleanArrayElements), :(JNI.ReleaseBooleanArrayElements)),
                  (:jchar,    :(JNI.GetCharArrayElements),    :(JNI.ReleaseCharArrayElements))   ,
                  (:jbyte,    :(JNI.GetByteArrayElements),    :(JNI.ReleaseByteArrayElements))   ,
                  (:jshort,   :(JNI.GetShortArrayElements),   :(JNI.ReleaseShortArrayElements))  ,
                  (:jint,     :(JNI.GetIntArrayElements),     :(JNI.ReleaseIntArrayElements))    ,
                  (:jlong,    :(JNI.GetLongArrayElements),    :(JNI.ReleaseLongArrayElements))   ,
                  (:jfloat,   :(JNI.GetFloatArrayElements),   :(JNI.ReleaseFloatArrayElements))  ,
                  (:jdouble,  :(JNI.GetDoubleArrayElements),  :(JNI.ReleaseDoubleArrayElements)) ]
    m = quote
        function convert(::Type{Array{$(x),1}}, obj::JObject)
            sz = JNI.GetArrayLength(obj.ptr)
            arr = $y(obj.ptr, Ptr{jboolean}(C_NULL))
            jl_arr::Array = unsafe_wrap(Array, arr, Int(sz))
            jl_arr = deepcopy(jl_arr)
            $z(obj.ptr, arr, Int32(0))
            return jl_arr
        end
    end
    eval(m)
end


function convert(::Type{Array{T, 1}}, obj::JObject) where T
    sz = JNI.GetArrayLength(obj.ptr)
    ret = Array{T}(undef, sz)
    for i=1:sz
        ptr = JNI.GetObjectArrayElement(obj.ptr, i-1)
        ret[i] = convert(T, JObject(ptr))
    end
    return ret
end

##Iterator
iterator(obj::JavaObject) = jcall(obj, "iterator", @jimport(java.util.Iterator), ())

"""
Given a `JavaObject{T}` narrows down `T` to a real class of the underlying object.
For example, `JavaObject{:java.lang.Object}` pointing to `java.lang.String`
will be narrowed down to `JavaObject{:java.lang.String}`
"""
function narrow(obj::JavaObject)
    c = jcall(obj,"getClass", @jimport(java.lang.Class), ())
    t = jcall(c, "getName", JString, ())
    return convert(JavaObject{Symbol(t)}, obj)
end

has_next(itr::JavaObject) = (jcall(itr, "hasNext", jboolean, ()) == JNI_TRUE)

function Base.iterate(itr::JavaObject, state=nothing)
    if has_next(itr)
        o = jcall(itr, "next", @jimport(java.lang.Object), ())
        return (narrow(o), state)
    else
        return nothing
    end
end
