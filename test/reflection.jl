@testset verbose = true "Test Reflection API" begin
    using JavaCall: Reflection

    @testset "Find class" begin
        @testset "Object Class" begin
            expected = Reflection.ClassDescriptor(
                C_NULL,
                :JObject,
                :jobject,
                "Ljava/lang/Object;"
            )
            objclass = Reflection.findclass(Symbol("java.lang.Object"))

            @test objclass == expected
            @test Reflection.superclass(objclass) === nothing
        end

        @testset "Integer Class" begin
            expected = Reflection.ClassDescriptor(
                C_NULL,
                :JInteger,
                :jobject,
                "Ljava/lang/Integer;"
            )
            expectedsuperclass = Reflection.ClassDescriptor(
                C_NULL,
                :JNumber,
                :jobject,
                "Ljava/lang/Number;"
            )
            integerclass = Reflection.findclass(Symbol("java.lang.Integer"))
            @test integerclass == expected
            @test Reflection.superclass(integerclass) == expectedsuperclass
        end 
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
            Reflection.ModifiersDescriptor(false, true)
        )
        
        # boolean equals(Object)
        equals = Reflection.MethodDescriptor(
            "equals", 
            Reflection.ClassDescriptor(C_NULL, :Bool, :jboolean, "Z"), 
            [Reflection.ClassDescriptor(C_NULL, :JObject, :jobject, "Ljava/lang/Object;")],
            Reflection.ModifiersDescriptor(false, true)
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
            Reflection.ModifiersDescriptor(true, true)
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
            Reflection.ModifiersDescriptor(false, true)
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

    @testset "Find Declared Methods" begin
        methods = Reflection.classdeclaredmethods(Symbol("java.lang.String"))
        @test length(methods) > 0
        @test_isa methods Vector{Reflection.MethodDescriptor}

        found_getbytes = false
        found_equals = false
        found_format = false
        found_notify = false

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
            Reflection.ModifiersDescriptor(false, true)
        )
        
        # boolean equals(Object)
        equals = Reflection.MethodDescriptor(
            "equals", 
            Reflection.ClassDescriptor(C_NULL, :Bool, :jboolean, "Z"), 
            [Reflection.ClassDescriptor(C_NULL, :JObject, :jobject, "Ljava/lang/Object;")],
            Reflection.ModifiersDescriptor(false, true)
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
            Reflection.ModifiersDescriptor(true, true)
        )

        # void notify()
        notify = Reflection.MethodDescriptor(
            "notify",
            Reflection.ClassDescriptor(C_NULL, :Nothing, :jvoid, "V"),
            [],
            Reflection.ModifiersDescriptor(false, true)
        )

        for m in methods
            if getbytes == m
                found_getbytes = true
            elseif equals == m
                found_equals = true
            elseif format == m
                found_format = true
            elseif notify == m
                found_notify = true
            end
        end
        @test found_getbytes
        # Equals is declared, as it is overriden, and should be found
        @test found_equals
        @test found_format
        # Notify is inherited and should not be found
        @test_false found_notify
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
