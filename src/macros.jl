
# TODO: remove
using JavaCall
import JavaCall: listmethods, getreturntype


function java_type_by_name(name::AbstractSting)
    # if 
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
        rettype = getreturntype(java_methods[1])
        jcall($obj, $method, rettype, arg_types, $(args...))        
    end
end



macro jcall(ex)
    jcall_macro(ex)
end



function main_471()
    JavaCall.init()
    obj = JObject(())    
    ex = :(obj.equals("foo"))

end
