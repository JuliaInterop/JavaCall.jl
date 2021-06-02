@testset verbose = true "Tests for exceptions" begin

    using JavaCall.JNI
    using JavaCall: JavaCodeGeneration, JavaLang

    @testset "Integer Parsing Exception" begin
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.Integer")))
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.String")))

        invalidnumber = JString(Char['1', '!', '3'])

        @test_throws JNumberFormatExceptionJuliaImpl j_parse_int(JInteger, invalidnumber)
        @test_throws JNumberFormatException j_parse_int(JInteger, invalidnumber)
        @test_throws JRuntimeException j_parse_int(JInteger, invalidnumber)

        try
            j_parse_int(JInteger, invalidnumber)
        catch e
            @test isa(e, JNumberFormatException)
            @test isa(e, JThrowable)
            @test j_length(j_get_message(e)) > 0
        end
    end
end
