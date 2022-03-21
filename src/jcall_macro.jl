macro jcall(expr)
    return jcall_macro_lower(jcall_macro_parse(expr)...)
end

function jcall_macro_lower(func, rettype, types, args, nreq)
    @info "args: " func rettype types args nreq func.head func.args
    obj = func.args[2]
    if obj isa Expr && obj.head == :.
        obj = quote
            jfield($(obj.args[1]), string($(obj.args[2])))
        end
    end
    f = string(func.args[1].value)
    jtypes = Expr(:tuple, types...)
    jret = rettype
    quote
        jcall($(esc(obj)), $f, $jret, $jtypes, $args...)
    end
end

# @jcall implementation, based on Base.@ccall
"""
    jcall_macro_parse(expression)

`jcall_macro_parse` is an implementation detail of `@jcall
it takes an expression like `:(printf("%d"::Cstring, value::Cuint)::Cvoid)`
returns: a tuple of `(function_name, return_type, arg_types, args)`
The above input outputs this:
    (:printf, :Cvoid, [:Cstring, :Cuint], ["%d", :value])
"""
function jcall_macro_parse(expr::Expr)
    # setup and check for errors
    if !Meta.isexpr(expr, :(::))
        throw(ArgumentError("@jcall needs a function signature with a return type"))
    end
    rettype = expr.args[2]

    call = expr.args[1]
    if !Meta.isexpr(call, :call)
        throw(ArgumentError("@jcall has to take a function call"))
    end

    # get the function symbols
    func = let f = call.args[1]
        if Meta.isexpr(f, :.)
            :(($(f.args[2]), $(f.args[1])))
        elseif Meta.isexpr(f, :$)
            f
        elseif f isa Symbol
            QuoteNode(f)
        else
            throw(ArgumentError("@jcall function name must be a symbol, a `.` node (e.g. `libc.printf`) or an interpolated function pointer (with `\$`)"))
        end
    end

    # detect varargs
    varargs = nothing
    argstart = 2
    callargs = call.args
    if length(callargs) >= 2 && Meta.isexpr(callargs[2], :parameters)
        argstart = 3
        varargs = callargs[2].args
    end

    # collect args and types
    args = []
    types = []

    function pusharg!(arg)
        if !Meta.isexpr(arg, :(::))
            throw(ArgumentError("args in @jcall need type annotations. '$arg' doesn't have one."))
        end
        push!(args, arg.args[1])
        push!(types, arg.args[2])
    end

    for i in argstart:length(callargs)
        pusharg!(callargs[i])
    end
    # Do we need this in JavaCall?
    # add any varargs if necessary
    nreq = 0
    if !isnothing(varargs)
        if length(args) == 0
            throw(ArgumentError("C ABI prohibits vararg without one required argument"))
        end
        nreq = length(args)
        for a in varargs
            pusharg!(a)
        end
    end

    return func, rettype, types, args, nreq
end

