# TODO: box incoming primitives that are sent to object args, including Strings

import Base.==

# See documentation for JProxy for infomation

const JField = JavaObject{Symbol("java.lang.reflect.Field")}

global genericFieldInfo
global objectClass
global sigTypes
methodsById = Dict()
genned = Set()
const emptyset = Set()

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
    name::AbstractString
    typeInfo::JavaTypeInfo
    returnType::Type # kluge this until we get generate typeInfo properly for new types
    returnClass::JClass
    argTypes::Tuple
    argClasses::Array{JClass}
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
        typ = juliaTypeFor(legalClassName(fcl))
        static = isStatic(field)
        cls = jcall(field, "getDeclaringClass", JClass, ())
        id = fieldId(getname(field), JavaObject{Symbol(legalClassName(fcl))}, static, field, cls)
        info = get(typeInfo, legalClassName(fcl), genericFieldInfo)
        new(field, info, static, id, cls)
    end
end

struct JMethodProxy{N, T}
    obj
    methods::Set
    static::Bool
end

struct JClassInfo
    parent::Union{Nothing, JClassInfo}
    class::JClass
    fields::Dict{Symbol, JFieldInfo}
    methods::Dict{Symbol, Set{JMethodInfo}}
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

abstract type java_lang_Object end
abstract type java_util_AbstractCollection <: java_lang_Object end

#types = Dict("java.lang.Object" => java_lang_Object)
types = Dict([
    Symbol("java.lang.Object") => java_lang_Object,
    Symbol("java.util.AbstractCollection") => java_util_AbstractCollection,
    Symbol("java.lang.String") => String,
])

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
struct JProxy{T<:Union{<:java_lang_Object, Array{<:java_lang_Object}}}
    obj::JavaObject
    info::JClassInfo
    static::Bool
    JProxy(s::AbstractString; deep=false) = JProxy(JString(s), deep=deep)
    JProxy(::JavaMetaClass{C}; deep=false) where C = JProxy(JavaObject{C}, static=true, deep=deep)
    function JProxy(obj::JavaObject; deep=false) where C
        obj = narrow(obj)
        aType, dim = arrayInfo(string(javaType(obj)))
        if dim != 0
            t = typeFor(Symbol(aType))
            info = infoFor(objectClass, deep=deep)
            new{Array{typeFor(Symbol(aType)), length(dims)}}(JObject(obj.ptr), info, false)
        else
            info = infoFor(isNull(obj) ? objectClass : getclass(obj), deep=deep)
            new{types[javaType(obj)]}(obj, info, false)
        end
    end
    function JProxy(::Type{JavaObject{C}}; static=false, deep=false) where C
        obj = classforname(string(C))
        info = infoFor(obj, deep=deep)
        new{typeFor(C)}(obj, info, true)
    end
end

struct GenInfo
    code
    typeCode
    deps
    classList
    methodSets
    fielddicts
    GenInfo() = new([], [], Set(), [], Dict(), Dict())
end

function arrayInfo(str)
    if (m = match(r"^(\[+)L(.*);", str)) != nothing
        m.captures[2], length(m.captures[1])
    else
        nothing, 0
    end
end

const JLegalArg = Union{Number, String, JProxy, Array{Number}, Array{String}, Array{JProxy}}
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

gettype(class::Symbol) = get(types, class, java_lang_Object)

gettypeinfo(class::Symbol) = gettypeinfo(string(class))
gettypeinfo(class::AbstractString) = get(typeInfo, class, genericFieldInfo)

hasClass(name::AbstractString) = hasClass(Symbol(name))
hasClass(name::Symbol) = name in genned
hasClass(gen, name::AbstractString) = hasClass(gen, Symbol(name))
hasClass(gen, name::Symbol) = name in genned || haskey(gen.methodSets, string(name))

function makeType(name::AbstractString, supername::Symbol, gen)
    if !haskey(types, Symbol(name)) && !haskey(gen.methodSets, name)
        typeName = typeNameFor(name)
        push!(gen.typeCode,
              :(abstract type $typeName <: $supername end),
#              :(types[Symbol($name)] = $typeName)
              )
    end
end

function gen(name::AbstractString, classType::Type)
    gen(Symbol(name), classType)
end
function gen(name::Symbol, classType::Type)
    if !(name in genned)
        types[name] = classType
        gen(classforname(string(name)))
    end
