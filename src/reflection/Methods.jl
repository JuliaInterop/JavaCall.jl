module Methods

export findmethod, classmethods

using JavaCall.JNI
using JavaCall.Signatures

using JavaCall.Reflection: Classes

const _GET_METHODS_SIGNATURE = signature(MethodSignature(
    Vector{Symbol("java.lang.reflect.Method")},
    []
))

_getmethods_id = nothing

function getmethods_id()
    global _getmethods_id
    if _getmethods_id === nothing
        _getmethods_id = JNI.get_method_id(
            Classes.class_obj(), 
            "getMethods", 
            _GET_METHODS_SIGNATURE)
    end
    _getmethods_id
end

function classmethods(classname::Symbol)
    metaclass = Classes.findmetaclass(classname)
    JNI.call_object_method_a(
        metaclass,
        getmethods_id(),
        jvalue[])
end

end

