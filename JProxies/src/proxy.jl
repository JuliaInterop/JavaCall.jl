# See documentation for JProxy for infomation

# TODO argtypefor(J.classforlegalname("[I")) returns Array{JavaCall.java_lang,1}
#      use sigtypes[class] to get primitive type
#
# TODO -- types' keys should probably be strings, not symbols
# 
#
# TODO switch from method.dynArgTypes to method.argTypes to allow full Julia type matching (array, etc.)
# TODO add specificity for Array types and add conversion rules for Array types
# TODO add iteration and access for lists, collecitons, maps

import Base.==

global useVerbose = false
global initialized = false

setVerbose() = global useVerbose = true
clearVerbose() = global useVerbose = false

location(source) = replace(string(source.file), r"^.*/([^/]*)$" => s"\1") * ":" * string(source.line) * ": "

macro verbose(args...)
    :(useVerbose && println($(location(__source__)), $(esc.(args)...)))
end
macro Verbose(args...)
    :(useVerbose && println("@@@ ", $(location(__source__)), $(esc.(args)...)))
end

abstract type java_lang end
abstract type interface <: java_lang end

classnamefor(t::Type{<:java_lang}) = classnamefor(nameof(t))
classnamefor(s::Symbol) = classnamefor(string(s))
function classnamefor(s::AbstractString)
    s = replace(s, "___" => "_")
    s = replace(s, "__S" => "\$")
    replace(s, "_" => ".")
end

_defjtype(a::Type, b::Type) = _defjtype(nameof(a), nameof(b))
function _defjtype(a, b)
    symA = Symbol(a)
    @verbose("DEFINING ", string(symA), " ", quote
        abstract type $symA <: $b end
        $symA
    end)
    get!(types, Symbol(classnamefor(a))) do
        eval(quote
             abstract type $symA <: $b  end
             $symA
        end)
    end
end

# types
macro defjtype(expr)
    :(_defjtype($(string(expr.args[1])), $(expr.args[2])))
end

const types = Dict()

@defjtype java_lang_Object <: java_lang
@defjtype java_lang_Class <: java_lang_Object
@defjtype java_lang_String <: java_lang_Object
@defjtype java_util_AbstractCollection <: java_lang_Object
@defjtype java_lang_Number <: java_lang_Object
@defjtype java_lang_Double <: java_lang_Number
@defjtype java_lang_Float <: java_lang_Number
@defjtype java_lang_Long <: java_lang_Number
@defjtype java_lang_Integer <: java_lang_Number
@defjtype java_lang_Short <: java_lang_Number
@defjtype java_lang_Byte <: java_lang_Number
@defjtype java_lang_Character <: java_lang_Object
@defjtype java_lang_Boolean <: java_lang_Object
@defjtype java_lang_Iterable <: interface
@defjtype java_util_List <: interface
@defjtype java_util_Collection <: interface
@defjtype java_util_Map <: interface

