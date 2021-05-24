module Conversions

export convert_to_julia, convert_to_jni, convert_to_string, convert_to_vector

using JavaCall.JNI
using JavaCall.CodeGeneration

# Conversion of primitive types.

convert_to_julia(::Type{Bool}, x::jboolean)::Bool = (x == JNI_TRUE)
convert_to_jni(::Type{jboolean}, x::Bool)::jboolean = x ? JNI_TRUE : JNI_FALSE

convert_to_julia(::Type{Int8}, x::jbyte)::Int8 = x
convert_to_jni(::Type{jbyte}, x::Int8)::jbyte = x

convert_to_julia(::Type{Char}, x::jchar)::Char = Char(x)
# May overflow as julia chars have 4 bytes and java
# chars have 2 bytes. Should not happen for UTF-16 chars.
convert_to_jni(::Type{jchar}, x::Char)::jchar = jchar(x)

convert_to_julia(::Type{Int16}, x::jshort)::Int16 = x
convert_to_jni(::Type{jshort}, x::Int16)::jshort = x

convert_to_julia(::Type{Int32}, x::jint)::Int32 = x
convert_to_jni(::Type{jint}, x::Int32)::jint = x

convert_to_julia(::Type{Int64}, x::jlong)::Int64 = x
convert_to_jni(::Type{jlong}, x::Int64)::jlong = x

convert_to_julia(::Type{Float32}, x::jfloat)::Float32 = x
convert_to_jni(::Type{jfloat}, x::Float32)::jfloat = x

convert_to_julia(::Type{Float64}, x::jdouble)::Float64 = x
convert_to_jni(::Type{jdouble}, x::Float64)::jdouble = x

convert_to_julia(::Type{Nothing}, ::jvoid)::Nothing = nothing
convert_to_jni(::Type{jvoid}, ::Nothing)::jvoid = nothing

# Conversion of vectors for primitive types
for (julia_type, jni_type, jni_arraytype, jni_function) in [
    (:Bool, :jboolean, :jbooleanArray, :get_boolean_array_elements),
    (:Int8, :jbyte, :jbyteArray, :get_byte_array_elements),
    (:Char, :jchar, :jcharArray, :get_char_array_elements),
    (:Int16, :jshort, :jshortArray, :get_short_array_elements),
    (:Int32, :jint, :jintArray, :get_int_array_elements),
    (:Int64, :jlong, :jlongArray, :get_long_array_elements),
    (:Float32, :jfloat, :jfloatArray, :get_float_array_elements),
    (:Float64, :jdouble, :jdoubleArray, :get_double_array_elements)
]
    params = [
        :(::Type{Vector{$julia_type}}),
        :(array::$jni_arraytype)
    ]
    body = quote
        array_len = JNI.get_array_length(array)
        iscopy = Ref(JNI_TRUE)
        iscopyptr = convert(Ptr{jboolean}, pointer_from_objref(iscopy))
        returnptr = JNI.$jni_function(array, iscopyptr)
        collect(map(x -> convert($julia_type, x), unsafe_wrap(Vector{$jni_type}, returnptr, (array_len,))))
    end
    eval(generatemethod(
        :convert_to_julia,
        params,
        body
    ))
end


# Auxiliary conversions for simplifying types interface
# between languages

function convert_to_string(::Type{String}, str::jobject)
    iscopy = Ref(JNI_TRUE)
    iscopyptr = convert(Ptr{jboolean}, pointer_from_objref(iscopy))
    unsafe_string(JNI.get_string_utfchars(str, iscopyptr))
end

#=
This method offers an intermediate representation 
for arrays of java objects that does not require
full transformation to julia types
=#
function convert_to_vector(::Type{Vector{jobject}}, array::jobjectArray)
    vector = jobject[]
    len = JNI.get_array_length(array)
    for i in 1:len
        push!(vector, JNI.get_object_array_element(array, i-1))
    end
    vector
end

end
