@testset verbose = true "Test JNI API" begin
    import JavaCall: JNI
    JNI.init_new_vm(JAVA_LIBPATH, ["-Djava.class.path=$(@__DIR__)/java"])
    @test JNI.is_jni_loaded()
    @test JNI.is_env_loaded()

    @testset "Find class by name" begin
        @test JNI.find_class("java/lang/System") != C_NULL
        @test JNI.find_class("Test") != C_NULL
        @test JNI.find_class("Test\$TestInner") != C_NULL
    end

    JNI.destroy_vm()
    @test_false JNI.is_jni_loaded()
    @test_false JNI.is_env_loaded()
end
