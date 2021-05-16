include("setup.jl")
# Configuration file for test variables
# Not synched to github as each environment can have different configurations
# See baseconfig.jl to see the expected variables
include("config.jl")

@testset verbose=true "JavaCall" begin
    # Test init options
    @info "Testing init opts"
    include("initopts.jl")

    # Test jni api
    @info "Testing JNI API"
    include("jni.jl")

    # Test signatures
    @info "Test signatures"
    include("signatures.jl")
end
