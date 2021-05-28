module CodeGeneration

export generatetype, generatestruct, generateimport, 
    generateblock, generatemethod, generatemodule

# Generate abstract types

generatetype(name::Symbol) = :(abstract type $name end)
generatetype(name::Symbol, supertype::Symbol) = :(abstract type $name <: $supertype end)

# Generate structs
    
generatestruct(name::Symbol, fields::Vararg{Tuple{Symbol, Symbol}, N}) where {N} = 
    :(struct $name 
        $(map(x -> :($(x[1])::$(x[2])), fields)...) 
    end)

generatestruct(name::Symbol, supertype::Symbol, fields::Vararg{Tuple{Symbol, Symbol}, N}) where {N} = 
    :(struct $name <: $supertype
        $(map(x -> :($(x[1])::$(x[2])), fields)...) 
    end)

# Generate import

generateimport(mod::Expr, ::Vararg{Symbol,0}) = :(import $mod)
generateimport(mod::Expr, objs::Vararg{Symbol,N}) where {N} = :(import $mod: $(objs...))

# Generate blocks

generateblock(exprs::Expr...) = Expr(:block, exprs...)

# Generate methods

const SymbolOrExpr = Union{Expr, Symbol}

function generatemethod(
    name::SymbolOrExpr, 
    parameters::Vector{T}, 
    code::Expr, 
    ::Vararg{SymbolOrExpr, 0}
) where {T <: SymbolOrExpr}

    :(function $name($(parameters...))
        $code
    end)
end

function generatemethod(
    name::SymbolOrExpr, 
    parameters::Vector{T}, 
    code::Expr, 
    whereparams::Vararg{SymbolOrExpr, N}
) where {T <: SymbolOrExpr, N}

    :(function $name($(parameters...)) where {$(whereparams...)}
        $code
    end)
end

# Generate modules

generatemodule(name::Symbol, exprs::Expr...) =
    :(module $name
        $(exprs...)
    end)

end
