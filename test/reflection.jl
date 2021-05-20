@testset verbose = true "Test Reflection API" begin
    using JavaCall: Reflection
    using JavaCall: JNI

    function jni_findclass(name::String)
        class = JNI.find_class(name)
        @test_not_cnull class
        @test_isa class JNI.jclass
        class
    end

    function jni_getmethodid(class::JNI.jclass, name::String, signature::String)::JNI.jmethodID
        method = JNI.get_method_id(class, name, signature)
        @test_not_cnull method
        @test_isa method JNI.jmethodID
        method
    end

    @testset "Find class" begin
        class = Reflection.findclass(Symbol("java.lang.String"))
        @test_not_cnull class
        @test_isa class JNI.jclass
        @test unsafe_load(class) == unsafe_load(jni_findclass("java/lang/String"))
    end

    @testset "Find meta class" begin
        class = Reflection.findmetaclass(Symbol("java.lang.String"))
        @test_not_cnull class
        @test_isa class JNI.jclass
    end

    @testset "Find methods" begin
        methods = Reflection.classmethods(Symbol("java.lang.String"))
        @test_not_cnull methods
        @test_isa methods JNI.jobjectArray
    end
end
