module Reflection

export 
    # Classes.jl
    findclass, isarray, superclass, ClassDescriptor,
    # Modifiers.jl
    ModifiersDescriptor,
    # Methods.jl
    classmethods, classdeclaredmethods,
    isstatic, ispublic, MethodDescriptor,
    # Constructors.jl
    classconstructors, ConstructorDescriptor

include("Classes.jl")
include("Modifiers.jl")
include("Methods.jl")
include("Constructors.jl")

using .Classes
using .Modifiers
using .Methods
using .Constructors

end
