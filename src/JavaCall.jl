module JavaCall

# Include file with all definitions to export
include("exports.jl")

# Include Submodules
# ------------------
include("Utils.jl")
include("CodeGeneration.jl")
include("InitOptions.jl")
include("jni/JNI.jl")
include("JavaVM.jl")
include("Signatures.jl")
include("Conversions.jl")
include("Core.jl")
include("JavaLang.jl")
include("reflection/Reflection.jl")
include("JavaCodeGeneration.jl")
include("JImport.jl")

using .InitOptions
using .JNI
using .JavaVM
using .JImport
using .JavaLang
end
