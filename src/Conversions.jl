module Conversions

using JavaCall.JNI
using JavaCall.CodeGeneration

import Base: convert

# Conversion of primitive types
Base.convert(::Type{Bool}, x::jboolean) = (x == true)

function Base.convert(::Type{String}, str::jobject)
    iscopy = Ref(JNI_TRUE)
    iscopyptr = convert(Ptr{jboolean}, pointer_from_objref(iscopy))
    unsafe_string(JNI.get_string_utfchars(str, iscopyptr))
end

function Base.convert(::Type{Vector{jobject}}, array::jobjectArray)
    vector = jobject[]
    len = JNI.get_array_length(array)
    for i in 1:len
        push!(vector, JNI.get_object_array_element(array, i-1))
    end
    vector
end

end
