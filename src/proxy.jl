import Base.==

# See documentation for JProxy for infomation

const JField = JavaObject{Symbol("java.lang.reflect.Field")}
genericFieldInfo = nothing

struct JMethodInfo
    name::String
    juliaType::Type
    void::Bool
    argTypes::Tuple
    argClasses::Array{JavaObject}
    id::Ptr{Nothing}
    static::Bool
    owner::JavaMetaClass
    primitive::Bool
    convertType::Type
end

struct JavaTypeInfo
    setterFunc
    signature::AbstractString
    juliaType::Type
    convertType::Type
    getter::Ptr{Nothing}
    staticGetter::Ptr{Nothing}
    setter::Ptr{Nothing}
    staticSetter::Ptr{Nothing}
end

struct JFieldInfo
    field::JField
    name::String
    info::JavaTypeInfo
    static::Bool
    id
    juliaType::Type
    fieldClass::JClass
    fieldJType::Type
    owner::JClass
    primitive::Bool
    function JFieldInfo(field)
        name = getname(field)
        fcl = jcall(field, "getType", JClass, ())
        fjt = JavaObject{Symbol(getname(fcl))}
        typ = juliaTypeFor(getname(fcl))
        static = isStatic(field)
        cls = jcall(field, "getDeclaringClass", JClass, ())
        id = fieldId(name, JavaObject{Symbol(getname(fcl))}, static, field, cls)
        info = get(typeInfo, getname(fcl), genericFieldInfo)
        new(field, name, info, static, id, typ, fcl, fjt, cls, isPrimitive(fcl))
    end
end
                      
struct JMethodProxy
    receiver
    name
    methods::Set{JMethodInfo}
    static::Bool
end

struct JClassInfo
    class::JClass
    fields::Dict{Symbol, JFieldInfo}
    methods::Dict{Symbol, Set{JMethodInfo}}
    JClassInfo(class) = new(class, fieldDict(class), methodDict(class))
end

"""
    JProxy(s::AbstractString)
    JProxy(::JavaMetaClass)
    JProxy(::Type{JavaObject}; static=false)
    JProxy(obj::JavaObject; static=false)

Create a proxy for a Java object that you can use like a Java object. Field and method syntax is like in Java. Primitive types and strings are converted to Julia objects on field accesses and method returns and converted back to Java types when sent as arguments to Java methods.

*NOTE: Because of this, if you need to call Java methods on a string that you got from Java, you'll have to use `JProxy(str)` to convert the Julia string to a proxied Java string*

To invoke static methods, set static to true.

#Example
```jldoctest
julia> a=JProxy(@jimport(java.util.ArrayList)(()))
[]

julia> a.size()
0

julia> a.add("hello")
true

julia> a.get(0)
"hello"

julia> a.isEmpty()
false

julia> a.toString()
"[hello]"

julia> b = a.clone()
[hello]

julia> b.add("derp")
true

julia> a == b
false

julia> b == b
true

julia> JProxy(@jimport(java.lang.System)).getName()
"java.lang.System"

julia> JProxy(@jimport(java.lang.System);static=true).out.println("hello")
hello
```
"""
struct JProxy
    obj::JavaObject
    info::JClassInfo
    static::Bool
    JProxy(s::AbstractString) = JProxy(JString(s))
    JProxy(::JavaMetaClass{C}) where C = JProxy(JavaObject{C}; static=true)
    JProxy(::Type{JavaObject{C}}; static=false) where C = JProxy(classforname(string(C)); static=static)
    JProxy(obj::JavaObject; static=false) = new(static ? obj : narrow(obj), infoFor(static ? obj : getclass(obj)), static)
end

classes = Dict()
methodCache = Dict{Tuple{String, String, Array{String}}, JMethodInfo}()
modifiers = JavaObject{Symbol("java.lang.reflect.Modifier")}
juliaConverters = Dict()
typeInfo = nothing

pxyObj(p::JProxy) = getfield(p, :obj)
pxyPtr(p::JProxy) = pxyObj(p).ptr
pxyInfo(p::JProxy) = getfield(p, :info)
pxyStatic(p::JProxy) = getfield(p, :static)

==(j1::JProxy, j2::JProxy) = Int64(ccall(jnifunc.IsSameObject, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}), penv, pxyPtr(j1), pxyPtr(j2))) != 0

function methodInfo(m::JMethod)
    name, returnType, argTypes = getname(m), getreturntype(m), getparametertypes(m)
    cls = jcall(m, "getDeclaringClass", JClass, ())
    methodKey = (getname(cls), name, getname.(argTypes))
    get!(methodCache, methodKey) do
        methodId = getmethodid(m, cls, name, returnType, argTypes)
        typeName = getname(returnType)
        info = get(typeInfo, typeName, genericFieldInfo)
        juliaType = juliaTypeFor(typeName)
        owner = metaclass(getname(cls))
        JMethodInfo(name, juliaType, typeName == "void", Tuple(juliaTypeFor.(argTypes)), argTypes, methodId, isStatic(m), owner, length(info.signature) == 1, info.convertType)
    end
end

isClass(obj::JavaObject) = false

