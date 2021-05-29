module JavaCodeGeneration

using JavaCall.CodeGeneration
using JavaCall.Reflection
using JavaCall.Utils

const SHALLOW_LOADED_SYMBOLS = Set([
    :Bool, 
    :Int8, 
    :Char,
    :Int16,
    :Int32,
    :Int64,
    :Float32,
    :Float64,
    :Nothing
])

const FULLY_LOADED_SYMBOLS = copy(SHALLOW_LOADED_SYMBOLS)

structidfromtypeid(typeid::Symbol) = Symbol(typeid, "Impl")

paramnamefromindex(i::Int64) = Symbol("param", i)

paramexprfromtuple(x::Tuple{Int64, ClassDescriptor}) = :($(paramnamefromindex(x[1]))::$(x[2].juliatype)) 

function generateconvertarg(x::Tuple{Int64, ClassDescriptor})
    :(push!(args, convert_to_jni($(x[2].jnitype), $(paramnamefromindex(x[1])))))
end

function methodfromdescriptors(
    classdescriptor::ClassDescriptor,
    methoddescriptor::MethodDescriptor
)   
    methodfromdescriptors(
        Val(isstatic(methoddescriptor)),
        classdescriptor,
        methoddescriptor
    )
end

function methodfromdescriptors(
    ::Val{true},
    classdescriptor::ClassDescriptor,
    methoddescriptor::MethodDescriptor
)   
    paramtypes = map(paramexprfromtuple, enumerate(methoddescriptor.paramtypes))
    signature = string(
        '(',
        map(x->x.signature, methoddescriptor.paramtypes)...,
        ')',
        methoddescriptor.rettype.signature)
    body = quote
        args = jvalue[]
        $(map(generateconvertarg, enumerate(methoddescriptor.paramtypes))...)
        result = JavaCall.Core.callstaticmethod(
            $(classdescriptor.jniclass),
            $(QuoteNode(Symbol(methoddescriptor.name))),
            $(methoddescriptor.rettype.jnitype),
            $signature,
            args...)
        convert_to_julia($(methoddescriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol(classdescriptor.juliatype, "_", snakecase_from_camelcase(methoddescriptor.name)),
        paramtypes,
        body)
end

function methodfromdescriptors(
    ::Val{false},
    receiverdescriptor::ClassDescriptor,
    descriptor::MethodDescriptor
)
    paramtypes = map(paramexprfromtuple, enumerate(descriptor.paramtypes))
    pushfirst!(paramtypes, :(receiver::$(receiverdescriptor.juliatype)))
    signature = string(
        '(',
        map(x->x.signature, descriptor.paramtypes)...,
        ')',
        descriptor.rettype.signature)
    
    body = quote
        obj = convert_to_jni(jobject, receiver)
        args = jvalue[]
        $(map(generateconvertarg, enumerate(descriptor.paramtypes))...)
        result = JavaCall.Core.callinstancemethod(
            obj, 
            $(QuoteNode(Symbol(descriptor.name))), 
            $(descriptor.rettype.jnitype),
            $signature,
            args...)
            convert_to_julia($(descriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol(receiverdescriptor.juliatype, "_", snakecase_from_camelcase(descriptor.name)),
        paramtypes,
        body)
end

function constructorfromdescriptors(
    classdescriptor::ClassDescriptor,
    constructordescriptor::ConstructorDescriptor
)
    paramtypes = map(paramexprfromtuple, enumerate(constructordescriptor.paramtypes))
    # As specified in the JNI reference object contructor methods signatures
    # should return void(V)
    signature = string(
        '(',
        map(x->x.signature, constructordescriptor.paramtypes)...,
        ")V")
    body = quote
        args = jvalue[]
        $(map(generateconvertarg, enumerate(constructordescriptor.paramtypes))...)
        result = JavaCall.Core.callconstructor(
            $(classdescriptor.jniclass),
            $signature,
            args...)
        convert_to_julia($(classdescriptor.juliatype), result)
    end
    generatemethod(
        classdescriptor.juliatype,
        paramtypes,
        body)
end

loadclass(classname::Symbol, shallow=false) = loadclass(findclass(classname), shallow)

function loadclass(classdescriptor::ClassDescriptor, shallow=false)
    exprstoeval = []
    typeid = classdescriptor.juliatype

    if isarray(classdescriptor)
        return generateblock(loadclass(classdescriptor.component, true))
    end

    structid = structidfromtypeid(typeid)
    
    if !(typeid in SHALLOW_LOADED_SYMBOLS)
        push!(
            exprstoeval, 
            generatetype(typeid),
            generatestruct(structid, typeid, (:ref, :jobject)),
            generatemethod(:(JavaCall.Conversions.convert_to_julia), [:(::Type{$typeid}), :(x::jobject)], :($structid(x))),
            generatemethod(:(JavaCall.Conversions.convert_to_jni), [:(::Type{jobject}), :(x::$typeid)], :(x.ref))
        )
        push!(SHALLOW_LOADED_SYMBOLS, typeid)
    end

    if !shallow && !(typeid in FULLY_LOADED_SYMBOLS)
        methoddescriptors = classmethods(classdescriptor)
        constructordescriptors = classconstructors(classdescriptor)
        shallowtypes = collect(flatmap(m -> [m.rettype, m.paramtypes...], methoddescriptors))
        push!(shallowtypes, flatmap(c -> c.paramtypes, constructordescriptors)...)
        push!(
            exprstoeval,
            map(x -> loadclass(x, true), shallowtypes)...
        )
        to_string_fn = Symbol(typeid, "_to_string")
        push!(
            exprstoeval,
            generatemethod(
                :(Base.show), 
                [:(io::IO), :(o::$typeid)],
                :(print(io, JavaCall.Conversions.convert_to_string(String, $to_string_fn(o).ref)))),
            map(x -> methodfromdescriptors(classdescriptor, x), methoddescriptors)...,
            map(x -> constructorfromdescriptors(classdescriptor, x), constructordescriptors)...
        )
        push!(FULLY_LOADED_SYMBOLS, typeid)
    end

    generateblock(exprstoeval...)
end

end
