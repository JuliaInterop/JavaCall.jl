module Modifiers

export ModifiersDescriptor

using JavaCall.Conversions
using JavaCall.Core
using JavaCall.JNI

using JavaCall.Reflection: Classes

#=
Struct to hold information about the modifiers
of a given method. It is a complement to the
MethodDescriptor struct and should store the results
of analysing the java.lang.reflect.Method#getModifiers
method

static: Boolean flag set to true if the method is static
        and false otherwise
=#
struct ModifiersDescriptor
    static::Bool
end

function Base.show(io::IO, m::ModifiersDescriptor)
    print(io, "ModifiersDescriptor{static: ", m.static, "}");
end

function Base.:(==)(x::ModifiersDescriptor, y::ModifiersDescriptor)
    x.static == y.static
end

function methodmodifiers(method::jobject)
    modifiersclass = Classes.findclass(Symbol("java.lang.reflect.Modifier"))
    modifiers = callinstancemethod(method, :getModifiers, jint, [])
    staticmod = convert_to_julia(
        Bool,
        callstaticmethod(modifiersclass.jniclass, :isStatic, jboolean, Any[jint], modifiers)
    )
    ModifiersDescriptor(staticmod)
end

end
