# See documentation for JProxy for infomation

import Base.==

abstract type java_lang end

classnamefor(t::Type{<:java_lang}) = classnamefor(nameof(t))
classnamefor(s::Symbol) = classnamefor(string(s))
function classnamefor(s::AbstractString)
    s = replace(s, "___" => "_")
    s = replace(s, "_s_" => "\$")
    replace(s, "_" => ".")
end

function _defjtype(a, b)
    symA = Symbol(a)
    eval(quote
        abstract type $symA <: $b  end
        types[Symbol($(classnamefor(a)))] = $symA
    end)
end

macro defjtype(expr)
    :(_defjtype($(string(expr.args[1])), $(expr.args[2])))
end

const types = Dict()

@defjtype java_lang_Object <: java_lang
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

# types
const modifiers = JavaObject{Symbol("java.lang.reflect.Modifier")}
const JField = JavaObject{Symbol("java.lang.reflect.Field")}
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
    setterFunc
    #class::Type{JavaObject{T}} where T # narrowed JavaObject type
    classname::Symbol # legal classname as a symbol
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
end

struct JReadonlyField
    get
end

struct JReadWriteField
    get
    set
end

struct JFieldInfo
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
    classType::Type
end

struct JMethodProxy{N, T}
    pxy # hold onto this so long-held method proxies don't have dead ptr references
    obj::Ptr{Nothing}
    methods::Set
    static::Bool
    function JMethodProxy(N::Symbol, T::Type, pxy, methods)
        new{N, T}(pxy, pxyptr(pxy), methods, pxystatic(pxy))
    end
end

struct Boxing
    info::JavaTypeInfo
    boxType::Type
    boxClass::JClass
    primClass::JClass
    boxer::Ptr{Nothing}
    unboxer::Ptr{Nothing}
end

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
# mutable because it can have a finalizer
mutable struct JProxy{T<:Union{<:java_lang, Array{<:java_lang}, <:AbstractString, <:Number}, C}
    ptr::Ptr{Nothing}
    info::JClassInfo
    static::Bool
    function JProxy{T, C}(ptr::Ptr{Nothing}, info, static) where {T, C}
        finalizer(finalizeproxy, new{T, C}(globalref(ptr), info, static))
    end
end

struct GenInfo
    code
    typeCode
    deps
    classList
    methodDicts
    fielddicts
end

struct GenArgInfo
    name::Symbol
    javaType::Type
    #juliaType::Union{Type,Expr}
    juliaType
    spec
end

const JLegalArg = Union{Number, String, JProxy, Array{Number}, Array{String}, Array{JProxy}}

const methodsById = Dict()
const genned = Set()
const emptyset = Set()
const classes = Dict()
const methodCache = Dict{Tuple{String, String, Array{String}}, JMethodInfo}()
const typeInfo = Dict{AbstractString, JavaTypeInfo}()
const boxers = Dict()
const juliaConverters = Dict()
global jnicalls = Dict()
const defaultjnicall = (instance=:CallObjectMethod,static=:CallStaticObjectMethod)

#function classnamefor(t::Type{<:java_lang})
#    s = replace(string(nameof(t)), "___" => "_")
#    s = replace(s, "_s_" => "\$")
#    Symbol(replace(s, "_" => "."))
#end
#
#const types = Dict([classnamefor(t) => t for t in [
#    java_lang_Object
#    java_util_AbstractCollection
#    java_lang_Number
#    java_lang_Double
#    java_lang_Float
#    java_lang_Long
#    java_lang_Integer
#    java_lang_Short
#    java_lang_Byte
#    java_lang_Character
#    java_lang_Boolean
#]])

#const types = Dict([
#    Symbol("java.lang.Object") => java_lang_Object,
#    Symbol("java.util.AbstractCollection") => java_util_AbstractCollection,
#    Symbol("java.lang.String") => String,
#])
const dynamicTypeCache = Dict()

global genericFieldInfo
global objectClass
global sigTypes

macro jnicall(func, rettype, types, args...)
    quote
        result = ccall($(esc(func)), $(esc(rettype)),
                       (Ptr{JNIEnv}, $(esc.(types.args)...)),
                       penv, $(esc.(args)...))
        result == C_NULL && geterror()
        result
    end
end

macro message(obj, rettype, methodid, args...)
    func = get(jnicalls, rettype, defaultjnicall).instance
    #println("INSTANCE FUNC: ", func)
    flush(stdout)
    quote
        result = ccall(jnifunc.$func, Ptr{Nothing},
                       (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, $((Ptr{Nothing} for i in args)...)),
                       penv, $(esc(obj)), $(esc(methodid)), $(esc.(args)...))
        result == C_NULL && geterror()
        result
    end
end

macro staticmessage(rettype, methodid, args...)
    func = get(jnicalls, rettype, defaultjnicall).static
    #println("STATIC FUNC: ", func)
    flush(stdout)
    expr = quote
        result = ccall(jnifunc.$func, $(esc(rettype)),
                       (Ptr{JNIEnv}, Ptr{Nothing}, $((Ptr{Nothing} for i in args)...)),
                       penv, $(esc(methodid)), $(esc.(args)...))
        result == C_NULL && geterror()
        result
    end
    #println("STATIC CALL: ", expr)
    #if func == defaultjnicall.static && true
    #    expr
    #else
    #    :(objectClass)
    #end
