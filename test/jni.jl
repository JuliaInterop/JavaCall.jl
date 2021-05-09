@testset verbose = true "Test JNI API" begin
    import JavaCall: JNI
    JNI.init_new_vm(JAVA_LIBPATH, [])
    @test JNI.is_jni_loaded()
    @test JNI.is_env_loaded()
    JNI.destroy_vm()
    @test_false JNI.is_jni_loaded()
    @test_false JNI.is_env_loaded()
end
