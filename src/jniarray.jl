jniname(::Type{jboolean}) = "Boolean"
jniname(::Type{jbyte}) = "Byte"
jniname(::Type{jchar}) = "Char"
jniname(::Type{jshort}) = "Short"
jniname(::Type{jint}) = "Int"
jniname(::Type{jlong}) = "Long"
jniname(::Type{jfloat}) = "Float"
jniname(::Type{jdouble}) = "Double"


mutable struct JNIVector{T} <: AbstractVector{T}
    ref::JavaRef
    arr::Union{Nothing,Vector{T}}
    function JNIVector{T}(ref) where T
        j = new{T}(ref, nothing)
        finalizer(deleteref, j)
        return j
    end
end

Base.getindex(jarr::JNIVector, args...) = getindex(jarr.arr, args...)
Base.setindex!(jarr::JNIVector, args...) = setindex!(jarr.arr, args...)
Base.size(jarr::JNIVector, args...; kwargs...) = size(jarr.arr, args...; kwargs...)

function deleteref(x::JNIVector{T}) where T
    if x.arr !== nothing
        release_elements(x)
    end
    deleteref(x.ref)
    x.ref = J_NULL
end

signature(::Type{JNIVector{T}}) where T = string("[", signature(T))
jvalue(jarr::JNIVector) = jarr.ref.ptr
JNIVector{T}(ptr::Ptr{Nothing}) where {T} = JNIVector{T}(JavaLocalRef(ptr))

function convert(::Type{JNIVector{T}}, vec::Vector{T}) where {T}
    arr = JNIVector{T}(length(vec))
    arr .= vec
    return arr
end

JNIVector(vec::Vector{T}) where {T} = convert(JNIVector{T}, vec)

for primitive in [:jboolean, :jchar, :jbyte, :jshort, :jint, :jlong, :jfloat, :jdouble]
    name = jniname(eval(primitive))
    get_elements = :(JNI.$(Symbol("Get$(name)ArrayElements")))
    release_elements = :(JNI.$(Symbol("Release$(name)ArrayElements")))
    new_array = :(JNI.$(Symbol("New$(name)Array")))
    m = quote
        function get_elements!(jarr::JNIVector{$primitive})
            sz = Int(JNI.GetArrayLength(jarr.ref.ptr))
            jarr.arr = unsafe_wrap(Array, $get_elements(jarr.ref.ptr, Ptr{jboolean}(C_NULL)), sz)
            jarr
        end
        JNIVector{$primitive}(sz::Int) = get_elements!(JNIVector{$primitive}($new_array(sz)))
        function release_elements(arg::JNIVector{$primitive})
            $release_elements(arg.ref.ptr, pointer(arg.arr), jint(0))
            arg.arr = nothing
        end
        function convert_result(::Type{JNIVector{$primitive}}, ptr)
            get_elements!(JNIVector{$primitive}(ptr))
        end
        function convert_arg(argtype::Type{Vector{$primitive}}, arg::JNIVector{$primitive})
            release_elements(arg)
            return arg, arg
        end
        function convert_arg(argtype::Type{JNIVector{$primitive}}, arg::JNIVector{$primitive})
            release_elements(arg)
            return arg, arg
        end
        function cleanup_arg(jarr::JNIVector{$primitive})
            get_elements!(jarr)
        end
    end
    eval(m)
end