const modifiers = JavaObject{Symbol("java.lang.reflect.Modifier")}
#const JField = JavaObject{Symbol("java.lang.reflect.Field")}
const JPrimitive = Union{Bool, Char, UInt8, Int8, UInt16, Int16, Int32, Int64, Float32, Float64}
const JNumber = Union{Int8, Int16, Int32, Int64, Float32, Float64}
const JBoxTypes = Union{
    java_lang_Double,
    java_lang_Float,
    java_lang_Long,
    java_lang_Integer,
    java_lang_Short,
    java_lang_Byte,
    java_lang_Character,
    java_lang_Boolean
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

struct JavaTypeInfo
    classname::Symbol # legal classname as a symbol
    signature::AbstractString
    juliaType::Type # the Julia representation of the Java type, like jboolean (which is a UInt8), for call-in
    convertType::Type # the Julia type to convert results to, like Bool or String
    primitive::Bool
    accessorName::AbstractString
    boxType::Type{JavaObject{T}} where T
    boxClass::JClass
    primClass::JClass
    getter::Function
    staticGetter::Function
    setter::Function
    staticSetter::Function
    newarray::Function
    arrayregionsetter::Function
end

struct JReadonlyField
    get
end

struct JReadWriteField
    get
    set
end

struct JFieldInfo{T}
    field::JField
    typeInfo::JavaTypeInfo
    static::Bool
    id::Ptr{Nothing}
    owner::JClass
end

struct JMethodInfo
    name::AbstractString
    typeInfo::JavaTypeInfo
    returnType::Symbol # kluge this until we get generate typeInfo properly for new types
    returnClass::JClass
    argTypes::Tuple
    argClasses::Array{JClass}
    id::Ptr{Nothing}
    static::Bool
    owner::JavaMetaClass
    dynArgTypes::Tuple
end

struct JClassInfo
    parent::Union{Nothing, JClassInfo}
    class::JClass
    fields::Dict{Symbol, Union{JFieldInfo, JReadonlyField}}
    methods::Dict{Symbol, Set{JMethodInfo}}
    constructors::Set{JMethodInfo}
    classtype::Type
end

struct Boxing
    info::JavaTypeInfo
    boxType::Type
    boxClass::JClass
    boxClassType::Type
    primClass::JClass
    boxer::Ptr{Nothing}
    unboxer::Ptr{Nothing}
end

newglobalref(x) = JNI.NewGlobalRef(x)
deleteglobalref(x) = JNI.DeleteGlobalRef(x)
#deleteglobalref(x) = x
function deletelocals()
    #JNI.PopLocalFrame(C_NULL)
    #JNI.PushLocalFrame(jint(5))
end


"""
    PtrBox(ptr::Ptr{Nothing}

Temporarily holds a globalref to a Java object during JProxy creation
"""
# mutable because it can have a finalizer
mutable struct PtrBox
    ptr::Ptr{Nothing}

    PtrBox(obj::JavaObject) = PtrBox(Ptr(obj))
    function PtrBox(ptr::Ptr{Nothing})
        finalizer(finalizebox, new(newglobalref(ptr)))
    end
end

"""
    JProxy{classType, static}

A proxy for a Java object that you can use like a Java object. Field and method syntax is like in Java. Primitive types and strings are converted to Julia objects on field accesses and method returns and converted back to Java types when sent as arguments to Java methods.

*NOTE: Because of this, if you need to call Java methods on a string that you got from Java, you'll have to use `JProxy(str)` to convert the Julia string to a proxied Java string*

The classType parameter will either hold a java_lang subtype, which keeps a hierarchy parallel to Java's class tree, or it will hold an array of a java_lang subtype. java_lang subtypes are named like the Java classes with _ substituted for ., ___ substituted for _, and __S substituted for \$.

Interfaces are direct subtypes of the interface type (which is a subtype of java_lang). To test for interface extension, use interfacehas(interface, candidateType) or extends(candidateType, interface).

Java arrays and collections support iteration and indexing so you can use them as-is or you can use collect() to convert them to Juila arrays (or use generators to convert them to other collection types).

To invoke static methods, set static to true.

To get a JProxy's Java object, use `JavaObject(proxy)`

#Example
```jldoctest
# A proxy on a Java string
julia> JProxy("hello")
hello

# a static proxy on Integer
julia> @class(java.lang.Integer)
static class java.lang.Integer

# a proxy on an ArrayList
julia> a = @class(java.util.ArrayList)()
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

julia> @class(java.lang.System).out.println("hello")
hello

# a proxy on the ArrayList class (not a static proxy)
julia> a.getClass()
class java.util.ArrayList
```
"""
# mutable because it can have a finalizer
mutable struct JProxy{T, STATIC}
    ptr::Ptr{Nothing}
    info::JClassInfo
    function JProxy{T, STATIC}(obj::JavaObject, info) where {T, STATIC}
        finalizer(finalizeproxy, new{T, STATIC}(newglobalref(obj), info))
    end
    function JProxy{T, STATIC}(obj::PtrBox, info) where {T, STATIC}
        finalizer(finalizeproxy, new{T, STATIC}(newglobalref(obj.ptr), info))
    end
end

struct JMethodProxy{N, T}
    pxy # hold onto this so long-held method proxies don't have dead ptr references
    obj::Ptr{Nothing}
    methods::Set
    static::Bool
    function JMethodProxy(N::Symbol, T::Type, pxy::JProxy{A, STATIC}, methods) where {A, STATIC}
        new{N, T}(pxy, pxyptr(pxy), methods, STATIC)
    end
end

const JLegalArg = Union{Number, String, JProxy, Array{Number}, Array{String}, Array{JProxy}}
const methodsById = Dict()
const emptyset = Set()
const classes = Dict()
const methodCache = Dict{Tuple{String, String, Array{String}}, JMethodInfo}()
const typeInfo = Dict{AbstractString, JavaTypeInfo}()
const boxers = Dict()
const juliaConverters = Dict()
global jnicalls = Dict()
const defaultjnicall = (instance=:CallObjectMethodA,static=:CallStaticObjectMethodA)
const dynamicTypeCache = Dict()

global genericFieldInfo
global objectClass
global stringClass
global sigtypes

macro jnicall(func, rettype, types, args...)
    _jnicall(func, rettype, types, args)
end
macro jnicallregistered(func, rettype, types, args...)
    :(registerreturn($(_jnicall(func, rettype, types, args))))
end
function _jnicall(func, rettype, types, args)
    quote
        #local result = ccall($(esc(func)), $(esc(rettype)),
        #               (Ptr{JNIEnv}, $(esc.(types.args)...)),
        #               penv, $(esc.(args)...))
        local result = JNI.$func($(esc.(args)...))
        result == C_NULL && geterror()
        result
    end
end

macro message(obj, rettype, methodid, args...)
    func = get(jnicalls, rettype, defaultjnicall).instance
    @verbose("INSTANCE FUNC: ", func, " RETURNING ", rettype, " ARGS ", typeof.(args))
    flush(stdout)
    quote
        #result = ccall(jnifunc.$func, Ptr{Nothing},
        #               (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, $((typeof(arg) for arg in args)...)),
        #               penv, $(esc(obj)), $(esc(methodid)), $(esc.(args)...))
        result = JNI.$func($(esc(obj)), $(esc(methodid)), JNI.jvalue.([$(esc.(args)...)]))
        result == C_NULL && geterror()
        $(if rettype == Ptr{Nothing} || rettype == :(Ptr{Nothing})
              :(registerreturn(result))
          else
              :(result)
          end)
    end
end

macro staticmessage(rettype, methodid, args...)
    func = get(jnicalls, rettype, defaultjnicall).static
    @verbose("STATIC FUNC: ", func, " RETURNING ", rettype, " ARGS ", typeof.(args))
    flush(stdout)
    quote
        #result = ccall(jnifunc.$func, $(esc(rettype)),
        #               (Ptr{JNIEnv}, Ptr{Nothing}, $((Ptr{Nothing} for i in args)...)),
        #               penv, $(esc(methodid)), $(esc.(args)...))
        result = JNI.$func($(esc(methodid)), $(esc.(args)...))
        result == C_NULL && geterror()
        $(if rettype == Ptr{Nothing} || rettype == :(Ptr{Nothing})
              :(registerreturn(result))
          else
              :(result)
          end)
    end
end

registerreturn(x) = x
registerreturn(x::Ptr{Nothing}) = registerlocal(x)
# We are not going to run our own registry, use JNI.PushLocalFrame, JNI.PopLocalFrame instead
registerlocal(x) = x

function arrayinfo(str)
    if (m = match(r"^(\[+)(.)$", str)) != nothing
        string(signatureClassFor(m.captures[2])), length(m.captures[1])
    elseif (m = match(r"^(\[+)L(.*);", str)) != nothing
        m.captures[2], length(m.captures[1])
    else
        nothing, 0
    end
end

function finalizeproxy(pxy::JProxy)
    ptr = pxyptr(pxy)
    if ptr == C_NULL || !JavaCall.isloaded(); return; end
    deleteglobalref(ptr)
    setfield!(pxy, :ptr, C_NULL) #Safety in case this function is called direcly, rather than at finalize
end

function finalizebox(box::PtrBox)
    if box.ptr == C_NULL !JavaCall.isloaded(); return; end
    deleteglobalref(box.ptr)
    box.ptr = C_NULL #Safety in case this function is called direcly, rather than at finalize
end

arraycomponent(::Type{Array{T}}) where T = T

signatureClassFor(name) = length(name) == 1 ? sigtypes[name].classname : name

isVoid(meth::JMethodInfo) = meth.typeInfo.convertType == Nothing

classtypename(ptr::Ptr{Nothing}) = typeNameFor(getclassname(getclass(ptr)))
classtypename(obj::JavaObject{T}) where T = string(T)

"""
    @class(CLASSNAME) -> JProxy

Create a static proxy that allows you to invoke constructors and access static members.

# Examples
```jldoctest
julia> @class(java.lang.Integer).MAX_VALUE
2147483647

julia> a = @class(java.util.ArrayList)()
[]
```
"""
macro class(name::Expr)
    :(JProxy(Symbol($(replace(sprint(Base.show_unquoted, name), r"[ ()]"=>"")))))
end
macro class(name::Symbol)
    :(JProxy(Symbol($(string(name)))))
end
macro class(name::String)
    :(JProxy(Symbol($name)))
end
class(str::String) = JProxy(Symbol(str))
class(sym::Symbol) = JProxy(sym)
JProxy(::JavaMetaClass{C}) where C = staticproxy(string(C))
JProxy(::Type{JavaObject{C}}) where C = staticproxy(string(C))
JProxy(s::Symbol) = staticproxy(string(s))
function staticproxy(classname::AbstractString)
    c = Symbol(legalClassName(classname))
    staticproxy(c, classforname(string(c)))
end
staticproxy(obj::JClass) = staticproxy(Symbol(legalClassName(getname(obj))), obj)
staticproxy(obj::JProxy{java_lang_Class, true}) = obj
staticproxy(obj::JProxy{java_lang_Class, false}) = staticproxy(JavaObject(obj))
function staticproxy(c::Symbol, obj)
    info = infoFor(obj)
    JProxy{typeFor(c), true}(obj, info)
end
# Proxies on classes are on the class objects, they don't get you static members
# To access static members, use the @class(NAME) macro
# like this: `@class(java.lang.Byte).TYPE`
JProxy(s::AbstractString) = JProxy(JString(s))
JProxy{T}(ptr::PtrBox) where {T} = JProxy{T, false}(ptr, infoFor(JClass(getclass(ptr))))
JProxy(obj::JavaObject) = JProxy(PtrBox(obj))
JProxy(ptr::Ptr{Nothing}) = JProxy(PtrBox(ptr))
function JProxy(obj::PtrBox)
    if obj.ptr == C_NULL
        cls = objectClass
        n = "java.lang.Object"
    else
        cls = JClass(getclass(obj.ptr))
        n = legalClassName(getname(cls))
    end
    c = Symbol(n)
    @verbose("JPROXY INFO FOR ", n, ", ", getname(cls))
    info = infoFor(cls)
    aType, dim = arrayinfo(n)
    typ = info.classtype
    if dim != 0
        typ = typeFor(Symbol(aType))
    end
    JProxy{info.classtype, false}(obj, info)
end

function JavaTypeInfo(class, signature, juliaType, convertType, accessorName, boxType, getter, staticGetter, setter, staticSetter, newarray, arrayregionsetter)
    boxClass = classfortype(boxType)
    primitive = length(signature) == 1
    primClass = primitive ? jfield(boxType, "TYPE", JClass) : objectClass
    info = JavaTypeInfo(class, signature, juliaType, convertType, primitive, accessorName, boxType, boxClass, primClass, getter, staticGetter, setter, staticSetter, newarray, arrayregionsetter)
    info
end

function JFieldInfo(field::JField)
    fcl = jcall(field, "getType", JClass, ())
    typ = juliaTypeFor(legalClassName(fcl))
    static = isStatic(field)
    cls = jcall(field, "getDeclaringClass", JClass, ())
    id = fieldId(getname(field), JavaObject{Symbol(legalClassName(fcl))}, static, field, cls)
    info = get(typeInfo, legalClassName(fcl), genericFieldInfo)
    JFieldInfo{info.convertType}(field, info, static, id, cls)
end

function Boxing(info)
    boxer = methodInfo(getConstructor(info.boxType, info.primClass)).id
    unboxer = methodInfo(getMethod(info.boxType, info.accessorName)).id
    Boxing(info, info.boxType, info.boxClass, types[Symbol(getname(info.boxClass))], info.primClass, boxer, unboxer)
end

gettypeinfo(class::Symbol) = gettypeinfo(string(class))
gettypeinfo(class::AbstractString) = get(typeInfo, class, genericFieldInfo)

legalClassName(pxy::JProxy{T,S}) where {T, S} = legalClassName(getclassname(S ? pxyptr(pxy) : getclass(pxyptr(pxy))))
legalClassName(cls::JavaObject) = legalClassName(getname(cls))
legalClassName(cls::Symbol) = legalClassName(string(cls))
function legalClassName(name::AbstractString)
    if (m = match(r"^([^[]*)((\[])+)$", name)) != nothing
        dimensions = Integer(length(m.captures[2]) / 2)
        info = get(typeInfo, m.captures[1], nothing)
        base = if info != nothing && info.primitive
            info.signature
        elseif length(m.captures[1]) == 1
            m.captures[1]
        else
            "L$(m.captures[1]);"
        end
        "$(repeat('[', dimensions))$base"
    else
        name
    end
end

componentType(e::Expr) = e.args[2]
componentType(sym::Symbol) = sym

"""
    typeNameFor(thing)

Attempt to return the type for thing, otherwise return a symbol
representing the type, should it come to exist
"""
typeNameFor(t::Type) = t
typeNameFor(::Type{JavaObject{T}}) where T = typeNameFor(string(T))
typeNameFor(class::JClass) = typeNameFor(legalClassName(class))
typeNameFor(className::Symbol) = typeNameFor(string(className))
function typeNameFor(className::AbstractString)
    if className == "java.lang.String"
        String
    elseif length(className) == 1
        sigtypes[className].convertType
    else
        aType, dims = arrayinfo(className)
        if dims != 0
            Array{typeNameFor(aType), dims}
        else
            t = get(typeInfo, className, genericFieldInfo)
            if t.primitive
                t.juliaType
            else
                sn = Symbol(className)
                get(types, sn) do
                    className = replace(className, "_" => "___")
                    className = replace(className, "\$" => "__S")
                    Symbol(replace(className, "." => "_"))
                end
            end
        end
    end
end

macro jp(s)
    :(JProxy{$s, false})
end

isArray(class::JClass) = jcall(class, "isArray", jboolean, ()) != 0

unionize(::Type{T1}, ::Type{T2}) where {T1, T2} = Union{T1, T2}

function definterfacecvt(ct, interfaces)
    if !isempty(interfaces)
        union = reduce(unionize, [i.classtype for i in interfaces])
        if ct <: interface
            union = unionize(ct, union)
        end
        eval(:(interfacehas(::Type{<:$union}, ::Type{$ct}) = true))
    end
end

function JClassInfo(class::JClass)
    n = Symbol(legalClassName(class))
    @verbose("INFO FOR $(string(n))")
    sc = superclass(class)
    parentinfo = !isNull(sc) ? _infoFor(sc) : nothing
    interfaces = [_infoFor(cl) for cl in allinterfaces(class)]
    tname = typeNameFor(string(n))
    #@verbose("JCLASS INFO FOR ", n)
    jtype = if tname == String
        String
    elseif isa(tname, Type) && tname <: Array
        tname
    else
        get!(types, n) do
            _defjtype(tname, tname == Symbol("java.lang.Object") ? java_lang : isNull(sc) ? interface : typeNameFor(Symbol(legalClassName(sc))))
        end
    end
    definterfacecvt(jtype, interfaces)
    classes[n] = JClassInfo(parentinfo, class, fielddict(class), methoddict(class), getConstructors(class), jtype)
end

function ensureclasstypes(class::JClass)
    n = Symbol(legalClassName(class))
    tn = typeNameFor(string(n))
    if isa(tn, DataType)
        tn <: Array && isa(tn.parameters[1], Symbol) && ensureclasstypes(classforname(string(tn.parameters[1])))
        tn
    else
        sc = superclass(class)
        !isNull(sc) && ensureclasstypes(sc)
        for int in allinterfaces(class)
            ensureclasstypes(int)
        end
        _defjtype(tn, isNull(sc) ? interface : typeNameFor(sc))
    end
end

typeFor(::Type{JavaObject{T}}) where T = typeFor(T)
typeFor(str::String) = typeFor(Symbol(str))
function typeFor(sym::Symbol)
    aType, dims = arrayinfo(string(sym))
    if dims == 1 && haskey(typeInfo, aType)
        Array{get(typeInfo, aType, java_lang_Object).convertType, 1}
    elseif dims != 0
        Array{get(types, Symbol(aType), java_lang_Object), dims}
    else
        get(types, sym, java_lang_Object)
    end
end

asJulia(t, obj) = obj
asJulia(::Type{Bool}, obj) = obj != 0
asJulia(t, obj::JBoxed) = unbox(obj)
function asJulia(x, ptr::Ptr{Nothing})
    @verbose("ASJULIA: ", repr(ptr))
    if ptr == C_NULL
        nothing
    else
        ref = newglobalref(ptr)
        @verbose("PROXY FOR ", ref)
        @verbose("    CLASS: ", getclassname(getclass(ref)))
        result = unbox(JavaObject{Symbol(legalClassName(getclassname(getclass(ref))))}, ref)
        deleteglobalref(ref)
        result
    end
end

box(str::AbstractString) = JString(str)
box(pxy::JProxy) = pxyptr(pxy)

unbox(obj) = obj
function unbox(::Type, obj)
    @Verbose("NOOP UNBOXED $(typeof(obj))")
    obj
end
unbox(::Type{JavaObject{Symbol("java.lang.String")}}, obj::Ptr{Nothing}) = unsafe_string(obj)
function unbox(::Type{JavaObject{T}}, obj::Ptr{Nothing}) where T
    if  obj == C_NULL
        nothing
    else
        result = JProxy(obj)
        @Verbose("UNBOXED $(obj) TO $(typeof(result)), $(pxyptr(result)), CLASS $(getclassname(getclass(obj)))")
        result
    end
end

pxyptr(p::JProxy) = getfield(p, :ptr)
pxyinfo(p::JProxy) = getfield(p, :info)

==(j1::JProxy, j2::JProxy) = isSame(pxyptr(j1), pxyptr(j2))

isSame(j1::JavaObject, j2::JavaObject) = isSame(Ptr(j1), Ptr(j2))
isSame(j1::Ptr{Nothing}, j2::Ptr{Nothing}) = Bool(JNI.IsSameObject(j1, j2))

getreturntype(c::JConstructor) = voidClass

function getMethod(class::Type, name::AbstractString, argTypes...)
    jcall(classfortype(class), "getMethod", JMethod, (JString, Vector{JClass}), name, collect(JClass, argTypes))
end

function getConstructor(class::Type, argTypes...)
    jcall(classfortype(class), "getConstructor", JConstructor, (Vector{JClass},), collect(argTypes))
end

getConstructors(class::Type) = getConstructors(classfortype(class))
function getConstructors(class::JClass)
    Set([methodInfo(c) for c in jcall(class, "getConstructors", Array{JConstructor, 1}, ())])
end

function argtypefor(class::JClass)
    cln = getclassname(Ptr(class))
    tinfo = gettypeinfo(cln)
    if tinfo.primitive
        tinfo.convertType
    elseif cln == "java.lang.String"
        JProxy{java_lang_String, false}
    else
        t = ensureclasstypes(class)
        t <: Union{Array, java_lang} ? JProxy{t, false} : t
    end
end

methodInfo(class::AbstractString, name::AbstractString, argTypeNames::Array) = methodCache[(class, name, argTypeNames)]
function methodInfo(m::Union{JMethod, JConstructor})
    name, returnType, argTypes = getname(m), getreturntype(m), getparametertypes(m)
    cls = jcall(m, "getDeclaringClass", JClass, ())
    methodKey = (legalClassName(cls), name, legalClassName.(argTypes))
    get!(methodCache, methodKey) do
        methodId = getmethodid(isStatic(m), legalClassName(cls), name, legalClassName(returnType), legalClassName.(argTypes))
        typeName = legalClassName(returnType)
        info = get(typeInfo, typeName, genericFieldInfo)
        owner = metaclass(legalClassName(cls))
        methodsById[length(methodsById)] = JMethodInfo(name, info, Symbol(typeName), returnType, Tuple(argtypefor.(argTypes)), argTypes, methodId, isStatic(m), owner, get(jnicalls, typeName, Tuple(filterDynArgType.(juliaTypeFor.(argTypes)))))
    end
end

filterDynArgType(::Type{<:AbstractString}) = JavaObject{Symbol("java.lang.String")}
filterDynArgType(t) = t

isStatic(meth::JConstructor) = false
function isStatic(meth::Union{JMethod,JField})
    global modifiers

    mods = jcall(meth, "getModifiers", jint, ())
    jcall(modifiers, "isStatic", jboolean, (jint,), mods) != 0
end

conv(func::Function, typ::Symbol) = juliaConverters[typ] = func

macro typeInf(jclass, sig, jtyp, jBoxType)
    :(eval(_typeInf($(sym(jclass)), $(sym("j", jclass)), $sig, $(sym(jtyp)), $(uppercasefirst(string(jclass))), false, $(string(jclass)) * "Value", "java.lang." * $(string(jBoxType)))))
end

macro vtypeInf(jclass, ctyp, sig, jtyp, Typ, object, jBoxType)
    if typeof(jclass) == String
        jclass = Symbol(jclass)
    end
    :(eval(_typeInf($(sym(jclass)), $(sym(ctyp)), $sig, $(sym(jtyp)), $(sym(Typ)), $(sym(object)), "", "java.lang." * $(string(jBoxType)))))
end

sym(s...) = :(Symbol($(join(string.(s)))))

function _typeInf(jclass, ctyp, sig, jtyp, Typ, object, accessor, boxType)
    #j = (strs...)-> :(jnifunc.$(Symbol(reduce(*, string.(strs)))))
    j = (strs...)-> :(JNI.$(Symbol(reduce(*, string.(strs)))))
    s = (p, t)-> j(p, t, "Field")
    newarray = (length(sig) == 1 && sig != "V" ? j("New", Typ, "Array") : identity)
    arrayregionsetter = (length(sig) == 1 && sig != "V" ? j("Set", Typ, "ArrayRegion") : identity)
    arrayset = (length(sig) == 1 && sig != "V" ? j("New", Typ, "Array") : identity)
    arrayget = if length(sig) == 1 && sig != "V"
        type_ctyp = getfield(JavaCall, ctyp)
        type_jtyp = getfield(Core, jtyp)
        quote
            function arrayget(pxy::JProxy{<:Array{$ctyp}, false}, index)
                result = $type_jtyp[$(type_jtyp(0))]
                #@jnicall($(j("Get" * Typ * "ArrayRegion")), Nothing,
                #         (Ptr{Nothing}, Csize_t, Csize_t, Ptr{$(jtyp)}),
                #         pxyptr(pxy), index, 1, result)
                $(j("Get" * Typ * "ArrayRegion"))( pxyptr(pxy), index, 1, result )
                result == C_NULL && geterror()
                $(type_jtyp == Bool ? :(result[1] != 0) : :(result[1]))
            end
            function arrayset!(pxy::JProxy{<:Array{$ctyp}, false}, index, value::$ctyp)
                valuebuf = $type_jtyp[$type_jtyp(value)]
                #@jnicall($(j("Set" * Typ * "ArrayRegion")), Nothing,
                #         (Ptr{Nothing}, Csize_t, Csize_t, Ptr{$(jtyp)}),
                #         pxyptr(pxy), index, 1, valuebuf)
                $(j("Set" * Typ * "ArrayRegion"))(  pxyptr(pxy), index, 1, valuebuf ) 
                geterror()
            end
        end
    else
        :(())
    end
    quote
        $(arrayget.args...)
        push!(typeInfo, $(string(jclass)) => JavaTypeInfo($(sym(jclass)), $sig, $ctyp, $jtyp, $accessor, JavaObject{Symbol($boxType)}, $(s("Get", Typ)), $(s("GetStatic", Typ)), $(s("Set", Typ)), $(s("SetStatic", Typ)), $(newarray), $(arrayregionsetter)))
    end
end

function arrayget(pxy::JProxy{<:Array, false}, index)
    #result = @jnicall(jnifunc.GetObjectArrayElement, Ptr{Nothing},
    #                  (Ptr{Nothing}, Csize_t),
    #                  pxyptr(pxy), index)
    JNI.GetObjectArrayElement( pxyptr(pxy), index)
    if result == C_NULL
        geterror()
    else
        getreftype(result) == 1 && registerlocal(result)
        result = asJulia(Ptr{Nothing}, result)
        deletelocals()
    end
    result
end
function arrayset!(pxy::JProxy{<:Array, false}, index, value::JProxy)
    #@jnicall(jnifunc.SetObjectArrayElement, Nothing,
    #         (Ptr{Nothing}, Csize_t, Ptr{Nothing}),
    #         pxyptr(pxy), index, pxyptr(value))
    JNI.SetObjectArray( pxyptr(pxy), index, pxyptr(value) )
    geterror()
end

macro defbox(primclass, boxtype, juliatype, javatype, boxclassname)
    :(eval(_defbox($(sym(primclass)), $(sym(boxtype)), $(sym(juliatype)), $(sym(javatype)), $(sym(boxclassname)))))
end

function _defbox(primclass, boxtype, juliatype, javatype, boxclassname)
    boxclass = JavaObject{Symbol(classnamefor(boxtype))}
    primname = string(primclass)
    boxVar = Symbol(primname * "Box")
    varpart = if juliatype == :Bool
        quote
            convert(::Type{JavaObject{T}}, obj::Union{jboolean, Bool}) where T = JavaObject(box(obj))
            function unbox(::Type{$boxclass}, ptr::Ptr{Nothing})
                  call(ptr, $boxVar.unboxer, jboolean, ()) != 0
            end
            function unbox(::Type{$boxtype}, ptr::Ptr{Nothing})
                call(ptr, $boxVar.unboxer, jboolean, ()) != 0
            end
            function unbox(obj::JavaObject{Symbol($(classnamefor(boxtype)))})
                @message(obj, jboolean, $boxVar.unboxer) != 0
            end
        end
    else
        quote
            $(if juliatype == :jchar
                  :(convert(::Type{JavaObject{T}}, obj::Char) where T = JavaObject(box(obj)))
              else
                  ()
              end)
            function unbox(::Type{$boxclass}, ptr::Ptr{Nothing})
                call(ptr, $boxVar.unboxer, $javatype, ())
            end
            function unbox(::Type{$boxtype}, ptr::Ptr{Nothing})
                call(ptr, $boxVar.unboxer, $javatype, ())
            end
            function unbox(obj::JavaObject{Symbol($(classnamefor(boxtype)))})
                call(Ptr(obj), $boxVar.unboxer, $juliatype, ())
            end
        end
    end
    quote
        const $boxVar = boxers[$primname] = Boxing(typeInfo[$primname])
        boxer(::Type{$juliatype}) = $boxVar
        function box(data::$juliatype)
            #result = ccall(jnifunc.NewObject, Ptr{Nothing},
            #               (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, $juliatype),
            #               penv, $boxVar.boxClass.ptr, $boxVar.boxer, data)
            if isa(data,Array)
                result = JNI.NewObjectA(Ptr($boxVar.boxClass), $boxVar.boxer, JNI.jvalue.(data))
            else
                result = JNI.NewObjectA(Ptr($boxVar.boxClass), $boxVar.boxer, JNI.jvalue.([data]))
            end
            result == C_NULL && geterror()
            registerreturn(result)
        end
        $varpart
    end
end

function init(args...)
    JavaCall.isloaded() || JavaCall.init(args...)
    initProxy()
end
function initProxy()
    push!(jnicalls,
          :boolean => (static=:CallStaticBooleanMethodA, instance=:CallBooleanMethodA),
          :byte => (static=:CallStaticByteMethodA, instance=:CallByteMethodA),
          :char => (static=:CallStaticCharMethodA, instance=:CallCharMethodA),
          :short => (static=:CallStaticShortMethodA, instance=:CallShortMethodA),
          :int => (static=:CallStaticIntMethodA, instance=:CallIntMethodA),
          :long => (static=:CallStaticLongMethodA, instance=:CallLongMethodA),
          :float => (static=:CallStaticFloatMethodA, instance=:CallFloatMethodA),
          :double => (static=:CallStaticDoubleMethodA, instance=:CallDoubleMethodA),
          :Nothing => (static=:CallStaticVoidMethodA, instance=:CallVoidMethodA),
    )
    global objectClass = classforname("java.lang.Object")
    global classClass = classforname("java.lang.Class")
    global stringClass = classforname("java.lang.String")
    global voidClass = jfield(JavaObject{Symbol("java.lang.Void")}, "TYPE", JClass)
    global methodid_getmethod = getmethodid("java.lang.Class", "getMethod", "java.lang.reflect.Method", "java.lang.String", "[Ljava.lang.Class;")
    conv(Symbol("java.lang.String")) do x; unsafe_string(x); end
    conv(Symbol("java.lang.Integer")) do x; @jp(java_lang_Integer)(x).intValue(); end
    conv(Symbol("java.lang.Long")) do x; @jp(java_lang_Long)(x).longValue(); end
    @vtypeInf(void, jint, "V", Nothing, Object, false, Void)
    @typeInf(boolean, "Z", Bool, Boolean)
    @typeInf(byte, "B", Int8, Byte)
    @typeInf(char, "C", Char, Character)
    @typeInf(short, "S", Int16, Short)
    @typeInf(int, "I", Int32, Integer)
    @typeInf(float, "F", Float32, Float)
    @typeInf(long, "J", Int64, Long)
    @typeInf(double, "D", Float64, Double)
    @vtypeInf("java.lang.String", String, "Ljava/lang/String;", String, Object, true, Object)
    @vtypeInf("java.lang.Object", Any, "Ljava/lang/Object;", JObject, Object, true, Object)
    global sigtypes = Dict([inf.signature => inf for (key, inf) in typeInfo if inf.primitive])
    global juliatojava = Dict([inf.convertType => inf for (key, inf) in typeInfo])
    global genericFieldInfo = typeInfo["java.lang.Object"]
    global methodId_object_getClass = getmethodid("java.lang.Object", "getClass", "java.lang.Class")
    global methodId_class_getName = getmethodid("java.lang.Class", "getName", "java.lang.String")
    global methodId_class_getInterfaces = getmethodid("java.lang.Class", "getInterfaces", "[Ljava.lang.Class;")
    global methodId_class_isInterface = getmethodid("java.lang.Class", "isInterface", "boolean")
    global methodId_system_gc = getmethodid(true, "java.lang.System", "gc", "void", String[])
    global methodId_method_getParameterTypes = getmethodid("java.lang.reflect.Method", "getParameterTypes", "[Ljava.lang.Class;")
    global initialized = true
    @defbox(boolean, java_lang_Boolean, Bool, jboolean, Boolean)
    @defbox(char, java_lang_Character, Char, jchar, Character)
    @defbox(byte, java_lang_Byte, jbyte, jbyte, Byte)
    @defbox(short, java_lang_Short, jshort, jshort, Short)
    @defbox(int, java_lang_Integer, jint, jint, Integer)
    @defbox(long, java_lang_Long, jlong, jlong, Long)
    @defbox(float, java_lang_Float, jfloat, jfloat, Float)
    @defbox(double, java_lang_Double, jdouble, jdouble, Double)
    #JNI.PushLocalFrame(jint(5))
    nothing
end

metaclass(class::AbstractString) = metaclass(Symbol(class))

function getclass(obj::Ptr{Nothing})
    initialized ? @message(obj, Ptr{Nothing}, methodId_object_getClass) : C_NULL
end

function getclassname(class::Ptr{Nothing})
    initialized ? unsafe_string(@message(class, Ptr{Nothing}, methodId_class_getName)) : "UNKNOWN"
end

isinterface(class::Ptr{Nothing}) = @message(class, jboolean, methodId_class_isInterface) != 0

"""
    getinterfaces

return JClass objects for the declared and inherited interfaces of a class
"""
function getinterfaces(class::JClass)
    classesFor(@message(Ptr(class), Ptr{Nothing}, methodId_class_getInterfaces))
end

function classesFor(array)
    # ptrbox array first so they don't get collected
    ap = PtrBox(array)
    [JClass(arrayat(ap.ptr, i)) for i in 1:arraylength(ap.ptr)]
end

jarray(array::Ptr{Nothing}) = [arrayat(array, i) for i in 1:arraylength(array)]

function allinterfaces(class::JClass)
    result = []
    queue = [class]
    seen = Set()
    while !isempty(queue)
        for interface in getinterfaces(pop!(queue))
            if !(interface in seen)
                push!(seen, interface)
                push!(result, interface)
                push!(queue, interface)
            end
        end
    end
    reverse(result)
end

function getmethodid(cls::AbstractString, name, rettype::AbstractString, argtypes::AbstractString...)
    getmethodid(false, cls, name, rettype, collect(argtypes))
end
function getmethodid(static, cls::JClass, name, rettype::AbstractString, argtypes::Vector{<:AbstractString})
    getmethodid(static, cls, name, classforlegalname(rettype), collect(JClass, classforlegalname.(argtypes)))
end
getmethodid(static, cls::JClass, name, rettype, argtypes) = getmethodid(static, legalClassName(cls), name, rettype, argtypes)
function getmethodid(static::Bool, clsname::AbstractString, name::AbstractString, rettype::AbstractString, argtypes::Vector{<:Union{JClass, AbstractString}})
    sig = proxyMethodSignature(rettype, argtypes)
    jclass = metaclass(clsname)
    #@verbose(@macroexpand @jnicall(static ? jnifunc.GetStaticMethodID : jnifunc.GetMethodID, Ptr{Nothing},
    #        (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
    #        jclass, name, sig))
    try
        if static
            JNI.GetStaticMethodID( Ptr(jclass) , name, sig)
        else
            JNI.GetMethodID( Ptr(jclass) , name, sig)
        end
        #@jnicall(static ? jnifunc.GetStaticMethodID : jnifunc.GetMethodID, Ptr{Nothing},
        #         (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
        #         jclass, name, sig)
    catch err
        println("ERROR GETTING METHOD $clsname.$name($(join(argtypes, ",")))")
        throw(err)
    end
end

function fieldId(name, typ::Type{JavaObject{C}}, static, field, cls::JClass) where {C}
    mc = metaclass(legalClassName(cls))
    sig = proxyClassSignature(string(C))
    if static
        JNI.GetStaticFieldID(Ptr(mc), name, sig)
    else
        JNI.GetFieldID(Ptr(mc), name, sig)
    end
    #@jnicall(static ? jnifunc.GetStaticFieldID : jnifunc.GetFieldID, Ptr{Nothing},
    #         (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
    #         metaclass(legalClassName(cls)), name, proxyClassSignature(string(C)))
end

function infoSignature(cls::AbstractString)
    info = get(typeInfo, cls, nothing)
    if info != nothing; info.signature; end
end

proxyClassSignature(cls::JClass) = proxyClassSignature(legalClassName(cls))
function proxyClassSignature(clsname::AbstractString)
    info = get(typeInfo, clsname, nothing)
    if info != nothing && info.primitive
        info.signature
    else
        atype, dim = arrayinfo(clsname)
        dim > 0 ? javaclassname(clsname) : "L" * javaclassname(clsname) * ";"
    end
end

function getcomponentclass(class::JClass)
    while jcall(class, "isArray", jboolean, ()) != 0
        class = jcall(class, "getComponentType", JClass, ())
    end
    class
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

juliaTypeFor(class::JavaObject) = juliaTypeFor(legalClassName(class))
function juliaTypeFor(name::AbstractString)
    info = get(typeInfo, name, nothing)
    info != nothing ? info.juliaType : JavaObject{Symbol(name)}
end

infoFor(typ::Type{T}) where {T <: java_lang} = infoFor(classforname(classnamefor(nameof(T))))
function infoFor(class::JClass)
    result = _infoFor(class)
    deletelocals()
    result
end
function _infoFor(class::JClass)
    if isNull(class)
        nothing
    else
        name = legalClassName(class)
        #@verbose("INFO FOR ", name)
        haskey(classes, name) ? classes[name] : classes[name] = JClassInfo(class)
    end
end

getname(thing::Union{JClass, JMethod, JField}) = jcall(thing, "getName", JString, ())
getname(thing::JConstructor) = "<init>"

function classforlegalname(n::AbstractString)
    try
        (i = get(typeInfo, n, nothing)) != nothing && i.primitive ? i.primClass : classforname(n)
    catch x
        #@verbose("Error finding class: $n, type: $(typeof(n))")
        throw(x)
    end
end

classfortype(t::Type{JavaObject{T}}) where T = classforname(string(T))
classfortype(t::Type{T}) where {T <: java_lang} = classforname(classnamefor(nameof(T)))

listfields(cls::AbstractString) = listfields(classforname(cls))
listfields(cls::Type{JavaObject{C}}) where C = listfields(classforname(string(C)))
listfields(cls::JClass) = jcall(cls, "getFields", Vector{JField}, ())

function fielddict(class::JClass)
    if isArray(class)
        Dict([:length => JReadonlyField((ptr)->arraylength(ptr))])
    else
        Dict([Symbol(getname(item)) => JFieldInfo(item) for item in listfields(class)])
    end
end

arraylength(obj::JavaObject) = JNI.GetArrayLength(obj)
#arraylength(obj::Ptr{Nothing}) = @jnicall(jnifunc.GetArrayLength, jint, (Ptr{Nothing},), obj)
arraylength(obj::Ptr{Nothing}) = JNI.GetArrayLength(obj)

arrayat(obj::JavaObject, i) = arrayat(obj.ptr, i)
#arrayat(obj, i) = @jnicallregistered(jnifunc.GetObjectArrayElement, Ptr{Nothing},
#                                     (Ptr{Nothing}, jint),
#                                     obj, jint(i) - 1)
arrayat(obj, i) = JNI.GetObjectArrayElement(obj, jint(i) - 1)

function methoddict(class)
    d = Dict()
    for method in listmethods(class)
        s = get!(d, Symbol(getname(method))) do
            Set()
        end
        push!(s, methodInfo(method))
    end
    d
end

javaType(::JavaObject{T}) where T = T
javaType(::Type{JavaObject{T}}) where T = T
javaType(::JavaMetaClass{T}) where T = T

isNull(obj::JavaObject) = isNull(Ptr(obj))
isNull(ptr::Ptr{Nothing}) = Int64(ptr) == 0

superclass(obj::JavaObject) = jcall(obj, "getSuperclass", @jimport(java.lang.Class), ())

function getField(p::JProxy{T,S}, field::JFieldInfo) where {T,S}
    asJulia(field.typeInfo.juliaType, @jnicallregistered(static ? field.typeInfo.staticGetter : field.typeInfo.getter, Ptr{Nothing},
                                                         (Ptr{Nothing}, Ptr{Nothing}),
                                                         S ? getclass(obj) : pxyptr(p), field.id))
end

function Base.getproperty(p::JProxy{T, STATIC}, name::Symbol) where {T, STATIC}
    info = pxyinfo(p)
    if haskey(info.methods, name)
        m = STATIC ? filter(m->m.static, info.methods[name]) : info.methods[name]
        isempty(m) && throw(KeyError("key: $name not found"))
        JMethodProxy(name, T, p, m)
    else
        getproxyfield(p, info.fields[name])
    end
end

getter(field::JFieldInfo) = field.static ? field.typeInfo.staticGetter : field.typeInfo.getter

setter(field::JFieldInfo) = field.static ? field.typeInfo.staticSetter : field.typeInfo.setter

getproxyfield(p::JProxy, field::JReadonlyField) = field.get(pxyptr(p))
function getproxyfield(p::JProxy, field::JFieldInfo)
    result = _getproxyfield(field.static ? C_NULL : pxyptr(p), field)
    geterror()
    @verbose("FIELD CONVERT RESULT ", repr(result), " TO ", field.typeInfo.convertType)
    asJulia(field.typeInfo.convertType, result)
end
macro defgetfield(juliat, javat = juliat)
    :(function _getproxyfield(p::Ptr{Nothing}, field::JFieldInfo{$juliat})
            #local result = ccall(getter(field), $javat,
            #                     (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}),
            #                     penv, p, field.id)
            local result = getter(field)(p, field.id)
            result == C_NULL && geterror()
            $(if juliat == Ptr{Nothing} || juliat == :(Ptr{Nothing})
                  :(registerreturn(result))
              else
                  :(result)
              end)
        end)
end
@defgetfield(<:Any, Ptr{Nothing})
@defgetfield(Bool, jboolean)
@defgetfield(jbyte)
@defgetfield(jchar)
@defgetfield(jshort)
@defgetfield(jint)
@defgetfield(jlong)
@defgetfield(jfloat)
@defgetfield(jdouble)

setproxyfield(p::JProxy, field::JFieldInfo{T}, value) where T = primsetproxyfield(p, field, convert(T, value))
setproxyfield(p::JProxy, field::JFieldInfo, value::JProxy) = primsetproxyfield(p, field, pxyptr(value))
setproxyfield(p::JProxy, field::JFieldInfo, value::JavaObject) = primsetproxyfield(p, field, Ptr(value))
function setproxyfield(p::JProxy, field::JFieldInfo{String}, value::AbstractString)
    str = JString(convert(String, value))
    primsetproxyfield(p, field, Ptr(str))
end

function primsetproxyfield(p::JProxy{T,S}, field::JFieldInfo, value) where {T,S}
    _setproxyfield(S ? C_NULL : pxyptr(p), field, value)
    geterror()
end

function _setproxyfield(p::Ptr{Nothing}, field::JFieldInfo, value::Ptr{Nothing})
    #@jnicall(setter(field), Nothing,
    #         (Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
    #         p, field.id, value)
    setter(field)(p, field.id, value)
    #ccall(setter(field), Nothing,
    #      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
    #      penv, p, field.id, value)
end

macro defsetfield(juliat, javat = juliat)
    :(function _setproxyfield(p::Ptr{Nothing}, field::JFieldInfo{$juliat}, value::$javat)
          setter(field)(p, field.id, value)
          #ccall(setter(field), Nothing,
          #    (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, $javat),
          #    penv, p, field.id, value)
      end)
end
@defsetfield(String, Ptr{Nothing})
@defsetfield(Bool, jboolean)
@defsetfield(jbyte)
@defsetfield(jchar)
@defsetfield(jshort)
@defsetfield(jint)
@defsetfield(jlong)
@defsetfield(jfloat)
@defsetfield(jdouble)

function Base.setproperty!(p::JProxy, name::Symbol, value)
    info = pxyinfo(p)
    meths = get(info.methods, name, nothing)
    result = if meths != nothing
        throw(JavaCallError("Attempt to set a method"))
    else
        setproxyfield(p, info.fields[name], value)
        value
    end
    isa(result, JavaObject) ? JProxy(result) : result
end

function (pxy::JProxy{T, STATIC})(args...) where {T, STATIC}
    if STATIC || T <: java_lang_Class
        info = STATIC ? pxyinfo(pxy) : infoFor(JavaObject(pxy))
        targets = Set(m for m in info.constructors if fits(m, args))
        if !isempty(targets)
            # Find the most specific constructor
            argTypes = typeof(args).parameters
            meth = reduce(((x, y)-> specificity(argTypes, x) > specificity(argTypes, y) ? x : y), targets)
            savedargs, convertedargs = convert_args(meth.argTypes, args...)
            #result = ccall(jnifunc.NewObjectA, Ptr{Nothing},
            #               (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
            #               penv, info.class.ptr, meth.id, convertedargs)
            result = JNI.NewObjectA(Ptr(info.class), meth.id, JNI.jvalue.(convertedargs))
            result == C_NULL && geterror()
            JProxy(result)
        else
            throw(ArgumentError("No constructor for argument types $(typeof.(args))"))
        end
    else
        throw(MethodError(pxy, args))
    end
end

function (pxy::JMethodProxy{N})(args...) where N
    targets = Set(m for m in filterStatic(pxy, pxy.methods) if fits(m, args))
    if !isempty(targets)
        # Find the most specific method
        argTypes = typeof(args).parameters
        meth = reduce(((x, y)-> specificity(argTypes, x) > specificity(argTypes, y) ? x : y), targets)
        @Verbose("SEND MESSAGE ", N, " RETURNING ", meth.typeInfo.juliaType, " ARG TYPES ", meth.argTypes)
        if meth.static
            staticcall(meth.owner, meth.id, meth.typeInfo.convertType, meth.argTypes, args...)
        else
            call(pxy.obj, meth.id, meth.typeInfo.convertType, meth.argTypes, args...)
        end
    else
        throw(ArgumentError("No $N method for argument types $(typeof.(args))"))
    end
end

function findmethod(pxy::JMethodProxy, args...)
    findmethod(Set(m for m in filterStatic(pxy, pxy.methods) if fits(m, args)), args...)
end
function findmethod(targets::Set, args...)
    if !isempty(targets)
        argTypes = typeof(args).parameters
        reduce(((x, y)-> specificity(argTypes, x) > specificity(argTypes, y) ? x : y), targets)
    end
end

function filterStatic(pxy::JMethodProxy, targets)
    static = pxy.static
    Set(target for target in targets if target.static == static)
end

fits(method::JMethodInfo, args::Tuple) = length(method.dynArgTypes) == length(args) && all(canConvert.(method.argTypes, args))

canConvert(::Type{T}, ::T) where T = true
canConvert(t::Type, ::T) where T = canConvertType(t, T)
canConvert(::Type{Array{T1,D}}, ::Array{T2,D}) where {T1, T2, D} = canConvertType(T1, T2)
canConvert(::Type{T1}, ::JProxy{T2, false}) where {T1, T2} = canConvertType(T1, T2)
canConvert(::Type{JProxy{T1, false}}, ::JProxy{T2, false}) where {T1, T2} = canConvertType(T1, T2)
canConvert(::Type{JProxy{T1, false}}, ::T2) where {T1, T2} = canConvertType(T1, T2)

canConvertType(::Type{java_lang_Object}, ::Type{<:Array}) = true
canConvertType(::Type{T}, ::Type{T}) where T = true
canConvertType(::Type{T1}, t::Type{T2}) where {T1 <: java_lang_Object, T2 <: java_lang_Object} = T2 <: T1
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Object")}, java_lang_Object}}, ::Type{<:Union{AbstractString, JPrimitive}}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Double")}, java_lang_Double}}, ::Type{<:Union{Float64, Float32, Float16, Int64, Int32, Int16, Int8}}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Float")}, java_lang_Float}}, ::Type{<:Union{Float32, Float16, Int32, Int16, Int8}}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Long")}, java_lang_Long}}, ::Type{<:Union{Int64, Int32, Int16, Int8}}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Integer")}, java_lang_Integer}}, ::Type{<:Union{Int32, Int16, Int8}}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Short")}, java_lang_Short}}, ::Type{<:Union{Int16, Int8}}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Byte")}, java_lang_Byte}}, ::Type{Int8}) = true
canConvertType(::Type{<:Union{JavaObject{Symbol("java.lang.Character")}, java_lang_Character}}, ::Type{<:Union{Int8, Char}}) = true
canConvertType(::Type{<:AbstractString}, ::Type{<:AbstractString}) = true
canConvertType(::Type{<:JProxy{<:Union{java_lang_String, java_lang_Object}, false}}, ::Type{<:AbstractString}) = true
canConvertType(::Type{JString}, ::Type{<:AbstractString}) = true
canConvertType(::Type{<: Real}, ::Type{<:Real}) = true
canConvertType(::Type{jboolean}, ::Type{Bool}) = true
canConvertType(::Type{jchar}, ::Type{Char}) = true
canConvertType(x, y) = interfacehas(x, y)