end

globalref(ptr::Ptr{Nothing}) = @jnicall(jnifunc.NewGlobalRef, Ptr{Nothing}, (Ptr{Nothing},), ptr)

function arrayinfo(str)
    if (m = match(r"^(\[+)(.)$", str)) != nothing
        signatureClassFor(m.captures[2]), length(m.captures[1])
    elseif (m = match(r"^(\[+)L(.*);", str)) != nothing
        m.captures[2], length(m.captures[1])
    else
        nothing, 0
    end
end

function finalizeproxy(pxy::JProxy)
    ptr = pxyptr(pxy)
    if ptr == C_NULL || penv == C_NULL; return; end
    #ccall(jnifunc.DeleteGlobalRef, Nothing, (Ptr{JNIEnv}, Ptr{Nothing}), penv, ptr)
    @jnicall(jnifunc.DeleteGlobalRef, Nothing, (Ptr{Nothing},), ptr)
    setfield!(pxy, :ptr, C_NULL) #Safety in case this function is called direcly, rather than at finalize
end

signatureClassFor(name) = length(name) == 1 ? sigTypes[name].classname : name

isVoid(meth::JMethodInfo) = meth.typeInfo.convertType == Nothing

classtypename(ptr::Ptr{Nothing}) = typeNameFor(getclassname(getclass(ptr)))
classtypename(obj::JavaObject{T}) where T = string(T)

# To access static members, use types or metaclasses
# like this: `JProxy(JavaObject{Symbol("java.lang.Byte")}).TYPE`
# or JProxy(JString).valueOf(1)
JProxy(::JavaMetaClass{C}) where C = JProxy(JavaObject{C})
function JProxy(::Type{JavaObject{C}}) where C
    c = Symbol(legalClassName(string(C)))
    obj = classforname(string(c))
    info = infoFor(obj)
    JProxy{typeFor(c), c}(obj.ptr, info, true)
end
# Proxies on classes are on the class objects, they don't get you static members
# To access static members, use types or metaclasses
# like this: `JProxy(JavaObject{Symbol("java.lang.Byte")}).TYPE`
JProxy(s::AbstractString) = JProxy(JString(s))
JProxy{T, C}(ptr::Ptr{Nothing}) where {T, C} = JProxy{T, C}(ptr, infoFor(JClass(getclass(ptr))), false)
function JProxy(ptr::Ptr{Nothing})
    if ptr == C_NULL
        cls = objectClass
        n = "java.lang.Object"
    else
        cls = JClass(getclass(ptr))
        n = legalClassName(getname(cls))
    end
    c = Symbol(n)
    #println("JPROXY INFO FOR ", n, ", ", getname(cls))
    info = infoFor(cls)
    aType, dim = arrayinfo(n)
    if dim != 0
        t = typeFor(Symbol(aType))
        JProxy{Array{typeFor(Symbol(aType)), dim}, c}(ptr, info, false)
    else
        JProxy{typeFor(c), c}(ptr, info, false)
    end
end
function JProxy(obj::JavaObject)
    cls = isNull(obj) ? objectClass : getclass(obj)
    n = legalClassName(getname(cls))
    c = Symbol(n)
    info = infoFor(cls)
    aType, dim = arrayinfo(n)
    if dim != 0
        t = typeFor(Symbol(aType))
        JProxy{Array{typeFor(Symbol(aType)), dim}, c}(JObject(obj.ptr), info, false)
    else
        JProxy{typeFor(c), c}(obj.ptr, info, false)
    end
end

function JavaTypeInfo(setterFunc, class, signature, juliaType, convertType, accessorName, boxType, getter, staticGetter, setter, staticSetter)
    boxClass = classfortype(boxType)
    primitive = length(signature) == 1
    primClass = primitive ? jfield(boxType, "TYPE", JClass) : objectClass
    info = JavaTypeInfo(setterFunc, class, signature, juliaType, convertType, primitive, accessorName, boxType, boxClass, primClass, getter, staticGetter, setter, staticSetter)
    info
end

function JFieldInfo(field::JField)
    fcl = jcall(field, "getType", JClass, ())
    typ = juliaTypeFor(legalClassName(fcl))
    static = isStatic(field)
    cls = jcall(field, "getDeclaringClass", JClass, ())
    id = fieldId(getname(field), JavaObject{Symbol(legalClassName(fcl))}, static, field, cls)
    info = get(typeInfo, legalClassName(fcl), genericFieldInfo)
    JFieldInfo(field, info, static, id, cls)
end

function Boxing(info)
    boxer = methodInfo(getConstructor(info.boxType, info.primClass)).id
    unboxer = methodInfo(getMethod(info.boxType, info.accessorName)).id
    Boxing(info, info.boxType, info.boxClass, info.primClass, boxer, unboxer)
end

gettypeinfo(class::Symbol) = gettypeinfo(string(class))
gettypeinfo(class::AbstractString) = get(typeInfo, class, genericFieldInfo)

hasClass(name::AbstractString) = hasClass(Symbol(name))
hasClass(name::Symbol) = name in genned
hasClass(gen, name::AbstractString) = hasClass(gen, Symbol(name))
hasClass(gen, name::Symbol) = name in genned || haskey(gen.methodDicts, string(name))

