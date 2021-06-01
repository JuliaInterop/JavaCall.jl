@testset verbose=true "Test import statements" begin
    using JavaCall
    using JavaCall.JImport

    @testset "Import Float" begin
        @jimport "java.lang.Float"
        @test @isdefined JFloat
        @test @isdefined JFloatJuliaImpl

        a = JFloat(Float32(2.2))
        b = JFloat(Float32(2.2))
        @test a == b
    end
end
