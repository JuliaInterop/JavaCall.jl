module Methods

export classmethods, MethodDescriptor

using JavaCall.JNI
using JavaCall.Signatures
using JavaCall.Conversions
using JavaCall.Core

using JavaCall.Reflection: Classes

# Struct to hold information aboud java methods
# used to generate functions that call the jni
# This should not be a replacement of java.lang.reflect.Method
# as it should only store essential information
struct MethodDescriptor
    name::String
    rettype::Any
    paramtypes::Vector{Any}
end

function Base.show(io::IO, m::MethodDescriptor)
    print(io, "MethodDescriptor{name: ", m.name, ", ret: ", string(m.rettype), ", params: ", string(m.paramtypes), "}")
end

function Base.:(==)(x::MethodDescriptor, y::MethodDescriptor)
    x.name == y.name && x.rettype == y.rettype && x.rettype == y.rettype 
end

function descriptorfrommethod(method::jobject)
    name = callinstancemethod(method, :getName, Symbol("java.lang.String"), [])
    rettype = callinstancemethod(method, :getReturnType, Symbol("java.lang.Class"), [])
    paramtypes = callinstancemethod(method, :getParameterTypes, Vector{Symbol("java.lang.Class")}, [])
    MethodDescriptor(
        convert(String, name), 
        Classes.juliatypefromclass(rettype),
        map(Classes.juliatypefromclass, convert(Vector{jclass}, paramtypes)))
end

function classmethods(classname::Symbol)
    array = convert(Vector{jobject}, callinstancemethod(
        Classes.findmetaclass(classname), 
        :getMethods, 
        Vector{Symbol("java.lang.reflect.Method")}, 
        []))
    map(descriptorfrommethod, array)
end

end