function makeType(name::AbstractString, supername::Symbol, gen)
    if string(name) != "String" && !haskey(types, Symbol(name)) && !haskey(gen.methodDicts, name)
        typeName = typeNameFor(name)
        push!(gen.typeCode,
              :(abstract type $typeName <: $supername end),
#              :(types[Symbol($name)] = $typeName)
              )
    end
end

function registerclass(name::AbstractString, classType::Type)
    registerclass(Symbol(name), classType)
end
function registerclass(name::Symbol, classType::Type)
    if !haskey(types, name)
        types[name] = classType
    end
    infoFor(classforname(string(name)))
end

gen(name::Symbol; genmode=:none, print=false, eval=true) = _gen(classforname(string(name)), genmode, print, eval)
gen(name::AbstractString; genmode=:none, print=false, eval=true) = _gen(classforname(name), genmode, print, eval)
gen(class::JClass; genmode=:none, print=false, eval=true) = _gen(class, genmode, eval)
function _gen(class::JClass, genmode, print, evalResult)
    n = legalClassName(class)
    gen = GenInfo()
    genClass(class, gen)
    if genmode == :deep
        while !isempty(gen.deps)
            cls = pop!(gen.deps)
            !hasClass(gen, cls) && genClass(classforname(string(cls)), gen)
        end
    else
        while !isempty(gen.deps)
            cls = pop!(gen.deps)
            !hasClass(gen, cls) && genType(classforname(string(cls)), gen)
        end
    end
    expr = :(begin $(gen.typeCode...); $(gen.code...); $(genClasses(getname.(gen.classList))...); end)
    if print
        for e in expr.args
            println(e)
        end
    end
    evalResult && eval(expr)
end

function genType(class, gen::GenInfo)
    name = getname(class)
    sc = superclass(class)
    push!(genned, Symbol(legalClassName(class)))
    if !isNull(sc)
        if !(Symbol(legalClassName(sc)) in genned)
            genType(getcomponentclass(sc), gen)
        end
        supertype = typeNameFor(sc)
        cType = componentType(supertype)
        makeType(name, cType, gen)
    else
        makeType(name, :java_lang, gen)
    end
end

genClass(class::JClass, gen::GenInfo) = genClass(class, gen, infoFor(class))
function genClass(class::JClass, gen::GenInfo, info::JClassInfo)
    name = getname(class)
    if !(Symbol(name) in genned)
        gen.fielddicts[legalClassName(class)] = fielddict(class)
        push!(gen.classList, class)
        sc = superclass(class)
        #println("SUPERCLASS OF $name is $(isNull(sc) ? "" : "not ")null")
        push!(genned, Symbol(legalClassName(class)))
        if !isNull(sc)
            supertype = typeNameFor(sc)
            cType = componentType(supertype)
            !hasClass(gen, cType) && genClass(sc, gen)
            makeType(name, cType, gen)
        else
            makeType(name, :java_lang, gen)
        end
        genMethods(class, gen, info)
    end
end

GenInfo() = GenInfo([], [], Set(), [], Dict(), Dict())

function GenArgInfo(index, info::JMethodInfo, gen::GenInfo)
    javaType = info.argTypes[index]
    GenArgInfo(Symbol("a" * string(index)), javaType, argType(javaType, gen), argSpec(javaType, gen))
end

argType(t, gen) = t
argType(::Type{JavaObject{Symbol("java.lang.String")}}, gen) = String
#argType(::Type{JavaObject{Symbol("java.lang.Object")}}, gen) = JLegalArg
argType(::Type{JavaObject{Symbol("java.lang.Object")}}, gen) = :JLegalArg
argType(::Type{<: Number}, gen) = Number
argType(typ::Type{JavaObject{T}}, gen) where T = :(JProxy{<:$(typeNameFor(T, gen)), T})

argSpec(t, gen) = t
argSpec(::Type{JavaObject{Symbol("java.lang.String")}}, gen) = String
argSpec(::Type{JavaObject{Symbol("java.lang.Object")}}, gen) = :JObject
argSpec(::Type{<: Number}, gen) = Number
argSpec(typ::Type{JavaObject{T}}, gen) where T = :(JProxy{<:$(typeNameFor(T, gen)), T})
argSpec(arg::GenArgInfo) = arg.spec

#legalClassName(cls::Ptr{Nothing}) = legalClassName(getclassname(getclass(cls)))
legalClassName(pxy::JProxy) = legalClassName(getclassname(pxystatic(pxy) ? pxyptr(pxy) : getclass(pxyptr(pxy))))
legalClassName(cls::JavaObject) = legalClassName(getname(cls))
legalClassName(cls::Symbol) = legalClassName(string(cls))
function legalClassName(name::AbstractString)
    if (m = match(r"^(.*)((\[])+)$", name)) != nothing
        dimensions = Integer(length(m.captures[2]) / 2)
        info = get(typeInfo, m.captures[1], nothing)
        base = if info != nothing && info.primitive
            info.signature
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

typeNameFor(T::Symbol, gen::GenInfo) = typeNameFor(string(T), gen)
function typeNameFor(T::AbstractString, gen::GenInfo)
    aType, dims = arrayinfo(T)
    c = dims != 0 ? aType : T
    csym = Symbol(c)
    if (dims == 0 || length(c) > 1) && !(csym in gen.deps) && !hasClass(gen, csym) && !get(typeInfo, c, genericFieldInfo).primitive
        push!(gen.deps, csym)
    end
    typeNameFor(T)