end
function gen(class::JClass; deep=false)
    gen = GenInfo()
    genClass(class, gen)
    if deep
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
    #println("\nEVALUATING...\n\n")
    expr = :(begin $(gen.typeCode...); $(gen.code...); $(genClasses(getname.(gen.classList))...); end)
    println(expr)
    eval(expr)
    for cl in gen.classList
        n = legalClassName(cl)
        classes[n] = JClassInfo(cl, gen.fielddicts[n], gen.methodSets[n], types[Symbol(n)])
    end
end

function genType(class, gen::GenInfo)
    name = getname(class)
    sc = superclass(class)
    push!(genned, Symbol(legalClassName(class)))
    if !isNull(sc)
        supertype = typeNameFor(sc)
        cType = componentType(supertype)
        makeType(name, cType, gen)
    else
        makeType(name, :java_lang_Object, gen)
    end
end

function genClass(class, gen::GenInfo)
    gen.fielddicts[legalClassName(class)] = fielddict(class)
    push!(gen.classList, class)
    name = getname(class)
    sc = superclass(class)
    #println("SUPERCLASS OF $name is $(isNull(sc) ? "" : "not ")null")
    push!(genned, Symbol(legalClassName(class)))
    if !isNull(sc)
        supertype = typeNameFor(sc)
        cType = componentType(supertype)
        !hasClass(gen, cType) && genClass(sc, gen)
        makeType(name, cType, gen)
    else
        makeType(name, :java_lang_Object, gen)
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
argType(typ::Type{JavaObject{T}}, gen) where T = :(JProxy{<:$(typeNameFor(T, gen))})

legalClassName(cls::JavaObject) = legalClassName(getname(cls))
legalClassName(cls::Symbol) = legalClassName(string(cls))
function legalClassName(name::AbstractString)
    if (m = match(r"((\[])+)$", name)) != nothing
        dimensions = Integer(length(m.captures[1]) / 2)
        "$(repeat('[', dimensions))L$(name[1:end-dimensions * 2]);"
    else
        name
    end
end

componentType(e::Expr) = e.args[2]
componentType(sym::Symbol) = sym

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
        aType, dims = arrayInfo(n)
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
typeNameFor(T::Symbol, gen::GenInfo) = typeNameFor(string(T), gen)
function typeNameFor(T::AbstractString, gen::GenInfo)
    aType, dims = arrayInfo(T)
    c = dims != 0 ? aType : T
    csym = Symbol(c)
    if (dims == 0 || length(c) > 1) && !(csym in gen.deps) && !hasClass(gen, csym) && !get(typeInfo, c, genericFieldInfo).primitive
        #println("GEN CLASS: $c")
        push!(gen.deps, csym)
    end
    typeNameFor(T)
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

function fieldEntry((name, fld))
    fieldType = JavaObject{Symbol(legalClassName(fld.owner))}
    name => :(jfield($(fld.info.class), $(string(name)), $fieldType))
end

function genMethods(class, gen)
    #push!(genned, Symbol(typeNameFor(legalClassName(class))))
    methodList = listmethods(class)
    classname = legalClassName(class)
    gen.methodSets[classname] = methods = Set()
    typeName = typeNameFor(classname, gen)
    classVar = Symbol("class_" * string(typeName))
    fieldsVar = Symbol("fields_" * string(typeName))
    methodsVar = Symbol("staticMethods_" * string(typeName))
    push!(gen.code, :($classVar = classforname($classname)))
    push!(gen.code, :($fieldsVar = Dict([$([fieldEntry(f) for f in gen.fielddicts[classname]]...)])))
    push!(gen.code, :($methodsVar = Set($([getname(m) for m in methodList if isStatic(m)]))))
    push!(gen.code, :(function Base.getproperty(p::JProxy{<: $typeName}, name::Symbol)
                          if (f = get($fieldsVar, name, nothing)) != nothing
                              getField(p, name, f)
                          else
                              JMethodProxy{name, $typeName}(pxyObj(p), emptyset, name in $methodsVar)
                          end
                      end))
    for method in methodList
        name = Symbol(getname(method))
        push!(methods, name)
        info = methodInfo(method)
        owner = javaType(info.owner)
        if isSame(class.ptr, info.owner.ptr)
            args = (GenArgInfo(i, info, gen) for i in 1:length(info.argTypes))
            argDecs = (:($(arg.name)::$(arg.juliaType)) for arg in args)
            methodIdName = Symbol("method_" * string(typeName) * "__" * string(name))
            push!(gen.code, :($methodIdName = getmethodid($(isStatic(method)), $classVar, $(string(name)), $(legalClassName(info.returnClass)), $(legalClassName.(info.argClasses)))))
            push!(gen.code, :(function (pxy::JMethodProxy{Symbol($(string(name))), <: $typeName})($(argDecs...))::$(genReturnType(info, gen))
                              $(genConvertResult(info.typeInfo.convertType, info, :(_jcall(getfield(pxy, :obj), $methodIdName, C_NULL, $(info.typeInfo.juliaType), ($(info.argTypes...),), $((argCode(arg) for arg in args)...)))))
                              end))
        end
    end
    push!(gen.code, :(push!(genned, Symbol($(legalClassName(class))))))
