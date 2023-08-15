using Test
using JavaCall

@testset "jcall macro" begin
    JavaCall.isloaded() || JavaCall.init(["-Djava.class.path=$(@__DIR__)"])
    System = @jimport java.lang.System
    version_from_macro = @jcall System.getProperty("java.version"::JString)::JString
    version_from_func = jcall(System, "getProperty", JString, (JString,), "java.version")
    @test version_from_macro == version_from_func
    @test "bar" == @jcall System.getProperty("foo"::JString, "bar"::JString)::JString
    @test 0x00 == @jcall System.out.checkError()::jboolean
    rettype = jboolean
    @test 0x00 == @jcall System.out.checkError()::rettype
    jstr = JString
    @test version_from_func == @jcall System.getProperty("java.version"::jstr)::jstr

    T = @jimport Test
    @test 10 == @jcall T.testShort(10::jshort)::jshort
    @test 10 == @jcall T.testInt(10::jint)::jint
    @test 10 == @jcall T.testLong(10::jlong)::jlong
    @test typemax(jint) == @jcall T.testInt(typemax(jint)::jint)::jint
    @test typemax(jlong) == @jcall T.testLong(typemax(jlong)::jlong)::jlong
    @test "Hello Java" == @jcall T.testString("Hello Java"::JString)::JString
    @test Float64(10.02) == @jcall T.testDouble(10.02::jdouble)::jdouble
    @test Float32(10.02) == @jcall T.testFloat(10.02::jfloat)::jfloat
    @test floatmax(jdouble) == @jcall T.testDouble(floatmax(jdouble)::jdouble)::jdouble
    @test floatmax(jfloat) == @jcall T.testFloat(floatmax(jfloat)::jfloat)::jfloat
    c=JString(C_NULL)
    @test isnull(c)
    @test "" == @jcall T.testString(c::JString)::JString
    a = rand(10^7)
    @test [@jcall(T.testDoubleArray(a::Array{jdouble,1})::jdouble)
           for i in 1:10][1] ≈ sum(a)
    a = nothing

    jlm = @jimport "java.lang.Math"
    @test 1.0 ≈ @jcall jlm.sin((pi/2)::jdouble)::jdouble
    @test 1.0 ≈ @jcall jlm.min(1::jdouble, 2::jdouble)::jdouble
    @test 1 == @jcall jlm.abs((-1)::jint)::jint

    @testset "jcall macro instance_methods_1" begin
        jnu = @jimport java.net.URL
        gurl = @jcall jnu("https://en.wikipedia.org"::JString)::jnu
        @test "en.wikipedia.org"== @jcall gurl.getHost()::JString
        jni = @jimport java.net.URI
        guri = @jcall gurl.toURI()::jni
        @test typeof(guri)==jni

        h=@jcall guri.hashCode()::jint
        @test typeof(h)==jint
    end

    jlist = @jimport java.util.ArrayList
    @test 0x01 == @jcall jlist().add(JObject(C_NULL)::JObject)::jboolean
end