"""
    interfacehas(interface, classOrInterfaceType)

Return whether interface has classOrInterfaceType as one of its subtypes, i.e. whether classOrInterfaceType extends interface.
"""
interfacehas(x, y) = false

"""
    extends(a, b)

Return whether a extends or implements b
"""
extends(::Type{<:T}, ::Type{T}) where {T <: java_lang} = true
extends(t1, t2) = interfacehas(t2, t1)

# score specificity of a method
function specificity(argTypes, mi::JMethodInfo) where T
    g = 0
    for i in 1:length(argTypes)
        g += specificity(argTypes[i], mi.argTypes[i])
    end
    g
end

isPrimitive(cls::JavaObject) = jcall(cls, "isPrimitive", jboolean, ()) != 0

const specificityworst = -1000000
const specificitybest = 1000000
const specificitybox = 100000
const specificityinherit = 10000

# score relative generality of corresponding arguments in two methods
# higher means c1 is more general than c2 (i.e. c2 is the more specific one)
specificity(::Type{JProxy{T1, false}}, ::Type{JProxy{T2, false}}) where {T1, T2} = specificity(T1, T2)
specificity(::Type{JProxy{T1, false}}, T2) where {T1} = specificity(T1, T2)
specificity(::Type{<:Union{JBoxTypes,JPrimitive}}, t1::Type{<:JPrimitive}) = specificitybest
specificity(::Type{<:JBoxTypes}, ::Type{<:JBoxTypes}) = specificitybest
specificity(::Type{<:JPrimitive}, ::Type{<:JBoxTypes}) = specificitybox
specificity(::Type{java_lang_Object}, ::Type{<:AbstractString}) = specificityinherit
specificity(::Type{java_lang_String}, ::Type{<:AbstractString}) = specificitybest
function specificity(argType::Type, t1::Type)
    if argType == t1 || interfacehas(t1, argType)
        specificitybest
    elseif argType <: t1
        at = argType
        spec = specificityinherit
        while at != t1
            spec -= 1
            at = supertype(at)
        end
        spec
    else
        specificityworst
    end
