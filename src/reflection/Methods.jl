module Methods

export classmethods, MethodDescriptor

using JavaCall.JNI
using JavaCall.Signatures
using JavaCall.Conversions
using JavaCall.Core

using JavaCall.Reflection: Classes

#=
Struct to hold information aboud java methods
used to generate functions that call the jni
This should not be a replacement of java.lang.reflect.Method
as it should only store essential information

name:       Name of the method

rettype:    Descriptor for the return class (void methods also
            have a descriptor with Nothing as the juliatype,
            jvoid as the jni type and V signature)

paramtypes: List of descriptors with the parameter types
=#
struct MethodDescriptor
    name::String
    rettype::Classes.ClassDescriptor
    paramtypes::Vector{Classes.ClassDescriptor}
end

function Base.show(io::IO, m::MethodDescriptor)
    print(io, "MethodDescriptor{name: ", m.name, ", ret: ", string(m.rettype), ", params: ", string(m.paramtypes), "}")
end

function Base.:(==)(x::MethodDescriptor, y::MethodDescriptor)
    x.name == y.name && x.rettype == y.rettype && x.paramtypes == y.paramtypes 
end

function descriptorfrommethod(method::jobject)
    name = callinstancemethod(method, :getName, Symbol("java.lang.String"), [])
    rettype = callinstancemethod(method, :getReturnType, Symbol("java.lang.Class"), [])
    paramtypes = callinstancemethod(method, :getParameterTypes, Vector{Symbol("java.lang.Class")}, [])
    MethodDescriptor(
        convert_to_string(String, name), 
        Classes.descriptorfromclass(rettype),
        map(Classes.descriptorfromclass, convert_to_vector(Vector{jclass}, paramtypes)))
end

function classmethods(classname::Symbol)
    array = convert_to_vector(Vector{jobject}, callinstancemethod(
        Classes.findclass(classname).jniclass, 
        :getMethods, 
        Vector{Symbol("java.lang.reflect.Method")}, 
        []))
    map(descriptorfrommethod, array)
end

end

