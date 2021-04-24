jniname(::Type{jboolean}) = "Boolean"
jniname(::Type{jbyte}) = "Byte"
jniname(::Type{jchar}) = "Char"
jniname(::Type{jshort}) = "Short"
jniname(::Type{jint}) = "Int"
jniname(::Type{jlong}) = "Long"
jniname(::Type{jfloat}) = "Float"
jniname(::Type{jdouble}) = "Double"


mutable struct JNIArray{T,N}
    arr
end
signature(::Type{JNIArray{T,N}}) where {T,N} = string("[" ^ N, signature(T))

for primitive in [:jboolean, :jchar, :jbyte, :jshort, :jint, :jlong, :jfloat, :jdouble]
    name = jniname(eval(primitive))
    get_elements = :(JNI.$(Symbol("Get$(name)ArrayElements")))
    m = quote
        function convert_result(::Type{JNIArray{$primitive, N}}, ptr) where N
            sz = Int(JNI.GetArrayLength(ptr))
            JNIArray{$primitive,N}(unsafe_wrap(Array, $get_elements(ptr, UInt8[JNI.JNI_FALSE]), sz))
        end
    end
    eval(m)
end