end
typeNameFor(class::JClass) = typeNameFor(legalClassName(class))
typeNameFor(className::Symbol) = typeNameFor(string(className))
function typeNameFor(className::AbstractString)
    if className == "java.lang.String"
        String
    elseif length(className) == 1
        sigTypes[className].convertType
    else
        n = replace(className, "_" => "___")
        n = replace(className, "\$" => "_s_")
        n = replace(n, "." => "_")
        aType, dims = arrayinfo(n)
        if dims != 0
            :(Array{$(typeNameFor(aType)), $(length(dims))})
        else
            t = get(typeInfo, n, genericFieldInfo)
            if t.primitive
                t.juliaType
            else
                Symbol(n)
            end
        end
    end
end

macro jp(s)
    :(JProxy{$(s), Symbol($(classnamefor(s)))})
end

function argCode(arg::GenArgInfo)
    argname = arg.name
    if arg.juliaType == String
        #:(JString($argname))
        argname
    elseif arg.juliaType == JLegalArg
        :(box($argname))
    elseif arg.juliaType == Number
        :($(arg.javaType)($argname))
    else
        argname
    end
end

function fieldEntry((name, fld))
    fieldType = JavaObject{Symbol(legalClassName(fld.owner))}
    name => :(jfield($(fld.typeInfo.class), $(string(name)), $fieldType))
end

function genMethods(class, gen, info)
    #push!(genned, Symbol(typeNameFor(legalClassName(class))))
    methodList = listmethods(class)
    classname = legalClassName(class)
    gen.methodDicts[classname] = methods = Dict()
    typeName = typeNameFor(classname, gen)
    classVar = Symbol("class_" * string(typeName))
    fieldsVar = Symbol("fields_" * string(typeName))
    methodsVar = Symbol("staticMethods_" * string(typeName))
    push!(gen.code, :($classVar = classforname($classname)))
    push!(gen.code, :($fieldsVar = Dict([$([fieldEntry(f) for f in gen.fielddicts[classname]]...)])))
    push!(gen.code, :($methodsVar = Set($([string(n) for (n, m) in info.methods if any(x->x.static, m)]))))
    push!(gen.code, :(function Base.getproperty(p::JProxy{T, C}, name::Symbol) where {T <: $typeName, C}
                      if (f = get($fieldsVar, name, nothing)) != nothing
                              getField(p, name, f)
                          else
                              JMethodProxy(name, $typeName, p, emptyset)
                          end
                      end))
    for nameSym in sort(collect(keys(info.methods)))
        name = string(nameSym)
        multiple = length(info.methods[nameSym]) > 1
        symId = 0
        for minfo in info.methods[nameSym]
            owner = javaType(minfo.owner)
            if isSame(class.ptr, minfo.owner.ptr)
                symId += 1
                args = (GenArgInfo(i, minfo, gen) for i in 1:length(minfo.argTypes))
                argDecs = (:($(arg.name)::$(arg.juliaType)) for arg in args)
                methodIdName = Symbol("method_" * string(typeName) * "__" * name * (multiple ? string(symId) : ""))
                callinfo = jnicalls[minfo.typeInfo.classname]
                push!(gen.code, :($methodIdName = getmethodid($(minfo.static), $classVar, $name, $(legalClassName(minfo.returnClass)), $(legalClassName.(minfo.argClasses)))))
                push!(gen.code, :(function (pxy::JMethodProxy{Symbol($name), <: $typeName})($(argDecs...))::$(genReturnType(minfo, gen))
                                      println($("Generated method $name$(multiple ? "(" * string(symId) * ")" : "")"))
                                      $(genConvertResult(minfo.typeInfo.convertType, minfo, :(call(pxy.obj, $methodIdName, $(static ? callinfo.static : callinfo.instance), $(minfo.typeInfo.juliaType), ($(argSpec.(args)...),), $((argCode(arg) for arg in args)...)))))
                                  end))
            end
        end
    end
    push!(gen.code, :(push!(genned, Symbol($(legalClassName(class))))))
end

function genReturnType(methodInfo, gen)
    t = methodInfo.typeInfo.convertType
    if methodInfo.typeInfo.primitive || t <: String || t == Nothing
        t
    else
        :(JProxy{<:$(typeNameFor(methodInfo.returnType, gen))})
    end
end


genConvertResult(toType::Type{Bool}, info, expr) = :($expr != 0)
genConvertResult(toType::Type{String}, info, expr) = :(unsafe_string($expr))
#genConvertResult(toType::Type{<:JBoxTypes}, info, expr) = :(unbox($expr))
genConvertResult(toType::Type{<:JBoxTypes}, info, expr) = :(unbox($(toType.parameters[1]), $expr))
function genConvertResult(toType, info, expr)
    if isVoid(info) || info.typeInfo.primitive
        expr
    else
        :(asJulia($toType, $expr))
    end
end

isArray(class::JClass) = jcall(class, "isArray", jboolean, ()) != 0

