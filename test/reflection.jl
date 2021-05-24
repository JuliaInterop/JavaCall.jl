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
        class = Reflection.findclass(Symbol("java.lang.Integer"))
        @test class.juliatype == :JInteger
        @test class.jnitype == :jobject
        @test class.signature == "Ljava/lang/Integer;"
    end

    @testset "Find methods" begin
        methods = Reflection.classmethods(Symbol("java.lang.String"))
        @test length(methods) > 0
        @test_isa methods Vector{Reflection.MethodDescriptor}

        found_getbytes = false
        found_equals = false
        found_format = false
        found_getchars = false

        # byte[] getBytes()
        getbytes = Reflection.MethodDescriptor(
            "getBytes", 
            Reflection.ClassDescriptor(C_NULL, :(Vector{Int8}), :jbyteArray, "[B"), 
            [])
        
        # boolean equals(Object)
        equals = Reflection.MethodDescriptor(
            "equals", 
            Reflection.ClassDescriptor(C_NULL, :Bool, :jboolean, "Z"), 
            [Reflection.ClassDescriptor(C_NULL, :JObject, :jobject, "Ljava/lang/Object;")]
        )
        
        # static String format(String, Object...)
        format = Reflection.MethodDescriptor(
            "format", 
            Reflection.ClassDescriptor(C_NULL, :JString, :jobject, "Ljava/lang/String;"), 
            [
                Reflection.ClassDescriptor(C_NULL, :JString, :jobject, "Ljava/lang/String;"), 
                Reflection.ClassDescriptor(C_NULL, :(Vector{JObject}), :jobjectArray, "[Ljava/lang/Object;")
            ]
        )

        # void getChars(int, int, char[], int)
        getchars = Reflection.MethodDescriptor(
            "getChars",
            Reflection.ClassDescriptor(C_NULL, :Nothing, :jvoid, "V"),
            [
                Reflection.ClassDescriptor(C_NULL, :Int64, :jint, "I"),
                Reflection.ClassDescriptor(C_NULL, :Int64, :jint, "I"),
                Reflection.ClassDescriptor(C_NULL, :(Vector{Char}), :jcharArray, "[C"),
                Reflection.ClassDescriptor(C_NULL, :Int64, :jint, "I")
            ]
        )

        for m in methods
            if getbytes == m
                found_getbytes = true
            elseif equals == m
                found_equals = true
            elseif format == m
                found_format = true
            elseif getchars == m
                found_getchars = true
            end
        end
        @test found_getbytes
        @test found_equals
        @test found_format
        @test found_getchars
    end
end
