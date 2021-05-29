@testset verbose = true "Test Reflection API" begin
    using JavaCall: Reflection

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
            Reflection.ClassDescriptor(
                C_NULL, 
                :(Vector{Int8}), 
                :jbyteArray, 
                "[B", 
                Reflection.ClassDescriptor(C_NULL, :Int8, :jbyte, "B")
            ), 
            [],
            Reflection.ModifiersDescriptor(false)
        )
        
        # boolean equals(Object)
        equals = Reflection.MethodDescriptor(
            "equals", 
            Reflection.ClassDescriptor(C_NULL, :Bool, :jboolean, "Z"), 
            [Reflection.ClassDescriptor(C_NULL, :JObject, :jobject, "Ljava/lang/Object;")],
            Reflection.ModifiersDescriptor(false)
        )
        
        # static String format(String, Object...)
        format = Reflection.MethodDescriptor(
            "format", 
            Reflection.ClassDescriptor(C_NULL, :JString, :jobject, "Ljava/lang/String;"), 
            [
                Reflection.ClassDescriptor(C_NULL, :JString, :jobject, "Ljava/lang/String;"), 
                Reflection.ClassDescriptor(
                    C_NULL, 
                    :(Vector{JObject}), 
                    :jobjectArray, 
                    "[Ljava/lang/Object;",
                    Reflection.ClassDescriptor(C_NULL, :JObject, :jobject, "Ljava/lang/Object;")    
                )
            ],
            Reflection.ModifiersDescriptor(true)
        )

        # void getChars(int, int, char[], int)
        getchars = Reflection.MethodDescriptor(
            "getChars",
            Reflection.ClassDescriptor(C_NULL, :Nothing, :jvoid, "V"),
            [
                Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I"),
                Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I"),
                Reflection.ClassDescriptor(
                    C_NULL, 
                    :(Vector{Char}), 
                    :jcharArray, 
                    "[C",
                    Reflection.ClassDescriptor(C_NULL, :Char, :jchar, "C")),
                Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I")
            ],
            Reflection.ModifiersDescriptor(false)
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

    @testset "Find Constructors" begin
        constructors = Reflection.classconstructors(Symbol("java.lang.String"))

        @test length(constructors) > 0 
        @test_isa constructors Vector{Reflection.ConstructorDescriptor}

        found_bytes = false
        found_chars = false
        found_string = false
        found_builder = false

        # String(byte[] bytes, int offset, int length, Charset charset)
        bytes = Reflection.ConstructorDescriptor([
            Reflection.ClassDescriptor(
                C_NULL, 
                :(Vector{Int8}), 
                :jbyteArray, 
                "[B", 
                Reflection.ClassDescriptor(C_NULL, :Int8, :jbyte, "B")),
            Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I"),
            Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I"),
            Reflection.ClassDescriptor(C_NULL, :JCharset, :jobject, "Ljava/nio/charset/Charset;")
        ])

        # String(char[] value, int offset, int count)
        chars = Reflection.ConstructorDescriptor([
            Reflection.ClassDescriptor(
                C_NULL, 
                :(Vector{Char}), 
                :jcharArray, 
                "[C", 
                Reflection.ClassDescriptor(C_NULL, :Char, :jchar, "C")),
            Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I"),
            Reflection.ClassDescriptor(C_NULL, :Int32, :jint, "I")
        ])

        # String(String original)
        string = Reflection.ConstructorDescriptor([
            Reflection.ClassDescriptor(C_NULL, :JString, :jobject, "Ljava/lang/String;")
        ])

        # String(StringBuilder builder)
        builder = Reflection.ConstructorDescriptor([
            Reflection.ClassDescriptor(C_NULL, :JStringBuilder, :jobject, "Ljava/lang/StringBuilder;")
        ])

        for c in constructors
            if c == bytes
                found_bytes = true
            elseif c == chars
                found_chars = true
            elseif c == string
                found_string = true
            elseif c == builder
                found_builder = true
            end
        end

        @test found_bytes
        @test found_chars
        @test found_string
        @test found_builder
    end
end
