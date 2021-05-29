module Reflection

export 
    # Classes.jl
    findclass, isarray, ClassDescriptor,
    # Modifiers.jl
    ModifiersDescriptor,
    # Methods.jl
    classmethods, isstatic, MethodDescriptor

include("Classes.jl")
include("Modifiers.jl")
include("Methods.jl")

using .Classes
using .Modifiers
using .Methods

end