function JClassInfo(class::JClass)
    n = Symbol(legalClassName(class))
    sc = superclass(class)
    parentinfo = !isNull(sc) ? infoFor(sc) : nothing
    tname = typeNameFor(string(n))
    #println("JCLASS INFO FOR ", n)
    jtype = get!(types, n) do
        if tname != String
            #println("DEFINING ", repr(tname), quote
            #    abstract type $tname <: JavaCall.$(isNull(sc) ? :java_lang : typeNameFor(Symbol(legalClassName(sc)))) end
            #    $tname
            #end)
            JavaCall.eval(quote
                abstract type $tname <: JavaCall.$(isNull(sc) ? :java_lang : typeNameFor(Symbol(legalClassName(sc)))) end
                $tname
            end)
        end
    end
    classes[n] = JClassInfo(parentinfo, class, fielddict(class), methoddict(class), jtype)
end

genClasses(classNames) = (:(registerclass($name, $(Symbol(typeNameFor(name))))) for name in reverse(classNames))

function typeFor(sym::Symbol)
    aType, dims = arrayinfo(string(sym))
    dims != 0 ? Array{get(types, Symbol(aType), java_lang), length(dims)} : get(types, sym, java_lang)
end

asJulia(t, obj) = obj
asJulia(::Type{Bool}, obj) = obj != 0
asJulia(t, obj::JBoxed) = unbox(obj)
function asJulia(x, ptr::Ptr{Nothing})
    if ptr == C_NULL
        jnull
    else
        unbox(JavaObject{Symbol(legalClassName(getclassname(getclass(ptr))))}, ptr)
    end
end

box(str::AbstractString) = str
box(pxy::JProxy) = ptrObj(pxy)
#function box(array::Array{T,N})
#end
unbox(obj) = obj
unbox(::Type{T}, obj) where T = obj
function unbox(::Type{JavaObject{T}}, obj::Ptr{Nothing}) where T
    if  obj == C_NULL
        nothing
    else
        #println("UNBOXING ", T)
        (get(juliaConverters, string(T)) do
            (x)-> JProxy(x)
        end)(obj)
    end
end

pxyptr(p::JProxy) = getfield(p, :ptr)
pxyinfo(p::JProxy) = getfield(p, :info)
pxystatic(p::JProxy) = getfield(p, :static)

==(j1::JProxy, j2::JProxy) = isSame(pxyptr(j1), pxyptr(j2))

isSame(j1::JavaObject, j2::JavaObject) = isSame(j1.ptr, j2.ptr)
isSame(j1::Ptr{Nothing}, j2::Ptr{Nothing}) = @jnicall(jnifunc.IsSameObject, Ptr{Nothing}, (Ptr{Nothing}, Ptr{Nothing}), j1, j2) != C_NULL

getreturntype(c::JConstructor) = voidClass

function getMethod(class::Type, name::AbstractString, argTypes...)
    jcall(classfortype(class), "getMethod", JMethod, (JString, Vector{JClass}), name, collect(JClass, argTypes))
end

function getConstructor(class::Type, argTypes...)
    jcall(classfortype(class), "getConstructor", JConstructor, (Vector{JClass},), collect(argTypes))
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
        methodsById[length(methodsById)] = JMethodInfo(name, info, Symbol(typeName), returnType, Tuple(juliaTypeFor.(argTypes)), argTypes, methodId, isStatic(m), owner, get(jnicalls, typeName, Tuple(filterDynArgType.(juliaTypeFor.(argTypes)))))
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

conv(func::Function, typ::AbstractString) = juliaConverters[typ] = func

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
            JavaTypeInfo(Symbol($(string(jclass))), $sig, $ctyp, $jtyp, $accessor, JavaObject{Symbol($boxType)}, $(s("Get", Typ)), $(s("GetStatic", Typ)), $(s("Set", Typ)), $(s("SetStatic", Typ))) do field, obj, value::$(object ? :JavaObject : ctyp)
                @jnicall(field.static ? field.typeInfo.staticSetter : field.typeInfo.setter, Ptr{Nothing},
                      (Ptr{Nothing}, Ptr{Nothing}, $(object ? :(Ptr{Nothing}) : ctyp)),
                      (field.static ? field.owner : obj).ptr, field.id, $(object ? :(value.ptr) : :value))
            end
        end
    end
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
    )
    global objectClass = classforname("java.lang.Object")
    global classClass = classforname("java.lang.Class")
    global voidClass = jfield(JavaObject{Symbol("java.lang.Void")}, "TYPE", JClass)
    global methodid_getmethod = getmethodid("java.lang.Class", "getMethod", "java.lang.reflect.Method", "java.lang.String", "[Ljava.lang.Class;")
    conv("java.lang.String") do x; unsafe_string(x); end
    conv("java.lang.Integer") do x; @jp(java_lang_Integer)(x).intValue(); end
    conv("java.lang.Long") do x; @jp(java_lang_Long)(x).longValue(); end
    push!(typeInfo,
        "void" => @vtypeInf(void, jint, "V", Nothing, Object, false, Void),
        "boolean" => @typeInf(boolean, "Z", Bool, Boolean),
        "byte" => @typeInf(byte, "B", Int8, Byte),
        "char" => @typeInf(char, "C", Char, Character),
        "short" => @typeInf(short, "S", Int16, Short),
        "int" => @typeInf(int, "I", Int32, Integer),
        "float" => @typeInf(float, "F", Float32, Float),
        "long" => @typeInf(long, "J", Int64, Long),
        "double" => @typeInf(double, "D", Float64, Double),
        "java.lang.String" => @vtypeInf("java.lang.String", String, "Ljava/lang/String;", String, Object, true, Object),
    )
    global sigTypes = Dict([inf.signature => inf for (key, inf) in typeInfo if inf.primitive])
    global genericFieldInfo = @vtypeInf("java.lang.Object", Any, "Ljava/lang/Object", JObject, Object, true, Object)
    global methodId_object_getClass = getmethodid("java.lang.Object", "getClass", "java.lang.Class")
    global methodId_class_getName = getmethodid("java.lang.Class", "getName", "java.lang.String")
    for info in (t->typeInfo[string(t)]).(:(int, long, byte, boolean, char, short, float, double).args)
        infoName = string(info.classname)
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
            function unbox(::Type{$(info.boxType)}, ptr::Ptr{Nothing})
                $(if box.info.convertType == Bool
                    :(call(ptr, $boxVar.unboxer, $boxVar.info.juliaType, ()) != 0)
                else
                    :(call(ptr, $boxVar.unboxer, $boxVar.info.juliaType, ()))
                end)
            end
            function unbox(::Type{$(types[javaType(info.boxType)])}, ptr::Ptr{Nothing})
                $(if box.info.convertType == Bool
                    :(call(ptr, $boxVar.unboxer, $boxVar.info.juliaType, ()) != 0)
                else
                    :(call(ptr, $boxVar.unboxer, $boxVar.info.juliaType, ()))
                end)
            end
            function unbox(obj::$(info.boxType))
                $(if box.info.convertType == Bool
                    :(_jcall(obj, $boxVar.unboxer, C_NULL, $(box.info.juliaType), ()) != 0)
                else
                    :(_jcall(obj, $boxVar.unboxer, C_NULL, $(box.info.juliaType), ()))
                end)
            end
        end
        #println("BOX METHOD FOR ", box.boxType)
        #println(expr)
        eval(expr)
    end
