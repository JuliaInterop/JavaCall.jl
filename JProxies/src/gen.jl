# This code is not used yet
# It was moved from the work-in-progress code in proxy.jl

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
    juliaType
    spec
end

const genned = Set()

hasClass(name::AbstractString) = hasClass(Symbol(name))
hasClass(name::Symbol) = name in genned
hasClass(gen, name::AbstractString) = hasClass(gen, Symbol(name))
hasClass(gen, name::Symbol) = name in genned || haskey(gen.methodDicts, string(name))

function genTypeDecl(name::AbstractString, supername::Symbol, gen)
    if string(name) != "String" && !haskey(types, Symbol(name)) && !haskey(gen.methodDicts, name)
        typeName = typeNameFor(name)
        push!(gen.typeCode, :(abstract type $typeName <: $supername end))
    end
end

function registerclass(name::AbstractString, classType::Type)
    registerclass(Symbol(name), classType)
end
function registerclass(name::Symbol, classType::Type)
    if !(classType <: Union{Array, String}) && !haskey(types, name)
        types[name] = classType
    end
    infoFor(classforname(string(name)))
end

gen(name::Symbol; genmode=:none, print=false, eval=true) = _gen(classforname(string(name)), genmode, print, eval)
gen(name::AbstractString; genmode=:none, print=false, eval=true) = _gen(classforname(name), genmode, print, eval)
gen(pxy::JProxy{T, C}) where {T, C} = gen(C)
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
        genTypeDecl(name, cType, gen)
    else
        genTypeDecl(name, :java_lang, gen)
    end
end

genClass(class::JClass, gen::GenInfo) = genClass(class, gen, infoFor(class))
function genClass(class::JClass, gen::GenInfo, info::JClassInfo)
    name = getname(class)
    if !(Symbol(name) in genned)
        gen.fielddicts[legalClassName(class)] = fielddict(class)
        push!(gen.classList, class)
        sc = superclass(class)
        #@verbose("SUPERCLASS OF $name is $(isNull(sc) ? "" : "not ")null")
        push!(genned, Symbol(legalClassName(class)))
        if !isNull(sc)
            supertype = typeNameFor(sc)
            cType = componentType(supertype)
            !hasClass(gen, cType) && genClass(sc, gen)
            genTypeDecl(name, cType, gen)
        else
            genTypeDecl(name, :java_lang, gen)
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
argType(::Type{JavaObject{Symbol("java.lang.Object")}}, gen) = :JLegalArg
argType(::Type{<: Number}, gen) = Number
argType(typ::Type{JavaObject{T}}, gen) where T = :(JProxy{<:$(typeNameFor(T, gen)), T})

argSpec(t, gen) = t
argSpec(::Type{JavaObject{Symbol("java.lang.String")}}, gen) = String
argSpec(::Type{JavaObject{Symbol("java.lang.Object")}}, gen) = :JObject
argSpec(::Type{<: Number}, gen) = Number
argSpec(typ::Type{JavaObject{T}}, gen) where T = :(JProxy{<:$(typeNameFor(T, gen)), T})
argSpec(arg::GenArgInfo) = arg.spec

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

function argCode(arg::GenArgInfo)
    argname = arg.name
    if arg.juliaType == String
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
                                      @verbose($("Generated method $name$(multiple ? "(" * string(symId) * ")" : "")"))
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
genConvertResult(toType::Type{<:JBoxTypes}, info, expr) = :(unbox($(toType.parameters[1]), $expr))
function genConvertResult(toType, info, expr)
    if isVoid(info) || info.typeInfo.primitive
        expr
    else
        :(asJulia($toType, $expr))
    end
end

genClasses(classNames) = (:(registerclass($name, $(Symbol(typeNameFor(name))))) for name in reverse(classNames))

