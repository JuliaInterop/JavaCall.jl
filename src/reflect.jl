
function getclass(obj::JavaObject)
    jcall(obj, "getClass", JClass, ())
end

function conventional_name(name::AbstractString)
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

"""
```
getname(cls::JClass)
```
Returns the fully qualified name of the java class

### Args
* cls: The JClass object

### Returns
The fully qualified name of the java class
"""
function getname(cls::JClass)
    rawname = jcall(cls, "getName", JString, ())
    conventional_name(rawname)
end

"""
```
getname(method::JMethod)
```
Returns the fully qualified name of the java method

### Args
* cls: The JClass method

### Returns
The fully qualified name of the method
"""
function getname(method::JMethod)
    jcall(method, "getName", JString, ())
end

"""
```
listmethods(obj::JavaObject)
```
Lists the methods that are available on the java object passed

### Args
* obj: The java object

### Returns
List of methods
"""
function listmethods(obj::JavaObject)
    cls = getclass(obj)
    jcall(cls, "getMethods", Vector{JMethod}, ())
end

"""
```
listmethods(obj::JavaObject, name::AbstractString)
```
Lists the methods that are available on the java object passed. The methods are filtered based on the name passed

### Args
* obj: The java object
* name: The filter (e.g. method name)

### Returns
List of methods available on the java object and matching the name passed
"""
function listmethods(obj::JavaObject, name::AbstractString)
    allmethods = listmethods(obj)
    filter(m -> getname(m) == name, allmethods)
end

"""
```
getreturntype(method::JMethod)
```
Returns the return type of the java method

### Args
* method: The java method object

### Returns
Returns the type of the return object as a JClass
"""
function getreturntype(method::JMethod)
    jcall(method, "getReturnType", JClass, ())
end

"""
```
getparametertypes(method::JMethod)
```
Returns the parameter types of the java method

### Args
* method: The java method object

### Returns
Vector the parametertypes 
"""
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

