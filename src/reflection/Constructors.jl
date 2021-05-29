module Constructors

export classconstructors, ConstructorDescriptor

using JavaCall.JNI
using JavaCall.Conversions
using JavaCall.Core

using JavaCall.Reflection: Classes

#=
Struct to hold information about java constructors
used to generate constructors that call the jni
This is not a replacement for java.lang.reflect.Constructor
as it only stores essential information

paramtypes: List of ClassDescriptor with the parameter
            types accepted by the constructor
=#
struct ConstructorDescriptor
    paramtypes::Vector{Classes.ClassDescriptor}
end

function Base.show(io::IO, c::ConstructorDescriptor)
    print(io, "ConstructorDescriptor{paramtypes: ", c.paramtypes, "}");
end

function Base.:(==)(x::ConstructorDescriptor, y::ConstructorDescriptor)
    x.paramtypes == y.paramtypes
end

function descriptorfromconstructor(constructor::jobject)
    paramtypes = callinstancemethod(
        constructor, 
        :getParameterTypes, 
        Vector{Symbol("java.lang.Class")}, 
        [])
    ConstructorDescriptor(map(
        Classes.descriptorfromclass, 
        convert_to_vector(Vector{jclass}, paramtypes)
    ))
end

classconstructors(classname::Symbol) = classconstructors(Classes.findclass(classname))

function classconstructors(classdescriptor::Classes.ClassDescriptor)
    array = convert_to_vector(Vector{jobject}, callinstancemethod(
        classdescriptor.jniclass, 
        :getConstructors, 
        Vector{Symbol("java.lang.reflect.Constructor")}, 
        []))
    map(descriptorfromconstructor, array)
end    

end
