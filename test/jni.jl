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

    @testset "Array operations" begin
        @testset "Fill char array" begin
            array = JNI.new_char_array(3)
            @test_not_cnull array
            @test_isa array JNI.jcharArray
            @test JNI.get_array_length(array) == 3
            
            original = JNI.jchar[JNI.jchar('c'), JNI.jchar('a'), JNI.jchar('r')]
            JNI.set_char_array_region(array, 0, 3, original)
            result = Vector{JNI.jchar}(undef, 3)
            JNI.get_char_array_region(array, 0, 3, result)
            @test original == result
        end

        @testset "Fill String array" begin
            clazz = JNI.find_class("java/lang/String")
            @test_not_cnull clazz
            @test_isa clazz JNI.jclass

            array = JNI.new_object_array(4, clazz, JNI.jobject(C_NULL))
            @test_not_cnull array
            @test_isa array JNI.jobjectArray
            @test JNI.get_array_length(array) == 4

            constructor = JNI.get_method_i_d(clazz, "<init>", "()V")
            @test_not_cnull constructor
            @test_isa constructor JNI.jmethodID

            numelemnts = 4
            original = JNI.jobject[]
            for i in 1:4
                el = JNI.new_object_a(clazz, constructor, JNI.jvalue[])
                @test_not_cnull el
                @test_isa el JNI.jobject
                push!(original, el)
                JNI.set_object_array_element(array, i-1, el)
            end

            result = JNI.jobject[]
            for i in 1:4
                push!(result, JNI.get_object_array_element(array, i-1))
            end
            
            for i in 1:4
                @test unsafe_load(original[i]) == unsafe_load(result[i])
            end
        end
    end

    @testset "Construct object operations" begin
        @testset "Construct object with no parameters" begin
            jstringclass = JNI.find_class("java/lang/String")
            @test_not_cnull jstringclass
            @test_isa jstringclass JNI.jclass
            jconstructormethodid = JNI.get_method_i_d(jstringclass, "<init>", "()V")
            @test_not_cnull jconstructormethodid
            @test_isa jconstructormethodid JNI.jmethodID
            jstringobject = JNI.new_object_a(jstringclass, jconstructormethodid, JNI.jvalue[])
            @test_not_cnull jstringobject
            @test_isa jstringobject JNI.jobject
        end

        @testset "Construct object with single parameter" begin
            jintegerclass = JNI.find_class("java/lang/Integer")
            @test_not_cnull jintegerclass
            @test_isa jintegerclass JNI.jclass
            jconstructormethodid = JNI.get_method_i_d(jintegerclass, "<init>", "(I)V")
            @test_not_cnull jconstructormethodid
            @test_isa jconstructormethodid JNI.jmethodID
            jintegerobject = JNI.new_object_a(jintegerclass, jconstructormethodid, JNI.jvalue[1])
            @test_not_cnull jintegerobject
            @test_isa jintegerobject JNI.jobject
        end

        @testset "Construct object with multiple parameters" begin
            clazz = JNI.find_class("Constructors")
            @test_not_cnull clazz
            @test_isa clazz JNI.jclass
            constructor = JNI.get_method_i_d(clazz, "<init>", "(III)V")
            @test_not_cnull constructor
            @test_isa constructor JNI.jmethodID
            object = JNI.new_object_a(clazz, constructor, JNI.jvalue[1, 2, 3])
            @test_not_cnull object
            @test_isa object JNI.jobject
        end

        @testset "Construct object with variable parameters" begin
            clazz = JNI.find_class("Constructors")
            @test_not_cnull clazz
            @test_isa clazz JNI.jclass

            constructor = JNI.get_method_i_d(clazz, "<init>", "([I)V")
            @test_not_cnull constructor
            @test_isa constructor JNI.jmethodID

            args = JNI.new_int_array(5)
            @test_not_cnull args
            @test_isa args JNI.jintArray
            JNI.set_int_array_region(args, 0, 5, JNI.jint[1, 2, 3, 4, 5])

            object = JNI.new_object_a(clazz, constructor, JNI.jvalue[args])
            @test_not_cnull object
            @test_isa object JNI.jobject
        end
    end

    JNI.destroy_vm()
    @test_false JNI.is_jni_loaded()
    @test_false JNI.is_env_loaded()
end
