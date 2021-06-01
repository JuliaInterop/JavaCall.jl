module Classes

export ClassDescriptor, findclass, isarray, isinterface, superclass,
       descriptorfromclass

using JavaCall.JNI
using JavaCall.Signatures
using JavaCall.Core
using JavaCall.Conversions

const SymbolOrExpr = Union{Expr, Symbol}

#=
Struct to hold information aboud java classes
used to generate functions that call the jni
This should not be a replacement of java.lang.Class
as it should only store essential information.

This struct is mutable as it has lazy loaded fields

jniclass:   object returned by the JNI for the class
            that this descriptor represents

juliatype:  holds the Symbol of the expected julia type 
            for this class (ex: :JObject for java.lang.Object,
            :Int64 for int and :(Vector{JObject}) for
            java.lang.Object[])

jnitype:    type to be used when interfacing with the JNI
            (ex: jobject for java.lang.Object, jint for int
            and jobject for java.lang.Object[])

signature:  holds the signature of this symbol to be
            used in calls (ex: Ljava.lang.Object; for
            java.lang.Object, I for int and [Ljava.lang.Object;
            for java.lang.Object[])

component:  holds information about the component type if the
            corresponding java class is an array

superclass: holds information about the super class of the
            represented java class (has the value of nothing
            for object) this attribute is not always required
            and so it is lazy loaded

=#
mutable struct ClassDescriptor
    jniclass::jclass
    juliatype::SymbolOrExpr
    jnitype::Symbol
    signature::String
    component::Union{ClassDescriptor, Nothing}
    superclass::Union{ClassDescriptor, Nothing}
end

ClassDescriptor(jniclass, juliatype, jnitype, signature) = 
    ClassDescriptor(jniclass, juliatype, jnitype, signature, nothing, nothing)

ClassDescriptor(jniclass, juliatype, jnitype, signature, component) = 
    ClassDescriptor(jniclass, juliatype, jnitype, signature, component, nothing)

isarray(d::ClassDescriptor) = d.component !== nothing

isinterface(d::ClassDescriptor) = convert_to_julia(
    Bool, 
    callinstancemethod(d.jniclass, :isInterface, jboolean, [])
)

function Base.show(io::IO, c::ClassDescriptor)
    print(
        io, 
        "ClassDescriptor{juliatype: ", c.juliatype, 
        ", jnitype: ", c.jnitype, 
        ", signature: ", c.signature, 
        (c.component !== nothing ? string(", component: ", c.component) : ""),
        "}"
    )
end

function Base.:(==)(x::ClassDescriptor, y::ClassDescriptor)
    x.juliatype == y.juliatype && 
    x.jnitype == y.jnitype && 
    x.signature == y.signature &&
    x.component == y.component
end

function superclass(descriptor::ClassDescriptor)
    # Lazy load superclass
    if descriptor.superclass === nothing && 
        descriptor.juliatype != :JObject &&
        !isprimitive(descriptor.jniclass)
        
        descriptor.superclass = descriptorfromclass(
            JNI.get_superclass(descriptor.jniclass)
        )
    end
    descriptor.superclass
end
    
const _CLASS_FOR_NAME_SIGNATURE = signature(
    MethodSignature(Symbol("java.lang.Class"), [Symbol("java.lang.String")])
)

const _JULIA_TYPES_FROM_NAME = Dict(
    "boolean" => :Bool,
    "byte" => :Int8,
    "char" => :Char,
    "short" => :Int16,
    "int" => :Int32,
    "long" => :Int64,
    "float" => :Float32,
    "double" => :Float64,
    "void" => :Nothing
)

const _JNI_TYPES_FROM_NAME = Dict(
    "boolean" => :jboolean,
    "byte" => :jbyte,
    "char" => :jchar,
    "short" => :jshort,
    "int" => :jint,
    "long" => :jlong,
    "float" => :jfloat,
    "double" => :jdouble,
    "void" => :jvoid
)

const _JNI_ARRAY_TYPES_FROM_NAME = Dict(
    "boolean" => :jbooleanArray,
    "byte" => :jbyteArray,
    "char" => :jcharArray,
    "short" => :jshortArray,
    "int" => :jintArray,
    "long" => :jlongArray,
    "float" => :jfloatArray,
    "double" => :jdoubleArray
)

const _SIGNATURES_FROM_NAME = Dict(
    "boolean" => signature(jboolean),
    "byte" => signature(jbyte),
    "char" => signature(jchar),
    "short" => signature(jshort),
    "int" => signature(jint),
    "long" => signature(jlong),
    "float" => signature(jfloat),
    "double" => signature(jdouble),
    "void" => signature(jvoid)
)

isprimitive(class::jclass) = convert_to_julia(
    Bool, 
    callinstancemethod(class, :isPrimitive, jboolean, [])
)

isarray(class::jclass) = convert_to_julia(
    Bool, 
    callinstancemethod(class, :isArray, jboolean, [])
)

classname(class::jclass) = convert_to_string(
    String, 
    callinstancemethod(class, :getCanonicalName, Symbol("java.lang.String"), [])
)

componenttype(class::jclass) = 
    callinstancemethod(class, :getComponentType, Symbol("java.lang.Class"), [])


function juliatypefromclass(class::jclass)
    if isprimitive(class)
        _JULIA_TYPES_FROM_NAME[classname(class)]
    elseif isarray(class)
        :(Vector{$(juliatypefromclass(componenttype(class)))})
    else
        name = classname(class)
        Symbol(string('J', name[findlast('.', name) + 1:end]))
    end
end

function jnitypefromclass(class::jclass)
    if isprimitive(class)
        _JNI_TYPES_FROM_NAME[classname(class)]
    elseif isarray(class)
        component = componenttype(class)
        if isprimitive(component)
            name = classname(component)
            if name == "void"
                error("Array of void detected")
            end
            _JNI_ARRAY_TYPES_FROM_NAME[name]
        else
            :jobjectArray
        end
    else
        :jobject
    end
end

function signaturefromclass(class::jclass)
    if isprimitive(class)
        _SIGNATURES_FROM_NAME[classname(class)]
    elseif isarray(class)
        string("[", signaturefromclass(componenttype(class)))
    else
        fullyqualifiedname(classname(class))
    end
end

function getcomponenttype(class::jclass)
    (isarray(class) ? descriptorfromclass(componenttype(class)) : nothing)
end

descriptorfromclass(class::jclass) = ClassDescriptor(
    class,
    juliatypefromclass(class),
    jnitypefromclass(class),
    signaturefromclass(class),
    getcomponenttype(class),
    nothing
)

findclass(classname::Symbol)::ClassDescriptor = 
    descriptorfromclass(JNI.find_class(searchname(classname)))

end
