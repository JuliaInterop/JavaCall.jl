
using JavaCall
using Compat

if !JavaCall.isloaded()
    JavaCall.init([])
end

JJClass = @jimport java.lang.Class
JMethod = @jimport java.lang.reflect.Method

function getclass(obj::JavaObject)
    jcall(obj, "getClass", JJClass, ())
end

function conventional_name(name::String)
    if @compat startswith(name, "[")
        return conventional_name(name[2:end]) * "[]"
    elseif name == "Z"
        return "boolean"
    elseif name == "B"
        return "byte"
    elseif name == "C"
        return "char"
    elseif name == "I"
        return "int"
    elseif name == "J"
        return "long"
    elseif name == "F"
        return "float"
    elseif name == "D"
        return "double"
    elseif name == "V"
        return "void"
    else
        return name
    end
end

function getclassname(cls::JJClass)
    rawname = jcall(cls, "getName", JString, ())
    return conventional_name(rawname)
end

function listmethods(obj::JavaObject)
    cls = getclass(obj)
    methods = jcall(cls, "getMethods", Vector{JMethod}, ())
end

function Base.show(io::IO, method::JMethod)
    name = jcall(method, "getName", JString, ())
    rettype = getclassname(jcall(method, "getReturnType", JJClass, ()))
    argtypes = [getclassname(c) for c in
                jcall(method, "getParameterTypes", Vector{JJClass}, ())]
    argtypestr = join(argtypes, ", ")
    print(io, "$rettype $name($argtypestr)")
end
