module Reflection

export 
    # Classes.jl
    findclass, findmetaclass,
    # Methods.jl
    classmethods, MethodDescriptor

include("Classes.jl")
include("Methods.jl")

using .Classes
using .Methods

end
