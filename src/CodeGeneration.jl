module CodeGeneration

export generatetype, generatestruct, generateblock, generatemethod, generatemodule

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

# Generate blocks

generateblock(exprs::Expr...) = Expr(:block, exprs...)

# Generate methods

generatemethod(name::Symbol, parameters::Vector{Symbol}, code::Expr) =
    :(function $name($(parameters...))
        $code
    end)

# Generate modules

generatemodule(name::Symbol, exprs::Expr...) =
    :(module $name
        $(exprs...)
    end)

end