end

metaclass(class::AbstractString) = metaclass(Symbol(class))

getclass(obj::Ptr{Nothing}) = @message(obj, Object, methodId_object_getClass)

getclassname(class::Ptr{Nothing}) = unsafe_string(@message(class, Object, methodId_class_getName))

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
    #println(@macroexpand @jnicall(static ? jnifunc.GetStaticMethodID : jnifunc.GetMethodID, Ptr{Nothing},
    #        (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
    #        jclass, name, sig))
    @jnicall(static ? jnifunc.GetStaticMethodID : jnifunc.GetMethodID, Ptr{Nothing},
            (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
            jclass, name, sig)
end

function fieldId(name, typ::Type{JavaObject{C}}, static, field, cls::JClass) where {C}
    #id = ccall(static ? jnifunc.GetStaticFieldID : jnifunc.GetFieldID, Ptr{Nothing},
    #           (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
    #           penv, metaclass(legalClassName(cls)), name, proxyClassSignature(string(C)))
    #id == C_NULL && geterror(true)
    #id
    @jnicall(static ? jnifunc.GetStaticFieldID : jnifunc.GetFieldID, Ptr{Nothing},
            (Ptr{Nothing}, Ptr{UInt8}, Ptr{UInt8}),
            metaclass(legalClassName(cls)), name, proxyClassSignature(string(C)))
end

function infoSignature(cls::AbstractString)
    info = get(typeInfo, cls, nothing)
    if info != nothing; info.signature; end
end

#function proxyClassSignature(cls::AbstractString)
#    sig = infoSignature(cls)
#    sig != nothing ? sig : proxyClassSignature(classforname(cls))
#end
#function proxyClassSignature(cls::JClass)
#    info = get(typeInfo, getname(cls), nothing)
#    if info != nothing && info.primitive
#        info.signature
#    else
#        sig = []
#        while jcall(cls, "isArray", jboolean, ()) != 0
#            push!(sig, "[")
#            cls = jcall(cls, "getComponentType", JClass, ())
#        end
#        clSig = infoSignature(jcall(cls, "getSimpleName", JString, ()))
#        push!(sig, clSig != nothing ? clSig : "L" * javaclassname(getname(cls)) * ";")
#        join(sig, "")
#    end
#end
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

function infoFor(class::JClass)
    if isNull(class)
        nothing
    else
        name = legalClassName(class)
        #println("INFO FOR ", name)
        haskey(classes, name) ? classes[name] : classes[name] = JClassInfo(class)
    end
end

getname(thing::Union{JClass, JMethod, JField}) = jcall(thing, "getName", JString, ())
getname(thing::JConstructor) = "<init>"

#classforlegalname(n::AbstractString) = (i = get(typeInfo, n, nothing)) != nothing && i.primitive ? i.primClass : classforname(n)

function classforlegalname(n::AbstractString)
    try
        (i = get(typeInfo, n, nothing)) != nothing && i.primitive ? i.primClass : classforname(n)
    catch x
        #println("Error finding class: $n, type: $(typeof(n))")
        throw(x)
    end
end

classfortype(t::Type{JavaObject{T}}) where T = classforname(string(T))

listfields(cls::AbstractString) = listfields(classforname(cls))
listfields(cls::Type{JavaObject{C}}) where C = listfields(classforname(string(C)))
listfields(cls::JClass) = jcall(cls, "getFields", Vector{JField}, ())

function fielddict(class::JClass)
    if isArray(class)
        Dict([:length => JReadonlyField((obj)->arraylength(obj.ptr))])
    else
        Dict([Symbol(getname(item)) => JFieldInfo(item) for item in listfields(class)])
    end
end

#arraylength(obj) = ccall(jnifunc.GetArrayLength, jint, (Ptr{JNIEnv}, Ptr{Nothing}), penv, obj)
arraylength(obj) = jni(jnifunc.GetArrayLength, jint, (Ptr{Nothing}), obj)

#function Base.getindex(pxy::JProxy{Array{T}}, I::Vararg{Int, N}) where {T, N}
#end
function Base.getindex(pxy::JProxy{Array{T, 1}}, i::Int) where T
    asJulia(JObject, JObject(@jnicall(jnifunc.GetObjectArrayElement, Ptr{Nothing},
                                     (Ptr{Nothing}, jint),
                                     pxyptr(pxy), jint(i))))
end

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

isNull(obj::JavaObject) = isNull(obj.ptr)
isNull(ptr::Ptr{Nothing}) = Int64(ptr) == 0

superclass(obj::JavaObject) = jcall(obj, "getSuperclass", @jimport(java.lang.Class), ())

function getField(p::JProxy, field::JFieldInfo)
    asJulia(field.typeInfo.juliaType, @jnicall(static ? field.typeInfo.staticGetter : field.typeInfo.getter, Ptr{Nothing},
                                           (Ptr{Nothing}, Ptr{Nothing}),
                                           pxystatic(p) ? getclass(obj) : pxyptr(p), field.id))
end

function Base.getproperty(p::JProxy{T}, name::Symbol) where T
    info = pxyinfo(p)
    if haskey(info.methods, name)
        JMethodProxy(name, T, p, info.methods[name])
    else
        finfo = info.fields[name]
        asJulia(finfo.typeInfo, getproxyfield(p, info, finfo))
    end
end

getproxyfield(p::JProxy, info::JClassInfo, field::JReadonlyField) = field.get(pxyptr(p))
function getproxyfield(p::JProxy, info::JClassInfo, field::JFieldInfo)
    static = pxystatic(p)
    ptr = pxyptr(p)
    asJulia(field.typeInfo.juliaType, @jnicall(static ? field.typeInfo.staticGetter : field.typeInfo.getter, Ptr{Nothing},
                                          (Ptr{Nothing}, Ptr{Nothing}),
                                          static ? getclass(ptr) : ptr, field.id))
end

function Base.setproperty!(p::JProxy, name::Symbol, value)
    info = pxyinfo(p)
    meths = get(info.methods, name, nothing)
    static = pxystatic(p)
    result = if meths != nothing
        throw(JavaCallError("Attempt to set a method"))
    else
        field = info.fields[name]
        value = convert(field.typeInfo.primitive ? field.typeInfo.juliaType : field.typeInfo.class, value)
        result = field.typeInfo.setterFunc(field, obj, value)
        result == C_NULL && geterror()
        value
    end
    isa(result, JavaObject) ? JProxy(result) : result
end

function (pxy::JMethodProxy{N})(args...) where N
    targets = Set(m for m in pxy.methods if fits(m, args))
    #println("LOCATING MESSAGE ", N, " FOR ARGS ", repr(args))
    if !isempty(targets)
        # Find the most specific method
        argTypes = typeof(args).parameters
        meth = reduce(((x, y)-> moreGeneral(argTypes, x, y) < moreGeneral(argTypes, y, x) ? x : y), filterStatic(pxy, targets))
        #println("SEND MESSAGE ", N, " RETURNING ", meth.typeInfo.juliaType)
        #withlocalref((meth.static ? staticcall : call)(pxy.obj, meth.id, meth.typeInfo.juliaType, meth.argTypes, args...)) do result
        withlocalref((meth.static ? staticcall : call)(pxy.obj, meth.id, meth.typeInfo.juliaType, meth.dynArgTypes, args...)) do result
            asJulia(meth.typeInfo.convertType, result)
        end
    end
end

withlocalref(func, result::Any) = func(result)
function withlocalref(func, ptr::Ptr{Nothing})
    ref = ccall(jnifunc.NewLocalRef, Ptr{Nothing}, (Ptr{JNIEnv}, Ptr{Nothing}), penv, ptr)
    try
        func(ref)
    finally
        deletelocalref(ptr::Ptr{Nothing}) = ccall(jnifunc.DeleteLocalRef, Nothing, (Ptr{JNIEnv}, Ptr{Nothing}), penv, ref)
    end
end

function filterStatic(pxy::JMethodProxy, targets)
    static = pxy.static
    Set(target for target in targets if target.static == static)
end

fits(method::JMethodInfo, args::Tuple) = length(method.dynArgTypes) == length(args) && all(canConvert.(method.dynArgTypes, args))

#canConvert(::Type{T}, ::T) where T = true
canConvert(::Type{JavaObject{Symbol("java.lang.Object")}}, ::Union{AbstractString, Real}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Double")}}, ::Union{Float64, Float32, Float16, Int64, Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Float")}}, ::Union{Float32, Float16, Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Long")}}, ::Union{Int64, Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Integer")}}, ::Union{Int32, Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Short")}}, ::Union{Int16, Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Byte")}}, ::Union{Int8}) = true
canConvert(::Type{JavaObject{Symbol("java.lang.Character")}}, ::Union{Int8, Char}) = true
canConvert(::Type{String}, ::AbstractString) = true
canConvert(::Type{JString}, ::AbstractString) = true
canConvert(::Type{<: Real}, ::T) where {T <: Real} = true
canConvert(::Type{jboolean}, ::Bool) = true
canConvert(::Type{jchar}, ::Char) = true
canConvert(::Type{<:Integer}, ::Ptr{Nothing}) = true
canConvert(x, y) = false
convert(::Type{JObject}, pxy::JProxy) = JavaObject(pxy)

