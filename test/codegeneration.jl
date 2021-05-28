

@testset verbose=true "Code Generation" begin
    
    import JavaCall: CodeGeneration
    @testset "Generate abstract types" begin
        eval(CodeGeneration.generatetype(:Type1))
        @test @isdefined Type1

        abstract type SuperType end
        eval(CodeGeneration.generatetype(:ConcreteType1, :SuperType))
        @test @isdefined ConcreteType1
        @test ConcreteType1 <: SuperType

    end

    @testset "Generate structs" begin
        eval(CodeGeneration.generatestruct(:Struct1))
        @test @isdefined Struct1

        abstract type SuperStruct end
        eval(CodeGeneration.generatestruct(:ConcreteStruct1, :SuperStruct))
        @test @isdefined ConcreteStruct1
        @test ConcreteStruct1 <: SuperStruct

        eval(CodeGeneration.generatestruct(:StructWithFields1, (:a,:Int64), (:b,:String)))
        @test @isdefined StructWithFields1
        @test :a in fieldnames(StructWithFields1)
        @test :b in fieldnames(StructWithFields1)
        @test length(StructWithFields1.types) == 2
        @test Int64 in StructWithFields1.types
        @test String in StructWithFields1.types

        eval(CodeGeneration.generatestruct(
            :StructWithFields2, 
            :SuperStruct, 
            (:a, :Int64), 
            (:b, :String)))
        @test @isdefined StructWithFields2
        @test StructWithFields2 <: SuperStruct
        @test :a in fieldnames(StructWithFields2)
        @test :b in fieldnames(StructWithFields2)
        @test length(StructWithFields2.types) == 2
        @test Int64 in StructWithFields2.types
        @test String in StructWithFields2.types
    end

    @testset "Generate block" begin
        exprs = [
            :(a = 1),
            :(b = 2),
            :(a = a + 1),
            :(b += a),
            :(a, b)
        ]
        block = CodeGeneration.generateblock(exprs...)
        @test block == Expr(:block, exprs...)
        @test eval(block) == (2, 4)
    end

    @testset "Generate method" begin
        @testset "Generate simple method" begin
            name = :method
            params = [:a, :b]
            body = [
                :(a = a + 1),
                :(b += a),
                :(a, b)
            ]
            eval(CodeGeneration.generatemethod(name, params, Expr(:block, body...)))
            @test method(1, 2) == (2, 4)
        end

        @testset "Generate method with types" begin
            name = :method
            params = [:(a::Int64), :(b::Int64)]
            body = [
                :(a = a + 1),
                :(b += a),
                :(a, b)
            ]
            eval(CodeGeneration.generatemethod(name, params, Expr(:block, body...)))
            @test method(1, 2) == (2, 4)
        end

        @testset "Generate method with parametric types" begin
            name = :method
            params = [:(a::T), :(b::N)]
            body = [
                :(a = a + 1),
                :(b += a),
                :(a, b)
            ]
            whereparams = [:(T <: Int64), :(N <: Int64)]
            eval(CodeGeneration.generatemethod(
                name, 
                params, 
                Expr(:block, body...),
                whereparams...))
            @test method(1, 2) == (2, 4)
        end
    end

    @testset "Generate module" begin
        eval(CodeGeneration.generatemodule(:Module1))
        @test @isdefined Module1

        modulevars = [
            :(a = 1),
            :(b = a + 1),
            :(customadd(a, b) = a + b),
            :(c = customadd(a, b)),
            :(struct ModuleStruct a::Int64 end),
            :(d = ModuleStruct(5))
        ]
        eval(CodeGeneration.generatemodule(:Module2, modulevars...))
        @test @isdefined Module2
        @test (Module2.a, Module2.b, Module2.c) == (1, 2, 3)
        @test Module2.customadd(3, 4) == 7
        @test isdefined(Module2, :ModuleStruct)
        @test Module2.d.a == 5
        @test Module2.d == Module2.ModuleStruct(5)
    end
end
