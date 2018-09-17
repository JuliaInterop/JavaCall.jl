# TODO: box incoming primitives that are sent to object args, including Strings

import Base.==

# See documentation for JProxy for infomation

const JField = JavaObject{Symbol("java.lang.reflect.Field")}

genericFieldInfo = nothing
objectClass = nothing
methodsById = Dict()

struct JavaTypeInfo
    setterFunc
    class::Type{JavaObject{T}} where T # narrowed JavaObject type
    signature::AbstractString
    juliaType::Type # the Julia representation of the Java type, like jboolean (which is a UInt8), for call-in
    convertType::Type # the Julia type to convert results to, like Bool or String
    primitive::Bool
    accessorName::AbstractString
    boxType::Type{JavaObject{T}} where T
    boxClass::JClass
    primClass::JClass
    getter::Ptr{Nothing}
    staticGetter::Ptr{Nothing}
    setter::Ptr{Nothing}
    staticSetter::Ptr{Nothing}
    function JavaTypeInfo(setterFunc, class, signature, juliaType, convertType, accessorName, boxType, getter, staticGetter, setter, staticSetter)
        boxClass = classfortype(boxType)
        primitive = length(signature) == 1
        primClass = primitive ? jfield(boxType, "TYPE", JClass) : objectClass
        info = new(setterFunc, class, signature, juliaType, convertType, primitive, accessorName, boxType, boxClass, primClass, getter, staticGetter, setter, staticSetter)
        info
    end
end

struct JMethodInfo
    uid::Int64
    name::String
    typeInfo::JavaTypeInfo
    argTypes::Tuple
    argClasses::Array{JavaObject}
    id::Ptr{Nothing}
    static::Bool
    owner::JavaMetaClass
end

struct JFieldInfo
    field::JField
    info::JavaTypeInfo
    static::Bool
    id::Ptr{Nothing}
    owner::JClass
    function JFieldInfo(field::JField)
        fcl = jcall(field, "getType", JClass, ())
        typ = juliaTypeFor(getname(fcl))
        static = isStatic(field)
        cls = jcall(field, "getDeclaringClass", JClass, ())
        id = fieldId(getname(field), JavaObject{Symbol(getname(fcl))}, static, field, cls)
        info = get(typeInfo, getname(fcl), genericFieldInfo)
        new(field, info, static, id, cls)
    end
end

struct JMethodProxy{N, T}
    obj
    static::Bool
end

struct JClassInfo
    class::JClass
    fields::Dict{Symbol, JFieldInfo}
    methods::Set{Symbol}
    classType::Type
end

struct Boxing
    info::JavaTypeInfo
    boxType::Type
    boxClass::JClass
    primClass::JClass
    boxer::Ptr{Nothing}
    unboxer::Ptr{Nothing}
    function Boxing(info)
        boxer = methodInfo(getConstructor(info.boxType, info.primClass)).id
        unboxer = methodInfo(getMethod(info.boxType, info.accessorName)).id
        new(info, info.boxType, info.boxClass, info.primClass, boxer, unboxer)
    end
end

boxers = Dict()

isVoid(meth::JMethodInfo) = meth.typeInfo.convertType == Nothing

juliaConverters = Dict()
classtypename(obj::JavaObject{T}) where T = string(T)

abstract type java_lang end

#types = Dict("java.lang.Object" => java_lang_Object)
types = Dict()

typeNameFor(className::String) = Symbol(replace(replace(className, "_" => "__"), "." => "_"))

typeNameString(className::String) = string(typeNameFor(className))

