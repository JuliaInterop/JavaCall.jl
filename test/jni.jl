@testset verbose = true "Test JNI API" begin
    import JavaCall: JNI
    JNI.init_new_vm(JAVA_LIBPATH, ["-Djava.class.path=$(@__DIR__)/java"])
    @test JNI.is_jni_loaded()
    @test JNI.is_env_loaded()

    @testset "Class operations" begin
        @testset "Find class by name" begin
            for classname in ["java/lang/System", "[Ljava/lang/Object;", "Test", "Test\$TestInner"]
                @test_not_cnull JNI.find_class(classname)
                @test_isa JNI.find_class(classname) JNI.jclass
            end
        end

        @testset "Get super class" begin
            jobjectclass = JNI.find_class("java/lang/Object")
            jstringclass = JNI.find_class("java/lang/String")
            @test_not_cnull jobjectclass jstringclass
            @test_isa jobjectclass jstringclass JNI.jclass
            jstringsuperclass = JNI.get_superclass(jstringclass)
            @test_not_cnull jstringsuperclass
            @test_isa jstringsuperclass JNI.jclass
            @test unsafe_load(jstringsuperclass) == unsafe_load(jobjectclass)
        end
    end

    @testset "Method operations" begin
        @testset "Get no parameter method id" begin
            jobjectclass = JNI.find_class("java/lang/Object")
            @test_not_cnull jobjectclass
            @test_isa jobjectclass JNI.jclass
            jhashmethodid = JNI.get_method_i_d(jobjectclass, "hashCode", "()I")
            @test_not_cnull jhashmethodid
            @test_isa jhashmethodid JNI.jmethodID
        end

        @testset "Get single parameter method id" begin
            jobjectclass = JNI.find_class("java/lang/Object")
            @test_not_cnull jobjectclass
            @test_isa jobjectclass JNI.jclass
            jequalsmethodid = JNI.get_method_i_d(jobjectclass, "equals", "(Ljava/lang/Object;)Z")
            @test_not_cnull jequalsmethodid
            @test_isa jequalsmethodid JNI.jmethodID
        end

        @testset "Get multiple parameter method id" begin
            jstringclass = JNI.find_class("java/lang/String")
            @test_not_cnull jstringclass
            @test_isa jstringclass JNI.jclass
            jvalueofmethodid = JNI.get_method_i_d(jstringclass, "replace", "(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;")
            @test_not_cnull jvalueofmethodid
            @test_isa jvalueofmethodid JNI.jmethodID
        end

        @testset "Get static single parameter method id" begin
            jstringclass = JNI.find_class("java/lang/String")
            @test_not_cnull jstringclass
            @test_isa jstringclass JNI.jclass
            jvalueofmethodid = JNI.get_static_method_i_d(jstringclass, "valueOf", "(F)Ljava/lang/String;")
            @test_not_cnull jvalueofmethodid
            @test_isa jvalueofmethodid JNI.jmethodID
        end

        @testset "Get static variable parameters method id" begin
            jstringclass = JNI.find_class("java/lang/String")
            @test_not_cnull jstringclass
            @test_isa jstringclass JNI.jclass
            jvalueofmethodid = JNI.get_static_method_i_d(jstringclass, "join", "(Ljava/lang/CharSequence;[Ljava/lang/CharSequence;)Ljava/lang/String;")
            @test_not_cnull jvalueofmethodid
            @test_isa jvalueofmethodid JNI.jmethodID
        end
    end

    JNI.destroy_vm()
    @test_false JNI.is_jni_loaded()
    @test_false JNI.is_env_loaded()
end
