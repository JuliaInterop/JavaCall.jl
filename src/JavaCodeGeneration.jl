module JavaCodeGeneration

using Core: print
export loadclass

using Base.Iterators

using JavaCall.CodeGeneration
using JavaCall.Reflection
using JavaCall.Utils

using JavaCall.JNI

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

structidfromtypeid(typeid::Symbol) = Symbol(typeid, "JuliaImpl")

paramnamefromindex(i::Int64) = Symbol("param", i)

paramexprfromtuple(x::Tuple{Int64, ClassDescriptor}) = :($(paramnamefromindex(x[1]))::$(x[2].juliatype)) 

function generateconvertarg(x::Tuple{Int64, ClassDescriptor})
    :(push!(args, JavaCall.Conversions.convert_to_jni($(x[2].jnitype), $(paramnamefromindex(x[1])))))
end

function loadclassfromobject(object::jobject)
    class = JNI.get_object_class(object)
    loadclass(Reflection.descriptorfromclass(class))
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

        $(generateexceptionhandling())

        if isa(result, jobject)
            eval(JavaCall.JavaCodeGeneration.loadclassfromobject(result))
        end
        JavaCall.Conversions.convert_to_julia($(methoddescriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol("j_", snakecase_from_camelcase(methoddescriptor.name)),
        [:(::Type{$(classdescriptor.juliatype)}), paramtypes...],
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
        obj = JavaCall.Conversions.convert_to_jni(jobject, receiver)
        args = jvalue[]
        $(map(generateconvertarg, enumerate(descriptor.paramtypes))...)
        result = JavaCall.Core.callinstancemethod(
            obj, 
            $(QuoteNode(Symbol(descriptor.name))), 
            $(descriptor.rettype.jnitype),
            $signature,
            args...)

        $(generateexceptionhandling())

        if isa(result, jobject)
            eval(JavaCall.JavaCodeGeneration.loadclassfromobject(result))
        end
        JavaCall.Conversions.convert_to_julia($(descriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol("j_", snakecase_from_camelcase(descriptor.name)),
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
        JavaCall.Conversions.convert_to_julia($(classdescriptor.juliatype), result)
    end
    generatemethod(
        classdescriptor.juliatype,
        paramtypes,
        body)
end

loadclass(classname::Symbol, shallow=false) = loadclass(findclass(classname), shallow)

function loadclass(classdescriptor::ClassDescriptor, shallow=false)
    if isarray(classdescriptor)
        return generateblock(loadclass(classdescriptor.component, true))
    end

    exprstoeval = []
    
    if !shallowcomponentsloeaded(classdescriptor)
        loadshallowcomponents!(exprstoeval, classdescriptor)
    end

    if !shallow && !fullcomponentsloaded(classdescriptor)
        loadfullcomponents!(exprstoeval, classdescriptor)
    end

    generateblock(exprstoeval...)
end

## Loading of shallow components (minimal components required for the code to function)

shallowcomponentsloeaded(d::ClassDescriptor) = d.juliatype in SHALLOW_LOADED_SYMBOLS

function loadshallowcomponents!(exprstoeval, classdescriptor)
    loadtype!(exprstoeval, classdescriptor)
    loadstruct!(exprstoeval, classdescriptor)
    loadconversions!(exprstoeval, classdescriptor)
    push!(SHALLOW_LOADED_SYMBOLS, classdescriptor.juliatype)
end

function loadtype!(exprstoeval, classdescriptor)
    typeid = classdescriptor.juliatype
    
    if !isinterface(classdescriptor) &&
        superclass(classdescriptor) !== nothing

        loadshallowcomponents!(exprstoeval, superclass(classdescriptor))
        push!(exprstoeval, generatetype(typeid, superclass(classdescriptor).juliatype))
    else
        push!(exprstoeval, generatetype(typeid))
    end
end

function loadstruct!(exprstoeval, classdescriptor)
    typeid = classdescriptor.juliatype
    structid = structidfromtypeid(typeid)
    push!(exprstoeval, generatestruct(structid, typeid, (:ref, :jobject)))
end

function loadconversions!(exprstoeval, classdescriptor)
    typeid = classdescriptor.juliatype
    structid = structidfromtypeid(typeid)
    push!(
        exprstoeval,
        generatemethod(
            :(JavaCall.Conversions.convert_to_julia), 
            [:(::Type{$typeid}), :(x::jobject)], 
            :($structid(x))
        ),
        generatemethod(
            :(JavaCall.Conversions.convert_to_jni),
            [:(::Type{jobject}), :(x::$typeid)], 
            :(x.ref)
        )
    )
end

## Loading of full components (fully generate the code for the class 
## such as methods and constructors)

fullcomponentsloaded(d::ClassDescriptor) = d.juliatype in FULLY_LOADED_SYMBOLS

function loadfullcomponents!(exprstoeval, class::ClassDescriptor)
    loadsuperclass!(exprstoeval, class)
    methods = classdeclaredmethods(class)
    constructors = classconstructors(class)
    loaddependencies!(exprstoeval, methods)
    loaddependencies!(exprstoeval, constructors)
    loadmethods!(exprstoeval, class, methods)
    loadconstructors!(exprstoeval, class, constructors)
    loadjuliamethods!(exprstoeval, class)
    push!(FULLY_LOADED_SYMBOLS, class.juliatype)
end

function loadsuperclass!(exprstoeval, class)
    if !isinterface(class) && superclass(class) !== nothing
        push!(exprstoeval, loadclass(superclass(class)))
    end
end

function loaddependencies!(exprstoeval, methods::Vector{MethodDescriptor})
    dependencies = 
        flatmap(m -> [m.rettype, m.paramtypes...], methods) |>
        l -> map(x -> loadclass(x, true), l)
    
    push!(exprstoeval, dependencies...)
end

function loaddependencies!(exprstoeval, constructors::Vector{ConstructorDescriptor})
    dependencies = 
        flatmap(c -> c.paramtypes, constructors) |>
        l -> map(x -> loadclass(x, true), l)
    
    push!(exprstoeval, dependencies...)
end

function loadmethods!(exprstoeval, class, methods)
    push!(exprstoeval, map(x -> methodfromdescriptors(class, x), methods)...)
end

function loadconstructors!(exprstoeval, class, constructors)
    push!(exprstoeval, map(x -> constructorfromdescriptors(class, x), constructors)...)
end

function loadjuliamethods!(exprstoeval, class)
    typeid = class.juliatype
    push!(
        exprstoeval,
        # generatemethod(
        #     :(Base.show), 
        #     [:(io::IO), :(o::$typeid)],
        #     :(print(io, JavaCall.Conversions.convert_to_string(String, j_to_string(o).ref)))),
        generatemethod(
            :(Base.:(==)),
            [:(o1::$typeid), :(o2::$typeid)],
            :(j_equals(o1, o2))
        )
    )
end

function generateexceptionhandling()
    quote
        if JNI.exception_check() === JNI_TRUE
            exception = JNI.exception_occurred()
            class = JNI.get_object_class(exception)
            desc = JavaCall.Reflection.descriptorfromclass(class)
            eval(JavaCall.JavaCodeGeneration.loadclass(desc))
            JNI.exception_clear()
            throw(eval(quote
                JavaCall.Conversions.convert_to_julia(
                    $(desc.juliatype),
                    $exception
                )
                end
            ))
        end
    end
end

end