end

function call(ptr::Ptr{Nothing}, mId::Ptr{Nothing}, rettype::Type{T}, argtypes::Tuple, args...) where T
    ptr == C_NULL && error("Attempt to call method on Java NULL")
    savedargs, convertedargs = convert_args(argtypes, args...)
    result = _call(T, ptr, mId, convertedargs)
    result == C_NULL && geterror()
    result = asJulia(rettype, result)
    deletelocals()
    result
end

function call(ptr::Ptr{Nothing}, mId::Ptr{Nothing}, rettype::Type{Ptr{Nothing}}, argtypes::Tuple, args...)
    ptr == C_NULL && error("Attempt to call method on Java NULL")
    savedargs, convertedargs = convert_args(argtypes, args...)
    result = _call(Ptr{Nothing}, ptr, mId, convertedargs)
    result == C_NULL && geterror()
    getreftype(result) == 1 && registerlocal(result)
    result = asJulia(rettype, result)
    deletelocals()
    result
end

macro defcall(t, f, ft)
    #:(_call(::Type{$t}, obj, mId, args) = ccall(jnifunc.$(Symbol("Call" * string(f) * "MethodA")), $ft,
    #                                           (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
    #                                           penv, obj, mId, args))
    :(_call(::Type{$t}, obj, mId, args) = JNI.$(Symbol("Call" * string(f) * "MethodA"))(obj, mId, JNI.jvalue.(args)))                                           