function isStatic(meth::Union{JMethod,JField})
    global modifiers

    mods = jcall(meth, "getModifiers", jint, ())
    jcall(modifiers, "isStatic", jboolean, (jint,), mods) != 0
end

conv(func::Function, typ::String) = juliaConverters[typ] = func

macro typeInf(sig, typ, jtyp, object, Typ)
    s = (p, t)-> :(jnifunc.$(Symbol(p * string(t) * "Field")))
    :(JavaTypeInfo($sig, $typ, $jtyp, $(s("Get", Typ)), $(s("GetStatic", Typ)), $(s("Set", Typ)), $(s("SetStatic", Typ))) do field, obj, value::$(object ? :JavaObject : typ)
        ccall(field.static ? field.info.staticSetter : field.info.setter, Ptr{Nothing},
            (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, $(object ? :(Ptr{Nothing}) : typ)),
            penv, (field.static ? field.owner : obj).ptr, field.id, $(object ? :(value.ptr) : :value))
    end)
end

function initProxy()
    conv("java.lang.String") do x; unsafe_string(x); end
    conv("java.lang.Integer") do x; JProxy(x).intValue(); end
    conv("java.lang.Long") do x; JProxy(x).longValue(); end
    global typeInfo = Dict([
        "int" => @typeInf("I", jint, Int32, false, Int)
        "long" => @typeInf("J", jlong, Int64, false, Long)
        "byte" => @typeInf("B", jbyte, Int8, false, Byte)
        "boolean" => @typeInf("Z", jboolean, Bool, false, Boolean)
        "char" => @typeInf("C", jchar, Char, false, Char)
        "short" => @typeInf("S", jshort, Int16, false, Short)
        "float" => @typeInf("F", jfloat, Float32, false, Float)
        "double" => @typeInf("D", jdouble, Float64, false, Double)
        "void" => @typeInf("V", jint, Nothing, false, Object)
        "java.lang.String" => @typeInf("Ljava/lang/String;", String, String, true, Object)
    ])
    global genericFieldInfo = @typeInf("Ljava/lang/Object", Any, JObject, true, Object)
end

metaclass(class::AbstractString) = metaclass(Symbol(class))

