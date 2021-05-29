module Modifiers

export ModifiersDescriptor

using JavaCall.Conversions
using JavaCall.Core
using JavaCall.JNI

using JavaCall.Reflection: Classes

#=
Struct to hold information about class and member
access modifiers, gathered by processing the constants
that represent this constants with the 
java.lang.reflect.Modifier class

static: Boolean flag set to true if the modifier is static
        and false otherwise

public: Boolean flag set to true if the modifier is public
        and false otherwise
=#
struct ModifiersDescriptor
    static::Bool
    public::Bool
end

function Base.show(io::IO, m::ModifiersDescriptor)
    print(
        io, 
        "ModifiersDescriptor{static: ", m.static, 
        ", public: ", m.public,
        "}");
end

function Base.:(==)(x::ModifiersDescriptor, y::ModifiersDescriptor)
    x.static == y.static &&
    x.public == y.public
end

function methodmodifiers(method::jobject)
    modifiersclass = Classes.findclass(Symbol("java.lang.reflect.Modifier"))
    modifiers = callinstancemethod(method, :getModifiers, jint, [])
    staticmod = convert_to_julia(
        Bool,
        callstaticmethod(modifiersclass.jniclass, :isStatic, jboolean, Any[jint], modifiers)
    )
    publicmod = convert_to_julia(
        Bool,
        callstaticmethod(modifiersclass.jniclass, :isPublic, jboolean, Any[jint], modifiers)
    )
    ModifiersDescriptor(staticmod, publicmod)
end

end
