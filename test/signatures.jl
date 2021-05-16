@testset verbose=true "Test Signatures" begin
    using JavaCall.Signatures
    using JavaCall.JNI

    OBJECT_SYM = Symbol("java.lang.Object")
    STRING_SYM = Symbol("java.lang.String")

    @testset "Primitive from Types" begin
        @test signature(jboolean) == "Z"
        @test signature(jbyte) == "B"
        @test signature(jchar) == "C"
        @test signature(jshort) == "S"
        @test signature(jint) == "I"
        @test signature(jlong) == "J"
        @test signature(jfloat) == "F"
        @test signature(jdouble) == "D"
        @test signature(jvoid) == "V"
    end

    @testset "Primitive Arrays from Types" begin
        @test signature(Vector{jboolean}) == "[Z"
        @test signature(Matrix{jbyte}) == "[[B"
        @test signature(Array{jvoid, 4}) == "[[[[V"
        @test signature(Array{jint, 0}) == "I"
    end

    @testset "Objects from Symbols" begin
        @test signature(OBJECT_SYM) == "Ljava/lang/Object;"
        @test signature(Vector{OBJECT_SYM}) == "[Ljava/lang/Object;"
        @test signature(Array{OBJECT_SYM, 4}) == "[[[[Ljava/lang/Object;"
    end

    @testset "Primitive Method Signatures" begin
        @test signature(MethodSignature(jboolean, [])) == "()Z"
        @test signature(MethodSignature(jchar, [jint, jdouble])) == "(ID)C"
        @test signature(MethodSignature(jshort, [jlong, jfloat, Vector{jdouble}])) == "(JF[D)S"
    end

    @testset "Object Method Signatures" begin
        @test signature(MethodSignature(jvoid, [OBJECT_SYM])) == "(Ljava/lang/Object;)V"
        @test signature(MethodSignature(jvoid, [Vector{OBJECT_SYM}])) == "([Ljava/lang/Object;)V"
        @test signature(MethodSignature(STRING_SYM, [OBJECT_SYM, Vector{STRING_SYM}])) == 
            "(Ljava/lang/Object;[Ljava/lang/String;)Ljava/lang/String;"
    end
end
