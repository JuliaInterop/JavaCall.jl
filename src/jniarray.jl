jniname(::Type{jboolean}) = "Boolean"
jniname(::Type{jbyte}) = "Byte"
jniname(::Type{jchar}) = "Char"
jniname(::Type{jshort}) = "Short"
jniname(::Type{jint}) = "Int"
jniname(::Type{jlong}) = "Long"
jniname(::Type{jfloat}) = "Float"
jniname(::Type{jdouble}) = "Double"


mutable struct JNIArray{T,N}
    ptr
    arr::Union{Nothing,Array{T,N}}
end

JNIArray(ptr) = get_elements!(JNIArray)
signature(::Type{JNIArray{T,N}}) where {T,N} = string("[" ^ N, signature(T))
jvalue(jarr::JNIArray) = jarr.ptr

for primitive in [:jboolean, :jchar, :jbyte, :jshort, :jint, :jlong, :jfloat, :jdouble]
    name = jniname(eval(primitive))
    get_elements = :(JNI.$(Symbol("Get$(name)ArrayElements")))
    release_elements = :(JNI.$(Symbol("Release$(name)ArrayElements")))
    m = quote
        function get_elements!(jarr::JNIArray{$primitive, N}) where N
            sz = Int(JNI.GetArrayLength(jarr.ptr))
            jarr.arr = unsafe_wrap(Array, $get_elements(jarr.ptr, Ptr{jboolean}(C_NULL)), sz)
            jarr
        end
        function convert_result(::Type{JNIArray{$primitive, N}}, ptr) where N
            get_elements!(JNIArray{$primitive,N}(ptr, nothing))
        end
        function convert_arg(argtype::Type{Vector{$primitive}}, arg::JNIArray{$primitive,1}) where N
            $release_elements(arg.ptr, pointer(arg.arr), jint(0))
            arg.arr = nothing
            return arg, arg.ptr
        end
        function convert_arg(argtype::Type{JNIArray{$primitive,1}}, arg::JNIArray{$primitive,1}) where N
            $release_elements(arg.ptr, pointer(arg.arr), jint(0))
            arg.arr = nothing
            return arg, arg
        end
        function cleanup_arg(jarr::JNIArray{$primitive, N}) where N
            get_elements!(jarr)
        end
    end
    eval(m)
end
