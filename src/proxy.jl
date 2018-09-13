const jvoid = Cvoid
const JField = JavaObject{Symbol("java.lang.reflect.Field")}

struct JMethodInfo
    name::String
    returnType::Type
    void::Bool
    argTypes::Tuple
    argClasses::Array{JavaObject}
    id::Ptr{Nothing}
    juliaType::Type
    static::Bool
    owner::JavaMetaClass
end

struct JFieldInfo
    field::JField
    name::String
    juliaType::Type
    static::Bool
    id
    function JFieldInfo(field)
        name = getname(field)
        typ = JavaObject{Symbol(getname(jcall(field, "getType", JClass, ())))}
        static = isStatic(field)
        id = fieldId(name, typ, static, field)
        new(field, name, typ, static, id)
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

struct JProxy
    obj::JavaObject
    info::JClassInfo
    static::Bool
    JProxy(::Type{JavaObject{C}}) where {C} = JProxy(string(C), false)
    JProxy(::Type{JavaObject{C}}, static) where {C} = JProxy(string(C), static)
    JProxy(::JavaMetaClass{C}) where {C} = JProxy(string(C), true)
    JProxy(C::AbstractString) = JProxy(classforname(C), false)
    JProxy(C::AbstractString, static) = JProxy(classforname(C), static)
    JProxy(obj) = JProxy(obj, false)
    JProxy(obj, static) = new(static ? JNull : narrow(obj), infoFor(static ? obj : getclass(obj)), static)
end

struct JavaTypeInfo
    signature::AbstractString
    juliaType::Type
    boxClass::AbstractString
end

classes = Dict()
methodCache = Dict{Tuple{String, String, Array{String}}, JMethodInfo}()
modifiers = JavaObject{Symbol("java.lang.reflect.Modifier")}
juliaConverters = Dict()
typeInfo = Dict([
    "int" => JavaTypeInfo("I", jint, "java.lang.Integer"),
    "long" => JavaTypeInfo("J", jlong, "java.lang.Long"),
    "byte" => JavaTypeInfo("B", jbyte, "java.lang.Byte"),
    "boolean" => JavaTypeInfo("Z", jboolean, "java.lang.Boolean"),
    "char" => JavaTypeInfo("C", jchar, "java.lang.Character"),
    "short" => JavaTypeInfo("S", jshort, "java.lang.Short"),
    "float" => JavaTypeInfo("F", jfloat, "java.lang.Float"),
    "double" => JavaTypeInfo("D", jdouble, "java.lang.Double"),
    "void" => JavaTypeInfo("V", jint, "java.lang.Void"),
    "java.lang.String" => JavaTypeInfo("[java/lang/String;", JString, "")
])

function methodInfo(m::JMethod)
    name, returnType, argTypes = getname(m), getreturntype(m), getparametertypes(m)
    cls = jcall(m, "getDeclaringClass", JClass, ())
    methodKey = (getname(cls), name, getname.(argTypes))
    get!(methodCache, methodKey) do
        methodId = getmethodid(m, cls, name, returnType, argTypes)
        typeName = getname(returnType)
        juliaType = juliaTypeFor(typeName)
        owner = metaclass(getname(cls))
        JMethodInfo(name, juliaType, typeName == "void", Tuple(juliaTypeFor.(argTypes)), argTypes, methodId, juliaType, isStatic(m), owner)
    end
end

isClass(obj::JavaObject) = false
#isClass(obj::JavaObject) = p((::JavaObject{C}) where {C} -> string(C))(narrow(obj))

function isStatic(meth::Union{JMethod,JField})
    global modifiers

    mods = jcall(meth, "getModifiers", jint, ())
    jcall(modifiers, "isStatic", jboolean, (jint,), mods) != 0
end

conv(func::Function, typ::String) = juliaConverters[typ] = func

function initProxy()
    conv("java.lang.String") do x; JProxy(x).toString(); end
    conv("java.lang.Integer") do x; JProxy(x).intValue(); end
    conv("java.lang.Long") do x; JProxy(x).longValue(); end
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