"""
    JProxy(s::AbstractString)
    JProxy(::JavaMetaClass)
    JProxy(::Type{JavaObject}; static=false)
    JProxy(obj::JavaObject; static=false)

Create a proxy for a Java object that you can use like a Java object. Field and method syntax is like in Java. Primitive types and strings are converted to Julia objects on field accesses and method returns and converted back to Java types when sent as arguments to Java methods.

*NOTE: Because of this, if you need to call Java methods on a string that you got from Java, you'll have to use `JProxy(str)` to convert the Julia string to a proxied Java string*

To invoke static methods, set static to true.

To get a JProxy's Java object, use `JavaObject(proxy)`

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
struct JProxy{C <: java_lang}
    obj::JavaObject
    info::JClassInfo
    static::Bool
    JProxy(s::AbstractString) = JProxy(JString(s))
    JProxy(::JavaMetaClass{C}) where C = JProxy(JavaObject{C}; static=true)
    function JProxy(obj::JavaObject) where C
        obj = narrow(obj)
        info = infoFor(isNull(obj) ? objectClass : getclass(obj))
        new{types[javaType(obj)]}(isNull(obj) ? obj : narrow(obj), info, false)
    end
    function JProxy(::Type{JavaObject{C}}; static::Bool=false) where C
        obj = classforname(string(C))
        info = infoFor(obj)
        new{types[C]}(obj, info, true)
    end
end

const JLegalArg = Union{Number, String, JProxy}
const JPrimitive = Union{Bool, Char, Int8, Int16, Int32, Int64, Float32, Float64}
const JNumber = Union{Int8, Int16, Int32, Int64, Float32, Float64}
const JBoxTypes = Union{
    Type{JavaObject{Symbol("java.lang.Boolean")}},
    Type{JavaObject{Symbol("java.lang.Byte")}},
    Type{JavaObject{Symbol("java.lang.Character")}},
    Type{JavaObject{Symbol("java.lang.Short")}},
    Type{JavaObject{Symbol("java.lang.Integer")}},
    Type{JavaObject{Symbol("java.lang.Long")}},
    Type{JavaObject{Symbol("java.lang.Float")}},
    Type{JavaObject{Symbol("java.lang.Double")}}
}
const JBoxed = Union{
    JavaObject{Symbol("java.lang.Boolean")},
    JavaObject{Symbol("java.lang.Byte")},
    JavaObject{Symbol("java.lang.Character")},
    JavaObject{Symbol("java.lang.Short")},
    JavaObject{Symbol("java.lang.Integer")},
    JavaObject{Symbol("java.lang.Long")},
    JavaObject{Symbol("java.lang.Float")},
    JavaObject{Symbol("java.lang.Double")}
}

classes = Dict()
methodCache = Dict{Tuple{String, String, Array{String}}, JMethodInfo}()
modifiers = JavaObject{Symbol("java.lang.reflect.Modifier")}
typeInfo = Dict()

struct GenInfo
    code
    typeCode
    deps
    classList
    methodSets
    GenInfo() = new([], [], Set(), [], Dict())
end

hasClass(gen, name::Symbol) = haskey(types, name) || haskey(gen.methodSets, string(name))

function genClass(class, gen::GenInfo)
    push!(gen.classList, class)
    name = getname(class)
    sc = superclass(class)
    if !isNull(sc)
        supername = getname(sc)
        !hasClass(gen, Symbol(supername)) && genClass(sc, gen)
        push!(gen.typeCode, :(abstract type $(typeNameFor(name)) <: $(typeNameFor(supername)) end))
    else
        push!(gen.typeCode, :(abstract type $(typeNameFor(name)) <: java_lang end))
    end
    genMethods(class, gen)
end

struct GenArgInfo
    name
    javaType
    juliaType
    function GenArgInfo(index, info, gen)
        javaType = info.argTypes[index]
        new(Symbol("a" * string(index)), javaType, argType(javaType, gen))
    end
end

argType(t, gen) = t
argType(::Type{JavaObject{Symbol("java.lang.String")}}, gen) = String
argType(::Type{JavaObject{Symbol("java.lang.Object")}}, gen) = JLegalArg
argType(::Type{<: Number}, gen) = Number
function argType(::Type{JavaObject{T}}, gen) where T
    cl = findfirst("[", string(T)) != nothing ? Symbol("java.lang.Object") : T
    !hasClass(gen, cl) && push!(gen.deps, cl)
    :(JProxy{<:$(typeNameFor(string(cl)))})
end

function argCode(arg::GenArgInfo)
    argname = arg.name
    if arg.juliaType == String
        :(JString($argname))
    elseif arg.juliaType == JLegalArg
        :(box($argname))
    elseif arg.juliaType == Number
        :($(arg.javaType)($argname))
    else
        argname
    end
end

function genMethods(class, gen)
    gen.methodSets[getname(class)] = methods = Set()
    for method in listmethods(class)
        name = getname(method)
        push!(methods, Symbol(name))
        info = methodInfo(method)
        owner = string(javaType(info.owner))
        if isSame(class.ptr, info.owner.ptr)
            args = (GenArgInfo(i, info, gen) for i in 1:length(info.argTypes))
            argDecs = (:($(arg.name)::$(arg.juliaType)) for arg in args)
            push!(gen.code, :(function (pxy::JMethodProxy{Symbol($name), <: $(typeNameFor(owner))})($(argDecs...))
                              $(genConvertResult(info.typeInfo.convertType, info, :(_jcall(getfield(pxy, :obj), methodsById[$(info.uid)].id, C_NULL, $(info.typeInfo.juliaType), ($(info.argTypes...),), $((argCode(arg) for arg in args)...)))))
                              end))
        end
    end
end

genConvertResult(toType::Type{Bool}, info, expr) = :($expr != 0)
genConvertResult(toType::Type{String}, info, expr) = :(unsafe_string($expr))
genConvertResult(toType::JBoxTypes, info, expr) = :(unbox($expr))
function genConvertResult(toType, info, expr)
    if isVoid(info) || info.typeInfo.primitive
        expr
    else
        :(asJulia($toType, $expr))
    end
end

function JClassInfo(class::JClass)
    gen = GenInfo()
    genClass(class, gen)
    while !isempty(gen.deps)
        cls = iterate(gen.deps)[1]
        delete!(gen.deps, cls)
        !hasClass(gen, cls) && genClass(classforname(string(cls)), gen)
    end
    for cl in gen.classList
        name = getname(cl)
        push!(gen.typeCode, :(types[Symbol($name)] = $(typeNameFor(name))))
    end
    println("\nEVALUATING...\n\n")
    expr = :(begin $(gen.typeCode...); $(gen.code...); end)
    println(expr)
    eval(expr)
    println("DONE EVALUATING")
    for cl in gen.classList
        n = getname(cl)
        classes[n] = JClassInfo(cl, fieldDict(cl), gen.methodSets[n], types[Symbol(n)])
    end
    classes[getname(class)]
end

asJulia(t, obj) = obj
asJulia(::Type{Bool}, obj) = obj != 0
asJulia(t, obj::JBoxed) = unbox(obj)
function asJulia(x, obj::JavaObject)
    if isNull(obj)
        nothing
    else
        (get(juliaConverters, classtypename(obj), JProxy))(obj)
    end
end
function asJulia(x, ptr::Ptr{Nothing})
    if isNull(ptr)
        jnull
    else
        asJulia(x, JavaObject{Symbol(getclassname(getclass(ptr)))}(ptr))
    end
end

box(str::String) = str
box(pxy::JProxy) = pxyObj(pxy)
unbox(obj) = obj

pxyObj(p::JProxy) = getfield(p, :obj)
pxyPtr(p::JProxy) = pxyObj(p).ptr
pxyInfo(p::JProxy) = getfield(p, :info)
pxyStatic(p::JProxy) = getfield(p, :static)

==(j1::JProxy, j2::JProxy) = isSame(pxyPtr(j1), pxyPtr(j2))

isSame(j1::JavaObject, j2::JavaObject) = isSame(j1.ptr, j2.ptr)
isSame(j1::Ptr{Nothing}, j2::Ptr{Nothing}) = ccall(jnifunc.IsSameObject, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}), penv, j1, j2) != C_NULL

getreturntype(c::JConstructor) = voidClass

function getMethod(class::Type, name::AbstractString, argTypes...)
    jcall(classfortype(class), "getMethod", JMethod, (JString, Vector{JClass}), name, collect(JClass, argTypes))
end

function getConstructor(class::Type, argTypes...)
    jcall(classfortype(class), "getConstructor", JConstructor, (Vector{JClass},), collect(argTypes))
end

methodInfo(class::String, name::String, argTypeNames::Array) = methodCache[(class, name, argTypeNames)]
function methodInfo(m::Union{JMethod, JConstructor})
    name, returnType, argTypes = getname(m), getreturntype(m), getparametertypes(m)
    cls = jcall(m, "getDeclaringClass", JClass, ())
    methodKey = (getname(cls), name, getname.(argTypes))
    get!(methodCache, methodKey) do
        methodId = getmethodid(isStatic(m), cls, name, returnType, argTypes)
        typeName = getname(returnType)
        info = get(typeInfo, typeName, genericFieldInfo)
        owner = metaclass(getname(cls))
        id = length(methodCache)
        methodsById[id] = JMethodInfo(id, name, info, Tuple(juliaTypeFor.(argTypes)), argTypes, methodId, isStatic(m), owner)
    end
end

isStatic(meth::JConstructor) = false
function isStatic(meth::Union{JMethod,JField})
    global modifiers

    mods = jcall(meth, "getModifiers", jint, ())
    jcall(modifiers, "isStatic", jboolean, (jint,), mods) != 0
end

conv(func::Function, typ::String) = juliaConverters[typ] = func

macro typeInf(jclass, sig, jtyp, jBoxType)
    _typeInf(jclass, Symbol("j" * string(jclass)), sig, jtyp, uppercasefirst(string(jclass)), false, string(jclass) * "Value", "java.lang." * string(jBoxType))
end

macro vtypeInf(jclass, ctyp, sig, jtyp, Typ, object, jBoxType)
    if typeof(jclass) == String
        jclass = Symbol(jclass)
    end
    _typeInf(jclass, ctyp, sig, jtyp, Typ, object, "", "java.lang." * string(jBoxType))
end

function _typeInf(jclass, ctyp, sig, jtyp, Typ, object, accessor, boxType)
    s = (p, t)-> :(jnifunc.$(Symbol(p * string(t) * "Field")))
    quote
        begin
            JavaTypeInfo(JavaObject{Symbol($(string(jclass)))}, $sig, $ctyp, $jtyp, $accessor, JavaObject{Symbol($boxType)}, $(s("Get", Typ)), $(s("GetStatic", Typ)), $(s("Set", Typ)), $(s("SetStatic", Typ))) do field, obj, value::$(object ? :JavaObject : ctyp)
                ccall(field.static ? field.info.staticSetter : field.info.setter, Ptr{Nothing},
                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, $(object ? :(Ptr{Nothing}) : ctyp)),
                      penv, (field.static ? field.owner : obj).ptr, field.id, $(object ? :(value.ptr) : :value))
            end
        end
    end
end

function initProxy()
    global objectClass = classforname("java.lang.Object")
    global classClass = classforname("java.lang.Class")
    global voidClass = jfield(JavaObject{Symbol("java.lang.Void")}, "TYPE", JClass)
    conv("java.lang.String") do x; unsafe_string(x); end
    conv("java.lang.Integer") do x; JProxy(x).intValue(); end
    conv("java.lang.Long") do x; JProxy(x).longValue(); end
    global typeInfo = Dict([
        "void" => @vtypeInf(void, jint, "V", Nothing, Object, false, Void)
        "boolean" => @typeInf(boolean, "Z", Bool, Boolean)
        "byte" => @typeInf(byte, "B", Int8, Byte)
        "char" => @typeInf(char, "C", Char, Character)
        "short" => @typeInf(short, "S", Int16, Short)
        "int" => @typeInf(int, "I", Int32, Integer)
        "float" => @typeInf(float, "F", Float32, Float)
        "long" => @typeInf(long, "J", Int64, Long)
        "double" => @typeInf(double, "D", Float64, Double)
        "java.lang.String" => @vtypeInf("java.lang.String", String, "Ljava/lang/String;", String, Object, true, Object)
    ])
    global genericFieldInfo = @vtypeInf("java.lang.Object", Any, "Ljava/lang/Object", JObject, Object, true, Object)
    global methodId_object_getClass = getmethodid(false, objectClass, "getClass", classforname("java.lang.Class"), Vector{JClass}())
    global methodId_class_getName = getmethodid(false, classClass, "getName", classforname("java.lang.String"), Vector{JClass}())
    for info in (t->typeInfo[string(t)]).(:(int, long, byte, boolean, char, short, float, double).args)
        infoName = string(javaType(info.class))
        boxVar = Symbol(infoName * "Box")
        box = boxers[infoName] = Boxing(info)
        expr = quote
            $boxVar = boxers[$infoName]
            function convert(::Type{JavaObject{T}}, obj::$(info.convertType)) where T
                box(obj)
            end
            function box(data::$(info.convertType))
                _jcall($boxVar.boxClass, $boxVar.boxer, jnifunc.NewObjectA, $(box.boxType), ($(box.info.juliaType),), data)
            end
            function unbox(obj::$(info.boxType))
                $(if box.info.convertType == Bool
                    :(_jcall(obj, $boxVar.unboxer, C_NULL, $(box.info.juliaType), ()) != 0)
                else
                    :(_jcall(obj, $boxVar.unboxer, C_NULL, $(box.info.juliaType), ()))
                end)
            end
        end
        println("BOX METHOD FOR ", box.boxType)
        println(expr)
        eval(expr)
    end
end

metaclass(class::AbstractString) = metaclass(Symbol(class))

function getclass(obj::Ptr{Nothing})
    result = ccall(jnifunc.CallObjectMethodA, Ptr{Nothing},
          (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
          penv, obj, methodId_object_getClass, Array{Int64,1}())
    result == C_NULL && geterror()
    result
end

function getclassname(class::Ptr{Nothing})
    result = ccall(jnifunc.CallObjectMethodA, Ptr{Nothing},
          (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
          penv, class, methodId_class_getName, Array{Int64,1}())
    result == C_NULL && geterror()
    unsafe_string(result)
end

function getmethodid(static::Bool, cls::JClass, name::AbstractString, rettype::JClass, argtypes::Vector{JClass})
    sig = proxyMethodSignature(rettype, argtypes)
    jclass = metaclass(getname(cls))
    result = ccall(static ? jnifunc.GetStaticMethodID : jnifunc.GetMethodID, Ptr{Nothing},
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

function proxyClassSignature(cls::JClass)
    info = get(typeInfo, getname(cls), nothing)
    if info != nothing && info.primitive
        info.signature
    else
        sig = []
        while jcall(cls, "isArray", jboolean, ()) != 0
            push!(sig, "[")
            cls = jcall(cls, "getComponentType", JClass, ())
        end
        clSig = infoSignature(jcall(cls, "getSimpleName", JString, ()))
        push!(sig, clSig != nothing ? clSig : "L" * javaclassname(getname(cls)) * ";")
        join(sig, "")
    end
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

function infoFor(class::JClass)
    name = getname(class)
    haskey(classes, name) ? classes[name] : classes[name] = JClassInfo(class)
end

getname(thing::Union{JClass, JMethod, JField}) = jcall(thing, "getName", JString, ())
getname(thing::JConstructor) = "<init>"

classfortype(t::Type{JavaObject{T}}) where T = classforname(string(T))

listfields(cls::JClass) = jcall(cls, "getFields", Vector{JField}, ())
listfields(cls::Type{JavaObject{C}}) where C = jcall(classforname(string(C)), "getFields", Vector{JField}, ())

fieldDict(class::JClass) = Dict([Symbol(getname(item)) => JFieldInfo(item) for item in listfields(class)])

javaType(::JavaObject{T}) where T = T
javaType(::Type{JavaObject{T}}) where T = T
javaType(::JavaMetaClass{T}) where T = T

isNull(obj::JavaObject) = isNull(obj.ptr)
isNull(ptr::Ptr{Nothing}) = Int64(ptr) == 0

superclass(obj::JavaObject) = jcall(obj, "getSuperclass", @jimport(java.lang.Class), ())

function Base.getproperty(p::JProxy, name::Symbol)
    obj = pxyObj(p)
    info = pxyInfo(p)
    static = pxyStatic(p)
    result = if name in info.methods
        JMethodProxy{name, types[javaType(obj)]}(obj, static)
    else
        field = info.fields[name]
        result = ccall(static ? field.info.staticGetter : field.info.getter, Ptr{Nothing},
                       (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}),
                       penv, static ? getclass(obj) : obj.ptr, field.id)
        result == C_NULL && geterror()
        result = (field.info.primitive ? convert(field.info.juliaType, result) : result == C_NULL ? jnull : narrow(JavaObject(JObject, result)))
        asJulia(field.info.juliaType, result)
    end
    result != jnull && isa(result, JavaObject) ? JProxy(result) : result
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
        value = convert(field.info.primitive ? field.info.juliaType : field.info.class, value)
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
        #print(io, Java.toString(pxy))
    end
end

JavaObject(pxy::JProxy) = pxyObj(pxy)
