@testset verbose = true "Test Java Lang" begin
    
    using JavaCall: JavaLang

    @testset "String Operations" begin
        s1 = JavaLang.new_string("Hello")
        @test_not_cnull s1.ref
        s2 = JavaLang.new_string("Hello")
        @test_not_cnull s2.ref
        @test JavaLang.equals(s1, s2)

        s3 = JavaLang.new_string("Bye")
        @test_not_cnull s3.ref
        @test_false JavaLang.equals(s1, s3)
    end
end