end

#_call(::Type, obj, mId, args) = ccall(jnifunc.CallObjectMethodA, Ptr{Nothing},
#                                      (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
#                                      penv, obj, mId, args)
_call(::Type, obj, mId, args) = JNI.CallObjectMethodA(obj, mId, JNI.jvalue.(args))
@defcall(Bool, Boolean, jboolean)
@defcall(jbyte, Byte, jbyte)
@defcall(jchar, Char, jchar)
@defcall(jshort, Short, jshort)
@defcall(jint, Int, jint)
@defcall(jlong, Long, jlong)
@defcall(jfloat, Float, jfloat)
@defcall(jdouble, Double, jdouble)
@defcall(Nothing, Void, Nothing)

function staticcall(class, mId, rettype::Type{T}, argtypes::Tuple, args...) where T
    savedargs, convertedargs = convert_args(argtypes, args...)
    result = _staticcall(T, Ptr(class), mId, convertedargs)
    result == C_NULL && geterror()
    if rettype <: JavaObject && result != C_NULL
        registerreturn(result)
    end
    @verbose("RETTYPE: ", rettype)
    @verbose("CONVERTING RESULT ", repr(result), " TO ", rettype)
    result = asJulia(rettype, result)
    deletelocals()
    result
end

macro defstaticcall(t, f, ft)
    #:(_staticcall(::Type{$t}, class, mId, args) = ccall(jnifunc.$(Symbol("CallStatic" * string(f) * "MethodA")), $ft,
    #                                             (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
    #                                             penv, class, mId, args))
    :(_staticcall(::Type{$t}, class, mId, args) = JNI.$(Symbol("CallStatic" * string(f) * "MethodA"))(class, mId, JNI.jvalue.([args])))
    :(_staticcall(::Type{$t}, class, mId, args::Array) = JNI.$(Symbol("CallStatic" * string(f) * "MethodA"))(class, mId, JNI.jvalue.(args)))
