@testset verbose=true "Test Java Code Generation" begin
    using JavaCall: JavaCodeGeneration

    @testset "Test Simple Object" begin
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.Object")))
        @test @isdefined JObject
        @test @isdefined JObjectImpl
        @test @isdefined equals
        @test @isdefined to_string
    end
end
