
function getclass(obj::JavaObject)
    jcall(obj, "getClass", JClass, ())
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
    elseif @compat startswith(name, "L")
        return name[2:end-1]
    else
        return name
    end
end

function getname(cls::JClass)
    rawname = jcall(cls, "getName", JString, ())
    conventional_name(rawname)
end

function getname(method::JMethod)
    jcall(method, "getName", JString, ())
end

function listmethods(obj::JavaObject)
    cls = getclass(obj)
    jcall(cls, "getMethods", Vector{JMethod}, ())
end

function listmethods(obj::JavaObject, name::String)
    allmethods = listmethods(obj)
    filter(m -> getname(m) == name, allmethods)
end

function getreturntype(method::JMethod)
    jcall(method, "getReturnType", JClass, ())
end

function getparametertypes(method::JMethod)
    jcall(method, "getParameterTypes", Vector{JClass}, ())
end

function Base.show(io::IO, method::JMethod)
    name = getname(method)
    rettype = getname(getreturntype(method))
    argtypes = [getname(c) for c in getparametertypes(method)]
    argtypestr = join(argtypes, ", ")
    print(io, "$rettype $name($argtypestr)")
end