end

#_staticcall(::Type, class, mId, args) = ccall(jnifunc.CallStaticObjectMethodA, Ptr{Nothing},
#  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
#  penv, class, mId, args)
_staticcall(::Type, class, mId, args::Array) = JNI.CallStaticObjectMethodA(class, mId, JNI.jvalue.(args))
_staticcall(::Type, class, mId, args) = JNI.CallStaticObjectMethodA(class, mId, JNI.jvalue.([args]))

@defstaticcall(Bool, Boolean, jboolean)
@defstaticcall(jbyte, Byte, jbyte)
@defstaticcall(jchar, Char, jchar)
@defstaticcall(jshort, Short, jshort)
@defstaticcall(jint, Int, jint)
@defstaticcall(jlong, Long, jlong)
@defstaticcall(jfloat, Float, jfloat)
@defstaticcall(jdouble, Double, jdouble)
@defstaticcall(Nothing, Void, Nothing)

Base.show(io::IO, pxy::JProxy{T,S}) where {T,S} = print(io, S ? "static class $(legalClassName(pxy))" : pxy.toString())

JavaObject(pxy::JProxy{T, false}) where {T} = JavaObject{Symbol(classnamefor(nameof(T)))}(pxyptr(pxy))

# ARG MUST BE CONVERTABLE IN ORDER TO USE CONVERT_ARG
function convert_arg(t::Union{Type{<:JavaObject}, Type{<:JProxy{<:java_lang_Object, false}}}, x::JPrimitive)
    result = box(x)
    result, result