function fieldId(name, typ::Type{JavaObject{C}}, static, field) where {C}
    cls = jcall(field, "getDeclaringClass", JClass, ())
    id = ccall(static ? jnifunc.GetStaticFieldID : jnifunc.GetFieldID, Ptr{Nothing},
               (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
               penv, metaclass(getname(cls)), name, proxyClassSignature(string(C)))
    id == C_NULL && geterror(true)
    id
end

function boxClass(cls)
    info = get(typeInfo, cls, nothing)
    info != nothing ? info.boxClass : cls
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

fieldDict(class::JClass) = Dict([Symbol(getname(item)) => JFieldInfo(item) for item = listfields(class)])

function methodDict(class::JClass)
    d = Dict()
    for method = listmethods(class)
        s = get!(d, Symbol(getname(method))) do; Set(); end
        push!(s, methodInfo(method))
    end
    d
end

fits(method::JMethodInfo, args::Tuple) = length(method.argTypes) == length(args) && all(canConvert.(method.argTypes, args))

canConvert(::Type{JavaObject{T}}, ::AbstractString) where {T} = true
canConvert(::Type{JavaObject{T}}, ::Real) where {T} = true
canConvert(::Type{JString}, ::AbstractString) = true
canConvert(::Type{T1}, ::T2) where {T1, T2 <: Real} = true
canConvert(::Type{jboolean}, ::Bool) = true
canConvert(::Type{jchar}, ::Char) = true
canConvert(x, y) = false
convert(::Type{JavaObject{T}}, n::Int32) where {T} = jnew(Symbol("java.lang.Integer"), (jint,), n)
convert(::Type{JObject}, n::Int64) = jnew(Symbol("java.lang.Long"), (jlong,), n)
convert(::Type{JavaObject{:int}}, n) = convert(jint, n)
convert(::Type{JavaObject{:long}}, n) = convert(jlong, n)
convert(::Type{JavaObject{:byte}}, n) = convert(jbyte, n)
convert(::Type{JavaObject{:boolean}}, n) = convert(jboolean, n)
convert(::Type{JavaObject{:char}}, n) = convert(jchar, n)
convert(::Type{JavaObject{:short}}, n) = convert(jshort, n)
convert(::Type{JavaObject{:float}}, n) = convert(jfloat, n)
convert(::Type{JavaObject{:double}}, n) = convert(jdouble, n)
convert(::Type{JavaObject{:void}}, n) = convert(jvoid, n)

function (pxy::JMethodProxy)(args...)
    targets = Set()
    for m = pxy.methods
        if fits(m, args)
            push!(targets, m)
        end
    end
    if !isempty(targets)
        # Find the most specific method
        meth = reduce(((x, y)-> generality(x, y) < generality(y, x) ? x : y), filterStatic(pxy, targets))
        convertedArgs = convert.(meth.argTypes, args)
        result = _jcall(meth.static ? meth.owner : pxy.receiver, meth.id, C_NULL, meth.juliaType, meth.argTypes, convertedArgs...)
        #println("METHOD: ", meth)
        asJulia(result)
    end
end

function filterStatic(pxy::JMethodProxy, targets)
    static = getfield(pxy, :static)
    filter(target->target.static == static, targets)
end

asJulia(obj) = obj
function asJulia(obj::JavaObject)
    (get(juliaConverters, classname(obj), identity))(obj)
end

classname(obj::JavaObject) = jcall(jcall(obj,"getClass", @jimport(java.lang.Class), ()), "getName", JString, ())


# Determine which method is more general using a fairly lame heuristic
function generality(p1::JMethodInfo, p2::JMethodInfo)
    g = 0
    for i = 1:length(p1.argTypes)
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
    obj = getfield(p, :obj)
    info = getfield(p, :info)
    meths = get(info.methods, name, nothing)
    static = getfield(p, :static)
    result = if meths != nothing
        JMethodProxy(obj, name, meths, static)
    else
        field = info.fields[name]
        #jfield(obj, name, info.fields[name].fieldType)
        result = ccall(static ? jnifunc.GetStaticObjectField : jnifunc.GetObjectField, Ptr{Nothing},
                       (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}),
                       penv, obj.ptr, field.id)
        result == C_NULL && geterror()
        asJulia(convert_result(field.juliaType, result))
    end
    isa(result, JavaObject) ? JProxy(result) : result
end

Base.show(io::IO, pxy::JProxy) = print(io, pxy.toString())

JavaObject(pxy::JProxy) = getfield(pxy, :obj)

function systest()
    println("\n\n\n")
    init(split("-Djava.class.path=/home/bill/work/workspace-photon/Julia/bin:/home/bill/work/workspace-photon/Julia/dist:/home/bill/work/Dataswarm/Dataswarm-libraries/lib-common/jna-4.5.2.jar -Djna.library.path=/home/bill/work/workspace-photon/Julia/dist", r" +"))
    JAL = @jimport java.util.ArrayList
    println(JProxy(JavaCall.jnew(Symbol("java.lang.Integer"), (jint,), 3)).toString() == "3")
    println(JProxy(convert(JObject, 3)).toString() == "3")
    a = JProxy(JAL(()))
    println(a.size() == 0)
    a.add("one")
    println(a.size() == 1)
    println(a.toString() == "[one]")
    removed = a.remove(0)
    println(typeof(removed) == String)
    println(removed == "one")
end
