using JavaCall
using JProxies
using Test

#const pxyptr = JavaCall.pxyptr
@testset "proxy_initialization" begin
    @test JProxies.init(["-Djava.class.path=$(@__DIR__)"])==nothing
end

@testset "proxy_array_list" begin
    JAL = @jimport java.util.ArrayList
    @test JProxy(JavaCall.jnew(Symbol("java.lang.Integer"), (jint,), 3)).toString() == "3"
    @test JProxy(@jimport(java.lang.Integer)).valueOf(3) == 3
    a = JProxy(JAL())
    @test a.size() == 0
    a.add("one")
    @test a.size() == 1
    @test a.toString() == "[one]"
    removed = a.remove(0)
    @test typeof(removed) == String
    @test removed == "one"
    a.add(1)
    @test a.get(0) == 1
    @test a.toString() == "[1]"
    b = JProxy(JAL())
    b.addAll(a)
    @test a.toString() == b.toString()
    a.add("two")
    @test collect(a) == [1, "two"]
end

@testset "proxy_test_class" begin
    T = @jimport(Test)
    t = JProxy(T(()))
    t.integerField = 3
    @test(t.integerField == 3)
    t.stringField = "hello"
    @test(t.stringField == "hello")
    @test(t.toString() == "Test(3, hello)")
    t.objectField = t
    @test(t.objectField == t)
    @test(t.objectField.stringField == "hello")
    @test(t.objectField.getInt() == 3)
    @test(t.objectField.getString() == "hello")
end

@testset "proxy_meta" begin
    @test(JProxy(@jimport(java.lang.Integer)).MAX_VALUE == 2147483647)
    @test(JProxy(@jimport(java.lang.Long)).MAX_VALUE == 9223372036854775807)
    @test(JProxy(@jimport(java.lang.Double)).MAX_VALUE == 1.7976931348623157e308)
    @test("class java.lang.Object" == JProxy(JavaCall.metaclass("java.lang.Class")).forName("java.lang.Object").toString())
    @test("class java.io.PrintStream" == JProxy(JavaObject{Symbol("java.lang.System")}).out.getClass().toString())
    @test("static class java.util.Arrays" == string(JProxy(@jimport(java.util.Arrays))))
end

@testset "proxy_array" begin
    s,ptr=JavaCall.convert_arg(JProxy{Array{Int,1}, false}, [1,2]) # convert Julia array to an unwrapped java array
    p=JProxy(ptr) # wrap it
    @test(length(p) == 2)
    @test(p[1] == 1)
    @test(p[2] == 2)
    @test(collect(p) == [1, 2])
    p[1] = 3
    @test(p[1] == 3)
end
