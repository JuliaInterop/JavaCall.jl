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

    function jni_newstring(vector::Vector{Char})
        JNI.new_string(map(JNI.jchar, vector), length(vector))
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
        @test length(methods) > 0
        @test_isa methods Vector{Reflection.MethodDescriptor}

        found_getbytes = false
        found_equals = false
        found_format = false

        # byte[] getBytes()
        getbytes = Reflection.MethodDescriptor("getBytes", Vector{JNI.jbyte}, [])
        
        # boolean equals(Object)
        equals = Reflection.MethodDescriptor("equals", jboolean, [Symbol("java.lang.Object")])
        
        # static String format(String, Object...)
        format = Reflection.MethodDescriptor(
            "format", 
            Symbol("java.lang.String"), 
            [Symbol("java.lang.String"), Vector{Symbol("java.lang.Object")}]
        )

        for m in methods
            if getbytes == m
                found_getbytes = true
            elseif equals == m
                found_equals = true
            elseif format == m
                found_format = true
            end
        end
        @test found_getbytes
        @test found_equals
        @test found_format
    end
end
