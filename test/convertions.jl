@testset verbose = true "Tests for Predefined Conversions" begin

    using JavaCall.Conversions
    using JavaCall.JNI

    @testset "Primitive Conversions" begin
        @testset "Boolean conversions" begin
            @test convert_to_julia(Bool, JNI_TRUE)
            @test_false convert_to_julia(Bool, JNI_FALSE)
    
            @test convert_to_jni(jboolean, true) == JNI_TRUE
            @test convert_to_jni(jboolean, false) == JNI_FALSE
        end
    
        @testset "Byte conversions" begin
            @test convert_to_julia(Int8, jbyte(1)) == Int8(1)
            @test convert_to_jni(jbyte, Int8(1)) == jbyte(1)
        end
    
        @testset "Char conversions" begin
            @test convert_to_julia(Char, jchar('a')) == 'a'
            @test Int(convert_to_julia(Char, jchar('a'))) == 97
            @test convert_to_jni(jchar, 'a') == jchar('a')
            @test Int(convert_to_jni(jchar, 'a')) == 97
        end
    
        @testset "Short conversions" begin
            @test convert_to_julia(Int16, jshort(1)) == Int16(1)
            @test convert_to_jni(jshort, Int16(1)) == jshort(1)
        end
    
        @testset "Integer conversions" begin
            @test convert_to_julia(Int32, jint(1)) == Int32(1)
            @test convert_to_jni(jint, Int32(1)) == jint(1)
        end
    
        @testset "Long conversions" begin
            @test convert_to_julia(Int64, jlong(1)) == 1
            @test convert_to_jni(jlong, 1) == jlong(1)
        end
    
        @testset "Float conversions" begin
            @test convert_to_julia(Float32, jfloat(1.1)) == Float32(1.1)
            @test convert_to_jni(jfloat, Float32(1.1)) == jfloat(1.1)
        end
    
        @testset "Double conversions" begin
            @test convert_to_julia(Float64, jdouble(1.1)) == 1.1
            @test convert_to_jni(jdouble, 1.1) == jdouble(1.1)
        end
    
        @testset "Void conversions" begin
            @test convert_to_julia(Nothing, nothing) === nothing
            @test convert_to_jni(jvoid, nothing) === nothing
        end
    end

    @testset "Primitive Arrays Conversions" begin
        
        iscopy = Ref(JNI_TRUE)
        iscopyptr = convert(Ptr{jboolean}, pointer_from_objref(iscopy))

        @testset "Boolean Array" begin
            jni_array = JNI.new_boolean_array(5)
            JNI.set_boolean_array_region(jni_array, 0, 5, jboolean[
                JNI_TRUE, JNI_FALSE, JNI_FALSE, JNI_TRUE, JNI_TRUE
            ])
            julia_array = convert_to_julia(Vector{Bool}, jni_array)
            @test julia_array == [true, false, false, true, true]

            julia_array = [true, false, false, true, true]
            jni_array = convert_to_jni(jbooleanArray, julia_array)

            jni_ptr = JNI.get_boolean_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jboolean, x), unsafe_wrap(Vector{jboolean}, jni_ptr, (5,))) == 
                jboolean[JNI_TRUE, JNI_FALSE, JNI_FALSE, JNI_TRUE, JNI_TRUE]
        end

        @testset "Char Array" begin
            jni_array = JNI.new_char_array(5)
            JNI.set_char_array_region(jni_array, 0, 5, jchar[
                jchar('h'), jchar('e'), jchar('l'), jchar('l'), jchar('o')
            ])
            julia_array = convert_to_julia(Vector{Char}, jni_array)
            @test julia_array == ['h', 'e', 'l', 'l', 'o']

            julia_array = ['h', 'e', 'l', 'l', 'o']
            jni_array = convert_to_jni(jcharArray, julia_array)

            jni_ptr = JNI.get_char_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jchar, x), unsafe_wrap(Vector{jchar}, jni_ptr, (5,))) == 
                jchar[jchar('h'), jchar('e'), jchar('l'), jchar('l'), jchar('o')]
        end

        @testset "Short Array" begin
            jni_array = JNI.new_short_array(5)
            JNI.set_short_array_region(jni_array, 0, 5, jshort[
                jshort(1), jshort(2), jshort(3), jshort(4), jshort(5)
            ])
            julia_array = convert_to_julia(Vector{Int16}, jni_array)
            @test julia_array == [Int16(1), Int16(2), Int16(3), Int16(4), Int16(5)]
        
            julia_array = [Int16(1), Int16(2), Int16(3), Int16(4), Int16(5)]
            jni_array = convert_to_jni(jshortArray, julia_array)

            jni_ptr = JNI.get_short_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jshort, x), unsafe_wrap(Vector{jshort}, jni_ptr, (5,))) == 
                jshort[jshort(1), jshort(2), jshort(3), jshort(4), jshort(5)]
        end

        @testset "Int Array" begin
            jni_array = JNI.new_int_array(5)
            JNI.set_int_array_region(jni_array, 0, 5, jint[
                jint(1), jint(2), jint(3), jint(4), jint(5)
            ])
            julia_array = convert_to_julia(Vector{Int32}, jni_array)
            @test julia_array == [Int32(1), Int32(2), Int32(3), Int32(4), Int32(5)]
        
            julia_array = [Int32(1), Int32(2), Int32(3), Int32(4), Int32(5)]
            jni_array = convert_to_jni(jintArray, julia_array)

            jni_ptr = JNI.get_int_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jint, x), unsafe_wrap(Vector{jint}, jni_ptr, (5,))) == 
                jint[jint(1), jint(2), jint(3), jint(4), jint(5)]
        end

        @testset "Long Array" begin
            jni_array = JNI.new_long_array(5)
            JNI.set_long_array_region(jni_array, 0, 5, jlong[
                jlong(1), jlong(2), jlong(3), jlong(4), jlong(5)
            ])
            julia_array = convert_to_julia(Vector{Int64}, jni_array)
            @test julia_array == [1, 2, 3, 4, 5]

            julia_array = [1, 2, 3, 4, 5]
            jni_array = convert_to_jni(jlongArray, julia_array)

            jni_ptr = JNI.get_long_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jlong, x), unsafe_wrap(Vector{jlong}, jni_ptr, (5,))) == 
                jlong[jlong(1), jlong(2), jlong(3), jlong(4), jlong(5)]
        end

        @testset "Float Array" begin
            jni_array = JNI.new_float_array(5)
            JNI.set_float_array_region(jni_array, 0, 5, jfloat[
                jfloat(1.1), jfloat(2.2), jfloat(3.3), jfloat(4.4), jfloat(5.5)
            ])
            julia_array = convert_to_julia(Vector{Float32}, jni_array)
            @test julia_array == [
                Float32(1.1), Float32(2.2), Float32(3.3), Float32(4.4), Float32(5.5)
            ]

            julia_array = [
                Float32(1.1), Float32(2.2), Float32(3.3), Float32(4.4), Float32(5.5)
            ]
            jni_array = convert_to_jni(jfloatArray, julia_array)

            jni_ptr = JNI.get_float_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jfloat, x), unsafe_wrap(Vector{jfloat}, jni_ptr, (5,))) == 
                jfloat[jfloat(1.1), jfloat(2.2), jfloat(3.3), jfloat(4.4), jfloat(5.5)]
        end

        @testset "Double Array" begin
            jni_array = JNI.new_double_array(5)
            JNI.set_double_array_region(jni_array, 0, 5, jdouble[
                jdouble(1.1), jdouble(2.2), jdouble(3.3), jdouble(4.4), jdouble(5.5)
            ])
            julia_array = convert_to_julia(Vector{Float64}, jni_array)
            @test julia_array == [1.1, 2.2, 3.3, 4.4, 5.5]

            julia_array = [1.1, 2.2, 3.3, 4.4, 5.5]
            jni_array = convert_to_jni(jdoubleArray, julia_array)

            jni_ptr = JNI.get_double_array_elements(jni_array, iscopyptr)
            @test map(x -> convert(jdouble, x), unsafe_wrap(Vector{jdouble}, jni_ptr, (5,))) == 
                jdouble[jdouble(1.1), jdouble(2.2), jdouble(3.3), jdouble(4.4), jdouble(5.5)]
        end
    end
end
