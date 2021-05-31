@testset verbose=true "Test Java Code Generation" begin
    using JavaCall: JavaCodeGeneration

    @testset "Test Simple Object" begin
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.Object")))
        @test @isdefined JObject
        @test @isdefined JObjectImpl
        @test @isdefined JString
        @test @isdefined JStringImpl
        @test @isdefined JObject_equals
        @test @isdefined JObject_to_string
    end

    @testset "Test Static Methods" begin
        @testset "Test Arrays" begin
            eval(JavaCodeGeneration.loadclass(Symbol("java.util.Arrays")))
    
            a = [1, 2, 3, 4, 5]
            @test 1 == JArrays_binary_search(a, 2) # Java Indexes at 0
        end

        @testset "Test Dates" begin
            eval(JavaCodeGeneration.loadclass(Symbol("java.time.LocalDate")))
            a = JLocalDate_of(Int32(2000), Int32(1), Int32(1))
            b = JLocalDate_plus_days(a, 1)
            c = JLocalDate_plus_months(b, 1)
            @test JLocalDate_get_year(a) == 2000
            @test JLocalDate_get_year(b) == 2000
            @test JLocalDate_get_year(c) == 2000
            @test JLocalDate_get_month_value(a) == 1
            @test JLocalDate_get_month_value(b) == 1
            @test JLocalDate_get_month_value(c) == 2
            @test JLocalDate_get_day_of_month(a) == 1
            @test JLocalDate_get_day_of_month(b) == 2
            @test JLocalDate_get_day_of_month(c) == 2
        end
    end

    @testset "Test Constructors" begin
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.String")))

        hellochars = ['H', 'e', 'l', 'l', 'o']
        hello1 = JString(hellochars)
        hello2 = JString(hello1)
        
        @test JString_length(hello1) == 5
        @test JString_length(hello2) == 5

        for (i, c) in enumerate(hellochars)
            @test JString_char_at(hello1, Int32(i-1)) == c
            @test JString_char_at(hello2, Int32(i-1)) == c
        end

        helloworldchars = ['H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd']
        
        finalworld = JString(helloworldchars, Int32(5), Int32(6))

        helloworld = JString_concat(hello1, finalworld)
        for (i, c) in enumerate(helloworldchars)
            @test JString_char_at(helloworld, Int32(i-1)) == c
        end

        @test JString_equals(hello1, hello2)
        @test_false JString_equals(hello1, helloworld)
        @test hello1 == hello2
        @test hello1 != helloworld
    end

    @testset "Test Load Superclass" begin
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.Integer")))
        @test @isdefined JInteger
        @test @isdefined JIntegerImpl
        @test @isdefined JNumber
        @test @isdefined JNumberImpl

        a = JInteger(Int32(1))
        b = JInteger(Int32(1))
        @test 1 == JNumber_long_value(a)
        @test a == b
    end
end
