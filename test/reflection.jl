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
        @test_not_cnull methods
        @test_isa methods JNI.jobjectArray

        found_getbytes = false

        getname_id = jni_getmethodid(
            jni_findclass("java/lang/reflect/Method"),
            "getName",
            "()Ljava/lang/String;")
        equals_id = jni_getmethodid(
            jni_findclass("java/lang/String"),
            "equals",
            "(Ljava/lang/Object;)Z"
        )

        expected_name = jni_newstring(['g', 'e', 't', 'B', 'y', 't', 'e', 's'])

        num_methods = JNI.get_array_length(methods)
        for i in 1:num_methods
            m = JNI.get_object_array_element(methods, i-1)
            m_name = JNI.call_object_method_a(m, getname_id, JNI.jvalue[])
            if JNI.call_boolean_method_a(m_name, equals_id, JNI.jvalue[expected_name]) == true
                found_getbytes = true
            end
        end
        @test found_getbytes
    end
end