# score relative generality of two methods as applied to a particular set of arguments
# higher means p1 is more general than p2 (i.e. p2 is the more specific one)
function moreGeneral(argTypes, p1::JMethodInfo, p2::JMethodInfo) where T
    g = 0
    for i in 1:length(argTypes)
        c1, c2 = p1.argClasses[i], p2.argClasses[i]
        t1, t2 = p1.argTypes[i], p2.argTypes[i]
        g += moreGeneral(argTypes[i], c1, t1, c2, t2) - moreGeneral(argTypes[i], c2, t2, c1, t1)
    end
    g
end

isPrimitive(cls::JavaObject) = jcall(cls, "isPrimitive", jboolean, ()) != 0

# score relative generality of corresponding arguments in two methods
# higher means c1 is more general than c2 (i.e. c2 is the more specific one)
function moreGeneral(argType::Type, c1::JClass, t1::Type, c2::JClass, t2::Type)
    p1 = t1 <: JPrimitive
    p2 = t2 <: JPrimitive
    g1 = !p1 ? 0 : argType <: t1 ? 1 : -1
    g2 = !p2 ? 0 : argType <: t2 ? 1 : -1
    g = if !p1 && p2 || jcall(c1, "isAssignableFrom", jboolean, (@jimport(java.lang.Class),), c2) != 0
        1
    else
        0
    end
    g + g2 - g1
