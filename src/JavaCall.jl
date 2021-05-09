module JavaCall

# Include file with all definitions to export
include("exports.jl")

# Include Submodules
# ------------------
include("IteratorUtils.jl")
include("InitOptions.jl")
include("jni/JNI.jl")

using .InitOptions
end