end
convert_arg(t::Type{JavaObject}, x::JProxy) = convert_arg(t, JavaObject(x))
convert_arg(::Type{T1}, x::JProxy) where {T1 <: java_lang} = x, pxyptr(x)
convert_arg(::Type{T}, x) where {T <: java_lang} = convert_arg(JavaObject{Symbol(classnamefor(T))}, x)
convert_arg(::Type{<:JProxy{<:Union{Array{A,N}, java_lang_Object}, false}}, array::JProxy{Array{<:A, N}, false}) where {A, N} = pxyptr(array)
function convert_arg(::Type{<:JProxy{<:Union{Array{A, 1}, java_lang_Object}, false}}, array::Array{A, 1}) where {A <: JPrimitive}
    typ = juliatojava[A]
    #newarray = PtrBox(@jnicall(typ.newarray, Ptr{Nothing},
    #                           (jint, Ptr{Nothing}),
    #                           length(array), C_NULL))
    newarray = PtrBox(typ.newarray(length(array)))
    #@jnicall(typ.arrayregionsetter, Nothing,
    #         (Ptr{Nothing}, Int32, Int32, Ptr{Nothing}),
    #         Ptr(newarray), 0, length(array), array)
    typ.arrayregionsetter(newarray.ptr, 0, length(array), array)
    newarray, newarray.ptr