end

function call(ptr::Ptr{Nothing}, mId::Ptr{Nothing}, rettype::Type{T}, argtypes::Tuple, args...) where T
    ptr == C_NULL && error("Attempt to call method on Java NULL")

    savedargs, convertedargs = convert_args(argtypes, args...)
    result = _call(T, ptr, mId, convertedargs)
    result == C_NULL && geterror()
    asJulia(rettype, convert_result(rettype, result))
end

_call(::Type, obj, mId, args) = ccall(jnifunc.CallObjectMethodA, Ptr{Nothing},
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{Bool}, obj, mId, args) = ccall(jnifunc.CallBooleanMethodA, jboolean,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jbyte}, obj, mId, args) = ccall(jnifunc.CallByteMethodA, jbyte,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jchar}, obj, mId, args) = ccall(jnifunc.CallCharMethodA, jchar,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jshort}, obj, mId, args) = ccall(jnifunc.CallShortMethodA, jshort,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jint}, obj, mId, args) = ccall(jnifunc.CallIntMethodA, jint,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jlong}, obj, mId, args) = ccall(jnifunc.CallLongMethodA, jlong,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jfloat}, obj, mId, args) = ccall(jnifunc.CallFloatMethodA, jfloat,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_call(::Type{jdouble}, obj, mId, args) = ccall(jnifunc.CallDoubleMethodA, jdouble,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)

function staticcall(class::Ptr{Nothing}, mId, rettype::Type{T}, argtypes::Tuple, args...) where T
    savedargs, convertedargs = convert_args(argtypes, args...)
    result = _staticcall(T, class, mId, convertedargs)
    #println("CONVERTING RESULT ", repr(result), " TO ", rettype)
    result == C_NULL && geterror()
    #println("RETTYPE: ", rettype)
    asJulia(rettype, convert_result(rettype, result))
end

_staticcall(::Type{Any}, obj, mId, args) = ccall(jnifunc.CallStaticObjectMethodA, Ptr{Nothing},
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{Bool}, obj, mId, args) = ccall(jnifunc.CallStaticBooleanMethodA, jboolean,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jbyte}, obj, mId, args) = ccall(jnifunc.CallStaticByteMethodA, jbyte,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jchar}, obj, mId, args) = ccall(jnifunc.CallStaticCharMethodA, jchar,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jshort}, obj, mId, args) = ccall(jnifunc.CallStaticShortMethodA, jshort,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jint}, obj, mId, args) = ccall(jnifunc.CallStaticIntMethodA, jint,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jlong}, obj, mId, args) = ccall(jnifunc.CallStaticLongMethodA, jlong,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jfloat}, obj, mId, args) = ccall(jnifunc.CallStaticFloatMethodA, jfloat,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)
_staticcall(::Type{jdouble}, obj, mId, args) = ccall(jnifunc.CallStaticDoubleMethodA, jdouble,
  (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}, Ptr{Nothing}),
  penv, obj, mId, args)

function Base.show(io::IO, pxy::JProxy)
    if pxystatic(pxy)
        print(io, "static class $(legalClassName(getclassname(pxyptr(pxy))))")
    else
        print(io, pxy.toString())
        #print(io, Java.toString(pxy))
    end
end

JavaObject(pxy::JProxy{T, C}) where {T, C} = JavaObject{C}(pxyptr(pxy))
