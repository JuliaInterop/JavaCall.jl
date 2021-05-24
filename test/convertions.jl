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
        @testset "Boolean Array" begin
            jni_array = JNI.new_boolean_array(5)
            JNI.set_boolean_array_region(jni_array, 0, 5, jboolean[
                JNI_TRUE, JNI_FALSE, JNI_FALSE, JNI_TRUE, JNI_TRUE
            ])
            julia_array = convert_to_julia(Vector{Bool}, jni_array)
            @test julia_array == [true, false, false, true, true]
        end
    end
end
