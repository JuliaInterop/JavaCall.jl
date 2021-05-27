module JavaCodeGeneration

using JavaCall.CodeGeneration
using JavaCall.Reflection
using JavaCall.Utils

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
        result = callinstancemethod(
            $(classdescriptor.jnitype),
            $(QuoteNode(Symbol(methoddescriptor.name))),
            $(methoddescriptor.rettype.jnitype),
            $signature,
            args...)
        convert_to_julia($(methoddescriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol(snakecase_from_camelcase(methoddescriptor.name)),
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
        receiverdescriptor.signature,
        map(x->x.signature, descriptor.paramtypes)...,
        ')',
        descriptor.rettype.signature)
    
    body = quote
        obj = convert_to_jni(jobject, receiver)
        args = jvalue[]
        $(map(generateconvertarg, enumerate(descriptor.paramtypes))...)
        result = callinstancemethod(
            obj, 
            $(Symbol(descriptor.name)), 
            $(descriptor.rettype.jnitype),
            $signature,
            args...)
            convert_to_julia($(descriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol(snakecase_from_camelcase(descriptor.name)),
        paramtypes,
        body)
end

function loadclass(classname::Symbol)
    classdescriptor = findclass(classname)
    typeid = classdescriptor.juliatype
    structid = structidfromtypeid(typeid)
    generateblock(
        generatetype(typeid),
        generatestruct(structid, typeid, (:ref, :jobject)),
        generatemethod(:(JavaCall.Conversions.convert_to_julia), [:(::Type{$typeid}), :(x::jobject)], :($structid(x))),
        generatemethod(:(JavaCall.Conversions.convert_to_jni), [:(::Type{jobject}), :(x::$typeid)], :(x.ref)),
        map(x -> methodfromdescriptors(classdescriptor, x), classmethods(classdescriptor))...
    )
end

end
