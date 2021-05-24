module JavaCall

# Include file with all definitions to export
include("exports.jl")

# Include Submodules
# ------------------
include("Utils.jl")
include("CodeGeneration.jl")
include("InitOptions.jl")
include("jni/JNI.jl")
include("Signatures.jl")
include("Conversions.jl")
include("Core.jl")
include("JavaLang.jl")
include("reflection/Reflection.jl")

using .InitOptions
using .JavaLang
end