end

function genReturnType(methodInfo, gen)
    t = methodInfo.typeInfo.convertType
    if methodInfo.typeInfo.primitive || t <: String || t == Nothing
        t
    else
        :(JProxy{<:$(typeNameFor(javaType(methodInfo.returnType), gen))})
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

isArray(class::JClass) = jcall(class, "isArray", jboolean, ()) != 0

#function JClassInfo(class::JClass; deep=false)
#    if isArray(class)
#        infoFor(objectClass)
#    else
#        gen = GenInfo()
#        genClass(class, gen)
#        if deep
#          while !isempty(gen.deps)
#              cls = pop!(gen.deps)
#              !hasClass(gen, cls) && genClass(classforname(string(cls)), gen)
#          end
#        else
#          while !isempty(gen.deps)
#              cls = pop!(gen.deps)
#              !hasClass(gen, cls) && genType(classforname(string(cls)), gen)
#          end
#        end
#        #println("\nEVALUATING...\n\n")
#        expr = :(begin $(gen.typeCode...); $(gen.code...); $(genClasses(getname.(gen.classList))...); end)
#        println(expr)
#        eval(expr)
#        #for e in expr.args
#        #    println(e)
#        #    eval(e)
#        #end
#        #println("DONE EVALUATING")
#        for cl in gen.classList
#            n = legalClassName(cl)
#            classes[n] = JClassInfo(cl, gen.fielddicts[n], gen.methodSets[n], types[Symbol(n)])
#        end
#        classes[legalClassName(class)]
#    end
#end

function JClassInfo(class::JClass; gen=false, deep=false)
    if isArray(class)
        infoFor(objectClass)
    else
        n = legalClassName(class)
        sc = superclass(class)
        info = classes[n] = JClassInfo(isNull(sc) ? nothing : infoFor(sc), class, fielddict(class), methoddict(class), gettype(Symbol(n)))
        if gen
            genInfo = GenInfo()
            genClass(class, genInfo)
            if deep
                while !isempty(genInfo.deps)
                    cls = pop!(genInfo.deps)
                    !hasClass(genInfo, cls) && genClass(classforname(string(cls)), genInfo)
                end
            else
                while !isempty(genInfo.deps)
                    cls = pop!(genInfo.deps)
                    !hasClass(genInfo, cls) && genType(classforname(string(cls)), genInfo)
                end
            end
            #println("\nEVALUATING...\n\n")
            expr = :(begin $(genInfo.typeCode...); $(genInfo.code...); $(genClasses(getname.(genInfo.classList))...); end)
            for e in expr.args
                println(e)
            #    eval(e)
            end
            #println(expr)
            eval(expr)
            #println("DONE EVALUATING")
            for cl in genInfo.classList
                n = legalClassName(cl)
                classes[n] = JClassInfo(cl, genInfo.fielddicts[n], genInfo.methodSets[n], types[Symbol(n)])
            end
            classes[legalClassName(class)]
        end
        info
    end
end

genClasses(classNames) = (:(gen($name, $(Symbol(typeNameFor(name))))) for name in classNames)

function typeFor(sym::Symbol)
    aType, dims = arrayInfo(string(sym))
    dims != 0 ? Array{types[Symbol(aType)], length(dims)} : types[sym]
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

box(str::AbstractString) = str
box(pxy::JProxy) = pxyObj(pxy)
#function box(array::Array{T,N})
#end
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

methodInfo(class::AbstractString, name::AbstractString, argTypeNames::Array) = methodCache[(class, name, argTypeNames)]
function methodInfo(m::Union{JMethod, JConstructor})
    name, returnType, argTypes = getname(m), getreturntype(m), getparametertypes(m)
    cls = jcall(m, "getDeclaringClass", JClass, ())
    methodKey = (legalClassName(cls), name, legalClassName.(argTypes))
    get!(methodCache, methodKey) do
        methodId = getmethodid(isStatic(m), cls, name, returnType, argTypes)
        typeName = legalClassName(returnType)
        info = get(typeInfo, typeName, genericFieldInfo)
        owner = metaclass(legalClassName(cls))
        id = length(methodCache)
        methodsById[id] = JMethodInfo(id, name, info, juliaTypeFor(returnType), returnType, Tuple(juliaTypeFor.(argTypes)), argTypes, methodId, isStatic(m), owner)
    end
