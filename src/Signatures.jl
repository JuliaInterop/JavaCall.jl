module Signatures

export searchname, signature, fullyqualifiedname, MethodSignature

using JavaCall.JNI

struct MethodSignature
    returntype::Any
    parametertypes::Vector{Any}
end

searchname(name::String) = replace(name, "." => "/")
searchname(name::Symbol) = searchname(string(name))

fullyqualifiedname(name::String) = string("L", searchname(name), ";")

signature(::Type{jboolean}) = "Z"
signature(::Type{jbyte}) = "B"
signature(::Type{jchar}) = "C"
signature(::Type{jshort}) = "S"
signature(::Type{jint}) = "I"
signature(::Type{jlong}) = "J"
signature(::Type{jfloat}) = "F"
signature(::Type{jdouble})= "D"
signature(::Type{jvoid}) = "V"

signature(::Type{Array{T,N}}) where {T,N} = string("[" ^ N, signature(T))

signature(sym::Symbol) = fullyqualifiedname(string(sym))

signature(s::MethodSignature) = 
    string("(", map(signature, s.parametertypes)..., ")", signature(s.returntype))

end