function getmethodid(meth::JMethod, cls::JClass, name::AbstractString, rettype::JClass, argtypes::Vector{JClass})
    sig = proxyMethodSignature(rettype, argtypes)
    jclass = metaclass(getname(cls))
    result = ccall(isStatic(meth) ? jnifunc.GetStaticMethodID : jnifunc.GetMethodID, Ptr{Nothing},
                   (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
                   penv, jclass, name, sig)
    if result == C_NULL
        println("ERROR CALLING METHOD class: ", jclass, ", name: ", name, ", sig: ", sig, ", arg types: ", argtypes)
    end
    result==C_NULL && geterror()
    result
end

function fieldId(name, typ::Type{JavaObject{C}}, static, field, cls::JClass) where {C}
    id = ccall(static ? jnifunc.GetStaticFieldID : jnifunc.GetFieldID, Ptr{Nothing},
               (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
               penv, metaclass(getname(cls)), name, proxyClassSignature(string(C)))
    id == C_NULL && geterror(true)
    id
end

function infoSignature(cls::AbstractString)
    info = get(typeInfo, cls, nothing)
    if info != nothing; info.signature; end
end

function proxyClassSignature(cls::AbstractString)
    sig = infoSignature(cls)
    sig != nothing ? sig : proxyClassSignature(classforname(cls))
end

function proxyClassSignature(cls::JavaObject)
    sig = []
    while jcall(cls, "isArray", jboolean, ()) != 0
        push!(sig, "[")
        cls = jcall(cls, "getComponentType", JClass, ())
    end
    clSig = infoSignature(jcall(cls, "getSimpleName", JString, ()))
    push!(sig, clSig != nothing ? clSig : "L" * javaclassname(getname(cls)) * ";")
    join(sig, "")
end

function proxyMethodSignature(rettype, argtypes)
    s = IOBuffer()
    write(s, "(")
    for arg in argtypes
        write(s, proxyClassSignature(arg))
    end
    write(s, ")")
    write(s, proxyClassSignature(rettype))
    String(take!(s))
end

juliaTypeFor(class::JavaObject) = juliaTypeFor(getname(class))
function juliaTypeFor(name::AbstractString)
    info = get(typeInfo, name, nothing)
    info != nothing ? info.juliaType : JavaObject{Symbol(name)}
end

infoFor(class::JClass) = haskey(classes, class) ? classes[class] : (classes[class] = JClassInfo(class))

getname(field::JField) = jcall(field, "getName", JString, ())

listfields(cls::JClass) = jcall(cls, "getFields", Vector{JField}, ())
listfields(cls::Type{JavaObject{C}}) where C = jcall(classforname(string(C)), "getFields", Vector{JField}, ())

fieldDict(class::JClass) = Dict([Symbol(getname(item)) => JFieldInfo(item) for item in listfields(class)])

function methodDict(class::JClass)
    d = Dict()
    for method in listmethods(class)
        s = get!(()->Set(), d, Symbol(getname(method)))
        push!(s, methodInfo(method))
    end
    d
end

fits(method::JMethodInfo, args::Tuple) = length(method.argTypes) == length(args) && all(canConvert.(method.argTypes, args))

canConvert(::Type{JavaObject{Symbol("java.lang.Object")}}, ::Union{AbstractString, Real}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Double")}}, ::Union{Float64, Float32, Float16, Int64, Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Float")}}, ::Union{Float32, Float16, Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Long")}}, ::Union{Int64, Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Integer")}}, ::Union{Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Short")}}, ::Union{Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Byte")}}, ::Union{Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Character")}}, ::Union{Int8, Char}) = true
canConvert(::Type{JString}, ::AbstractString) = true
canConvert(::Type{<: Real}, ::T) where {T <: Real} = true
canConvert(::Type{jboolean}, ::Bool) = true
canConvert(::Type{jchar}, ::Char) = true
canConvert(::Type{<:Integer}, ::Ptr{Nothing}) = true
canConvert(x, y) = false
convert(::Type{JObject}, pxy::JProxy) = JavaObject(pxy)

function (pxy::JMethodProxy)(args...)
    targets = Set(m for m in pxy.methods if fits(m, args))
    if !isempty(targets)
        # Find the most specific method
        meth = reduce(((x, y)-> generality(x, y) < generality(y, x) ? x : y), filterStatic(pxy, targets))
        convertedArgs = convert.(meth.argTypes, args)
        result = _jcall(meth.static ? meth.owner : pxy.receiver, meth.id, C_NULL, meth.juliaType, meth.argTypes, convertedArgs...)
        if !meth.void; asJulia(meth.convertType, result); end
    end
end

function filterStatic(pxy::JMethodProxy, targets)
    static = pxy.static
    Set(target for target in targets if target.static == static)
end

convertPointers(typ, val) = isa(val, Ptr) ? convert(typ, val) : val

isNull(obj::JavaObject) = isNull(obj.ptr)
isNull(ptr::Ptr{Nothing}) = Int64(ptr) == 0

asJulia(t, obj) = obj
asJulia(::Type{Bool}, obj) = obj != 0
function asJulia(x, obj::JavaObject)
    if isNull(obj)
        obj
    else
        obj = narrow(obj)
        (get(juliaConverters, classtypename(obj), JProxy))(obj)
    end
end

function asJulia(x, ptr::Ptr{Nothing})
    isNull(ptr) ? JNull : asJulia(x, JObject(ptr))
end

classtypename(obj::JavaObject{T}) where T = string(T)
classname(obj::JavaObject) = jcall(jcall(obj,"getClass", @jimport(java.lang.Class), ()), "getName", JString, ())

# Determine which method is more general using a fairly lame heuristic
function generality(p1::JMethodInfo, p2::JMethodInfo)
    g = 0
    for i in 1:length(p1.argTypes)
        c1, c2 = p1.argClasses[i], p2.argClasses[i]
        g += generality(c1, c2) - generality(c2, c1)
    end
    g
end

function generality(c1::JClass, c2::JClass)
    p1, p2 = isPrimitive.((c1, c2))
    if !p1 && p2 || jcall(c1, "isAssignableFrom", jboolean, (@jimport(java.lang.Class),), c2) != 0
        1
    else
        0
    end
end

isPrimitive(cls::JavaObject) = jcall(cls, "isPrimitive", jboolean, ()) != 0

function Base.getproperty(p::JProxy, name::Symbol)
    obj = pxyObj(p)
    info = pxyInfo(p)
    meths = get(info.methods, name, nothing)
    static = pxyStatic(p)
    result = if meths != nothing
        JMethodProxy(obj, name, meths, static)
    else
        field = info.fields[name]
        result = ccall(static ? field.info.staticGetter : field.info.getter, Ptr{Nothing},
                       (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}),
                       penv, static ? getclass(obj) : obj.ptr, field.id)
        result == C_NULL && geterror()
        result = (field.primitive ? convert(field.juliaType, result) : result == C_NULL ? JNull : narrow(JavaObject(JObject, result)))
        asJulia(field.juliaType, result)
    end
    result != JNull && isa(result, JavaObject) ? JProxy(result) : result
end

function Base.setproperty!(p::JProxy, name::Symbol, value)
    obj = pxyObj(p)
    info = pxyInfo(p)
    meths = get(info.methods, name, nothing)
    static = pxyStatic(p)
    result = if meths != nothing
        throw(JavaCallError("Attempt to set a method"))
    else
        if isa(value, JProxy); value = JavaObject(value); end
        field = info.fields[name]
        value = convert(field.primitive ? field.juliaType : field.fieldJType, value)
        result = field.info.setterFunc(field, obj, value)
        result == C_NULL && geterror()
        value
    end
    isa(result, JavaObject) ? JProxy(result) : result
end

function Base.show(io::IO, pxy::JProxy)
    if pxyStatic(pxy)
        print(io, "static class $(getname(JavaObject(pxy)))")
    else
        print(io, pxy.toString())
    end
end

JavaObject(pxy::JProxy) = pxyObj(pxy)