end

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
    classes["java.lang.String"] = JClassInfo(nothing, classforname("java.lang.String"), Dict(), Dict(), types[Symbol("java.lang.String")])
    global sigTypes = Dict([inf.signature => inf for (key, inf) in typeInfo if inf.primitive])
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
        #println("BOX METHOD FOR ", box.boxType)
        #println(expr)
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

function getmethodid(static::Bool, cls::JClass, name::AbstractString, rettype::AbstractString, argtypes::Vector{<:AbstractString})
    getmethodid(static, cls, name, classforlegalname(rettype), collect(JClass, classforlegalname.(argtypes)))
end
function getmethodid(static::Bool, cls::JClass, name::AbstractString, rettype::JClass, argtypes::Vector{JClass})
    sig = proxyMethodSignature(rettype, argtypes)
    jclass = metaclass(legalClassName(cls))
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
               penv, metaclass(legalClassName(cls)), name, proxyClassSignature(string(C)))
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

juliaTypeFor(class::JavaObject) = juliaTypeFor(legalClassName(class))
function juliaTypeFor(name::AbstractString)
    info = get(typeInfo, name, nothing)
    info != nothing ? info.juliaType : JavaObject{Symbol(name)}
end

function infoFor(class::JClass; deep=false)
    name = legalClassName(class)
    haskey(classes, name) ? classes[name] : classes[name] = JClassInfo(class, deep=deep)
end

getname(thing::Union{JClass, JMethod, JField}) = jcall(thing, "getName", JString, ())
getname(thing::JConstructor) = "<init>"

classforlegalname(n::AbstractString) = (i = get(typeInfo, n, nothing)) != nothing && i.primitive ? i.primClass : classforname(n)

classfortype(t::Type{JavaObject{T}}) where T = classforname(string(T))

listfields(cls::AbstractString) = listfields(classforname(cls))
listfields(cls::Type{JavaObject{C}}) where C = listfields(classforname(string(C)))
listfields(cls::JClass) = jcall(cls, "getFields", Vector{JField}, ())

fielddict(class::JClass) = Dict([Symbol(getname(item)) => JFieldInfo(item) for item in listfields(class)])

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

function getField(p::JProxy, name::Symbol, field::JFieldInfo)
    result = ccall(static ? field.info.staticGetter : field.info.getter, Ptr{Nothing},
                   (Ptr{JNIEnv}, Ptr{Nothing}, Ptr{Nothing}),
                   penv, pxyStatic(p) ? getclass(obj) : pxyObj(p).ptr, field.id)
    result == C_NULL && geterror()
    result = (field.info.primitive ? convert(field.info.juliaType, result) : result == C_NULL ? jnull : narrow(JavaObject(JObject, result)))
    asJulia(field.info.juliaType, result)
end

function Base.getproperty(p::JProxy, name::Symbol)
    obj = pxyObj(p)
    info = pxyInfo(p)
    static = pxyStatic(p)
    result = if name in info.methods
        println("MAKING METHOD PROXY")
        JMethodProxy{name, gettype(javaType(obj))}(obj, info.methods[name], static)
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

function (pxy::JMethodProxy)(args...)
    targets = Set(m for m in pxy.methods if fits(m, args))
    if !isempty(targets)
        # Find the most specific method
        meth = reduce(((x, y)-> generality(x, y) < generality(y, x) ? x : y), filterStatic(pxy, targets))
        convertedArgs = convert.(meth.argTypes, args)
        result = _jcall(meth.static ? meth.owner : pxy.receiver, meth.id, C_NULL, meth.typeInfo.juliaType, meth.argTypes, convertedArgs...)
        if !isVoid(meth); asJulia(meth.typeInfo.convertType, result); end
    end
end

function Base.show(io::IO, pxy::JProxy)
    if pxyStatic(pxy)
        print(io, "static class $(legalClassName(JavaObject(pxy)))")
    else
        print(io, pxy.toString())
        #print(io, Java.toString(pxy))
    end
end

JavaObject(pxy::JProxy) = pxyObj(pxy)
