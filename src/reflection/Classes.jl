module Classes

export findclass, findmetaclass, class_obj, juliatypefromclass

using JavaCall.JNI
using JavaCall.Signatures
using JavaCall.Core
using JavaCall.Conversions
    
const _CLASS_FOR_NAME_SIGNATURE = signature(
    MethodSignature(Symbol("java.lang.Class"), [Symbol("java.lang.String")])
)

const _PRIMITIVE_TYPES_FROM_NAME = Dict(
    "boolean" => jboolean,
    "byte" => jbyte,
    "char" => jchar,
    "short" => jshort,
    "int" => jint,
    "long" => jlong,
    "float" => jfloat,
    "double" => jdouble,
    "void" => jvoid
)

_class_obj = nothing
_forname_id = nothing

isprimitive(class::jclass) = convert(
    Bool, 
    callinstancemethod(class, :isPrimitive, jboolean, [])
)

isarray(class::jclass) = convert(
    Bool, 
    callinstancemethod(class, :isArray, jboolean, [])
)

classname(class::jclass) = convert(
    String, 
    callinstancemethod(class, :getCanonicalName, Symbol("java.lang.String"), [])
)

componenttype(class::jclass) = 
    callinstancemethod(class, :getComponentType, Symbol("java.lang.Class"), [])


function juliatypefromclass(class::jclass)
    if isprimitive(class)
        _PRIMITIVE_TYPES_FROM_NAME[classname(class)]
    elseif isarray(class)
        Vector{juliatypefromclass(componenttype(class))}
    else
        Symbol(classname(class))
    end
end

function class_obj()
    global _class_obj
    if _class_obj === nothing
        _class_obj = JNI.find_class(searchname(Symbol("java.lang.Class")))
    end
    _class_obj
end

function _forname_methodid()
    global _forname_id
    if _forname_id === nothing
        _forname_id = JNI.get_static_method_id(class_obj(), "forName", _CLASS_FOR_NAME_SIGNATURE)
    end
    _forname_id
end

findclass(classname::Symbol)::jclass = JNI.find_class(searchname(classname))

function findmetaclass(classname::Symbol)::jclass
    classnamechars = map(jchar, collect(string(classname)))
    JNI.call_static_object_method_a(
        class_obj(),
        _forname_methodid(),
        jvalue[JNI.new_string(classnamechars, length(classnamechars))])
end

end