end
function convert_arg(::Type{JProxy{<:Union{Array{String, 1}, java_lang_Object}, false}}, array::Array{String, 1})
    #newarray = PtrBox(@jnicall(jnifunc.NewObjectArray, Ptr{Nothing},
    #                           (jint, Ptr{Nothing}, Ptr{Nothing}),
    #                           length(array), stringClass, C_NULL))
    newarray = PtrBox(JNI.NewObjectArray( length(array), stringClass, C_NULL ))
    for i in 1:length(array)
        str = JNI.NewStringUTF(array[i])
        JNI.SetObjectArrayElement( Ptr(newarray), i - 1, str)
        #@jnicall(jnifunc.SetObjectArrayElement, Nothing,
        #         (Ptr{Nothing}, Int32, Ptr{Nothing}),
        #         newarray.ptr, i - 1, @jnicall(jnifunc.NewStringUTF, Ptr{Nothing}, (Ptr{UInt8},), array[i]))
    end
    newarray, Ptr(newarray)
end
function convert_arg(::Type{JProxy{Array{java_lang_Object, 1}, false}}, array::Array{<:Union{JPrimitive, JProxy}, 1})
    #newarray = PtrBox(@jnicall(jnifunc.NewObjectArray, Ptr{Nothing},
    #                           (jint, Ptr{Nothing}, Ptr{Nothing}),
    #                           length(array), objectClass, C_NULL))
    newarray = PtrBox( JNI.NewObjectArray( length(array), objectClass, C_NULL ) )
    for i in 1:length(array)
        JNI.SetObjectArrayElement( newarray.ptr, i - 1, box(array([i])) )
        #@jnicall(jnifunc.SetObjectArrayElement, Nothing,
        #         (Ptr{Nothing}, Int32, Ptr{Nothing}),
        #         newarray.ptr, i - 1, box(array[i]))
    end
    newarray, newarray.ptr
end
function convert_arg(::Type{<:JProxy{<:Union{java_lang_Object, java_lang_String}, false}}, str::AbstractString)
    #str, @jnicall(jnifunc.NewStringUTF, Ptr{Nothing}, (Ptr{UInt8},), string(str))
    str, JNI.NewStringUTF( string(str) )
end
function convert_arg(int::Type{<:JProxy{I, false}}, pxy::JProxy{T, false}) where {I <: interface, T}
    if interfacehas(I, T)
        pxy, pxyptr(pxy)
    else
        convert(int, pxy)
    end
end

# Julia support
Base.unsafe_convert(::Type{Ptr{Nothing}}, pxy::JProxy) = pxyptr(pxy)

# iteration and indexing support
Base.length(obj::JavaObject) = Base.length(JProxy(obj))
Base.length(pxy::JProxy{<:Array, false}) = arraylength(pxyptr(pxy))
Base.length(col::JProxy{T, false}) where T = interfacehas(java_util_Collection, T) ? col.size() : 0

Base.getindex(pxy::JProxy{<:Array, false}, i) = arrayget(pxy, i - 1)
function Base.getindex(pxy::JProxy{Array, false}, i::Integer)
   #JProxy(@jnicallregistered(jnifunc.GetObjectArrayElement, Ptr{Nothing},
   #                          (Ptr{Nothing}, jint),
   #                          pxyptr(pxy), jint(i) - 1))
   JProxy( JNI.GetObjectArrayElement( pxyptr(pxy), jint(i) - 1 ) )
end
function Base.getindex(pxy::JProxy{T, false}, i) where T
    if interfacehas(java_util_List, T) || interfacehas(java_util_Map, T)
        pxy.get(i - 1)
    else
        throw(MethodError(getindex, (pxy, i)))
    end
end

Base.setindex!(pxy::JProxy{<:Array{T}, false}, v::T, i) where {T <: JPrimitive} = arrayset!(pxy, i - 1, v)
Base.setindex!(pxy::JProxy{<:Array{<:Union{interface, java_lang}}, false}, v::JPrimitive, i) = Base.setindex!(pxy, JProxy(box(v)), i)
Base.setindex!(pxy::JProxy{<:Array{T}, false}, v::JProxy{U, false}, i) where {T <: java_lang_Object, U <: T} = arrayset!(pxy, i - 1, v)
function Base.setindex!(pxy::JProxy{<:Array{T}, false}, v::JProxy{U, false}, i) where {T <: interface, U <: java_lang}
    if interfacehas(T, U)
        arrayset!(pxy, i - 1, v)
    end
end
function Base.setindex!(pxy::JProxy{T, false}, value, i) where T
    if interfacehas(java_util_List, T)
        pxy.set(i - 1, value)
    elseif interfacehas(java_util_Map, T)
        pxy.put(i, value)
    else
        throw(MethodError(setindex!, (pxy, value, i)))
    end
end

Base.IteratorSize(::JProxy{<:Array, false}) = Base.HasLength()
Base.iterate(array::JProxy{<:Array, false}) = Base.iterate(array, (1, length(array)))
Base.iterate(array::JProxy{<:Array, false}, (next, len)) = next > len ? nothing : (array[next], (next + 1, len))

Base.IteratorSize(::JProxy{T, false}) where T = interfacehas(java_util_Collection, T) ? Base.HasLength() : Base.SizeUnknown()
function Base.iterate(col::JProxy{T, false}) where T
    if interfacehas(java_lang_Iterable, T)
        i = col.iterator()
        nextGetter(col, i)()
    else
        nothing
    end
end
Base.iterate(col::JProxy, state) = state()
function nextGetter(col::JProxy, iter)
    let pending = true, value # memoize value
        function ()
            if pending
                pending = false
                value = iter.hasNext() ? (iter.next(), nextGetter(col, iter)) : nothing
            else
                value
            end
        end
    end
end

#Base.fieldnames(::JProxy{<:Array, false}) = (:length,)
Base.fieldnames(::Type{JProxy{<:Array, false}}) = (:length,)
Base.fieldnames(::Type{JProxy{<:Array{T}, true}}) where {T, STATIC} = fieldnames(JProxy{java_lang_Object, true})
function Base.fieldnames(::Type{JProxy{T, STATIC}}) where {T <: java_lang, STATIC}
    i = infoFor(T)
    Tuple(union(keys(filter((p)-> p[2].static == STATIC, i.fields)), keys(filter((p)-> any((m)-> m.static == STATIC, p[2]), i.methods))))
end
