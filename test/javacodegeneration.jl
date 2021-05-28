@testset verbose=true "Test Java Code Generation" begin
    using JavaCall: JavaCodeGeneration

    @testset "Test Simple Object" begin
        eval(JavaCodeGeneration.loadclass(Symbol("java.lang.Object")))
        @test @isdefined JObject
        @test @isdefined JObjectImpl
        @test @isdefined JString
        @test @isdefined JStringImpl
        @test @isdefined equals
        @test @isdefined to_string
    end

    @testset "Test Static Methods" begin
        @testset "Test Arrays" begin
            eval(JavaCodeGeneration.loadclass(Symbol("java.util.Arrays")))
    
            a = [1, 2, 3, 4, 5]
            @test 1 == binary_search(a, 2) # Java Indexes at 0
        end

        @testset "Test Dates" begin
            eval(JavaCodeGeneration.loadclass(Symbol("java.time.LocalDate")))
            a = of(Int32(2000), Int32(1), Int32(1))
            b = plus_days(a, 1)
            c = plus_months(b, 1)
            @test get_year(a) == 2000
            @test get_year(b) == 2000
            @test get_year(c) == 2000
            @test get_month_value(a) == 1
            @test get_month_value(b) == 1
            @test get_month_value(c) == 2
            @test get_day_of_month(a) == 1
            @test get_day_of_month(b) == 2
            @test get_day_of_month(c) == 2
        end
    end
end
