
# TODO: remove
using JavaCall
import JavaCall: listmethods, getreturntype


const JAVA_PRIMITIVE_TYPES = Dict(
    :int => jint,
    :long => jlong,
    :byte => jbyte,
    :boolean => jboolean,
    :short => jshort,
    :float => jfloat,
    :double => jdouble
)

function java_type_by_name(name::AbstractString)
    sym_name = Symbol(name)
    if haskey(JAVA_PRIMITIVE_TYPES, sym_name)
        return JAVA_PRIMITIVE_TYPES[sym_name]
    else
        return JavaObject{sym_name}
    end
end


function jcall_macro(ex)
    @assert ex.head == :call && ex.args[1].head == :.
    obj = ex.args[1].args[1]
    method = string(ex.args[1].args[2].value)
    args = ex.args[2:end]
    return quote
        arg_types = map(typeof, $args)
        java_methods = listmethods($obj, $method)
        if length(java_methods) != 1
            error("Expected exactly 1 method for " * string($obj) * "." * string($method) *
                  "but found $(length(java_methods))")
        end
        rettype_name = getname(getreturntype(java_methods[1]))
        rettype = java_type_by_name(rettype_name)
        jcall($obj, $method, rettype, arg_types, $(args...))
    end
end



nominal_class{T}(::Type{JavaObject{T}}) = T   # don't we have something like this already?


method_name_value{M}(::Type{Val{M}}) = string(M)


@generated function jcall_gen(obj, method, args)
    cls = classforname(string(nominal_class(obj)))
    method_name = method_name_value(method)
    java_methods = listmethods(cls, method_name)
    println(java_methods)
    if length(java_methods) != 1
        error("Expected exactly 1 method for $cls.$method_name " *
              "but found $(length(java_methods))")
    end
    rettype_name = getname(getreturntype(java_methods[1]))
    rettype = java_type_by_name(rettype_name)
    arg_type_classes = (getparametertypes(java_methods[1])...,)
    arg_types = ([JavaObject{Symbol(getname(C))} for C in arg_type_classes]...)
    # arg_types = (args...,)
    # println(arg_types)
    return quote
        jcall(obj, $method_name, $rettype, $arg_types, args...)
    end
end




@generated function foo(x)
    println(x)
    return :(x*x)
end




macro jcall(ex)
    jcall_macro(ex)
end



function main_471()
    JavaCall.init()
    obj = JObject(())
    jcall_gen(obj, Val{:equals}(), ["hello"])
    cls = getclass(obj)

    
    ex = :(obj.equals("foo"))

end
