using Base.Test
using JavaCall
using Compat


versioninfo();

# JavaCall.init(["-Djava.class.path=$(joinpath(Pkg.dir(), "JavaCall", "test"))"])
JavaCall.init(["-verbose:gc","-Djava.class.path=$(joinpath(Pkg.dir(), "JavaCall", "test"))"])

a=JString("how are you")
@test a.ptr != C_NULL
@test 11==ccall(JavaCall.jnifunc.GetStringUTFLength, jint, (Ptr{JavaCall.JNIEnv}, Ptr{Void}), JavaCall.penv, a.ptr)
b=ccall(JavaCall.jnifunc.GetStringUTFChars, Ptr{UInt8}, (Ptr{JavaCall.JNIEnv}, Ptr{Void}, Ptr{Void}), JavaCall.penv, a.ptr, C_NULL)
@test unsafe_string(b) == "how are you"

# Test parameter passing
T = @jimport Test
@test 10 == jcall(T, "testShort", jshort, (jshort,), 10)
@test 10 == jcall(T, "testInt", jint, (jint,), 10)
@test 10 == jcall(T, "testLong", jlong, (jlong,), 10)
@test typemax(jint) == jcall(T, "testInt", jint, (jint,), typemax(jint))
@test typemax(jlong) == jcall(T, "testLong", jlong, (jlong,), typemax(jlong))
@test "Hello Java"==jcall(T, "testString", JString, (JString,), "Hello Java")
@test @compat Float64(10.02) == jcall(T, "testDouble", jdouble, (jdouble,), 10.02) #Comparing exact float representations hence ==
@test @compat Float32(10.02) == jcall(T, "testFloat", jfloat, (jfloat,), 10.02)
@test realmax(jdouble) == jcall(T, "testDouble", jdouble, (jdouble,), realmax(jdouble))
@test realmax(jfloat) == jcall(T, "testFloat", jfloat, (jfloat,), realmax(jfloat))

c=JString(C_NULL)
@test isnull(c)
@test "" == jcall(T, "testString", JString, (JString,), c)

# Test calling static methods
jlm = @jimport "java.lang.Math"
@test_approx_eq 1.0 jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
@test_approx_eq 1.0 jcall(jlm, "min", jdouble, (jdouble,jdouble), 1,2)
@test 1 == jcall(jlm, "abs", jint, (jint,), -1)

#Test instance creation
jnu = @jimport java.net.URL
gurl = jnu((JString,), "http://www.google.com")
@test "www.google.com"==jcall(gurl, "getHost", JString,())

#Test instance methods
jni=@jimport java.net.URI
guri=jcall(gurl, "toURI", jni,())
@test typeof(guri)==jni

h=jcall(guri, "hashCode", jint,())
typeof(h)==jint

#Test NULL
H=@jimport java.util.HashMap
a=jcall(T, "testNull", H, ())
@test_throws ErrorException jcall(a, "toString", JString, ())

# Arrays
j_u_arrays = @jimport java.util.Arrays
@test 3 == jcall(j_u_arrays, "binarySearch", jint, (Array{jint,1}, jint), [10,20,30,40,50,60], 40)
@test 2 == jcall(j_u_arrays, "binarySearch", jint, (Array{JObject,1}, JObject), ["123","abc","uvw","xyz"], "uvw")

a=jcall(j_u_arrays, "copyOf", Array{jint, 1}, (Array{jint, 1}, jint), [1,2,3], 3)
@test typeof(a) == Array{jint, 1}
@test a[1] == @compat Int32(1)
@test a[2] == @compat Int32(2)
@test a[3] == @compat Int32(3)

a=jcall(j_u_arrays, "copyOf", Array{JObject, 1}, (Array{JObject, 1}, jint), ["a","b","c"], 3)
@test 3==length(a)
@test "a"==unsafe_string(convert(JString, a[1]))
@test "b"==unsafe_string(convert(JString, a[2]))
@test "c"==unsafe_string(convert(JString, a[3]))

#Test for Dates

jd = @jimport(java.util.Date)(())
jcal = @jimport(java.util.GregorianCalendar)(())
jsd =  @jimport(java.sql.Date)((jlong,),round(jlong, time()))

@assert typeof(convert(Dates.DateTime, jd)) == Dates.DateTime
@assert typeof(convert(Dates.DateTime, jcal)) == Dates.DateTime
@assert typeof(convert(Dates.DateTime, jsd)) == Dates.DateTime
nulldate = @jimport(java.util.Date)(C_NULL)
@assert Dates.year(convert(Dates.DateTime, nulldate)) == 1970
nullcal = @jimport(java.util.GregorianCalendar)(C_NULL)
@assert Dates.year(convert(Dates.DateTime, nullcal)) == 1970

Dates.year(convert(Dates.DateTime, nullcal)) == 1970
#Test for Map conversion

JHashMap = @jimport(java.util.HashMap)
p = JHashMap(())
a=@compat Dict("a"=>"A", "b"=>"B")
b=convert(@jimport(java.util.Map), JString, JString, a)
@assert jcall(b, "size", jint, ()) == 2

# test for ArrayList conversion
JArrayList = @jimport(java.util.ArrayList)
p = JArrayList(())
a = ["hello", " ", "world"]
b = convert(@jimport(java.util.ArrayList), a, JString)
@assert jcall(b, "size", jint, ()) == 3

#Inner Classes
TestInner = @jimport(Test$TestInner)
Test = @jimport(Test)
t=Test(())
inner = TestInner((Test,), t)
@assert jcall(inner, "innerString", JString, ()) == "from inner"

#Static Field Access
@assert jfield(@jimport(java.lang.Math), "E", jdouble) == 2.718281828459045
@assert jfield(@jimport(java.lang.Math), "PI", jdouble) == 3.141592653589793
@assert jfield(@jimport(java.text.NumberFormat), "INTEGER_FIELD", jint) == 0
Locale = @jimport java.util.Locale
lc = jfield(@jimport(java.util.Locale), "CANADA", @jimport(java.util.Locale))
#Instance field access
#Disabled for now. Need to verify stability
@assert jfield(@jimport(java.util.logging.Logger), "GLOBAL_LOGGER_NAME", JString ) == "global"
@assert jcall(lc, "getCountry", JString, ()) == "CA"
@assert jfield(t, "integerField", jint) == 100
@assert jfield(t, "stringField", JString) == "A STRING"

# Test Memory allocation and de-allocatios
# the following loop fails with an OutOfMemoryException in the absence of de-allocation
# However, since Java and Julia memory are not linked, and manual gc() is required.
gc()
for i in 1:100000
	a=JString("A"^10000); #deleteref(a);
	if (i%10000 == 0); gc(); end
end

#Test for Issue #8
@test_throws ErrorException jcall(jlm, "sinx", jdouble, (jdouble,), 1.0)
@test_throws ErrorException jcall(jlm, "sinx", jdouble, (jdouble,), 1.0)

@test length(listmethods(JString("test"))) >= 72
@test length(listmethods(JString("test"), "indexOf")) >= 3
m = listmethods(JString("test"), "indexOf")[1]
@test getname(getreturntype(m)) == "int"
@test [getname(typ) for typ in getparametertypes(m)] == ["java.lang.String", "int"]

#Test for double free bug, #20
#Fix in #28. The following lines will segfault without the fix
JHashtable = @jimport java.util.Hashtable
JProperties = @jimport java.util.Properties
ta_20=Any[]
for i=1:100; push!(ta_20, convert(JHashtable, JProperties((),))); end
gc(); gc()
for i=1:100; @test jcall(ta_20[i], "size", jint, ()) == 0; end

# Test array conversions
jobj = jcall(T, "testArrayAsObject", JObject, ())
arr = convert(Array{Array{UInt8, 1}, 1}, jobj)
@test ["Hello", "World"] == map(Compat.String, arr)

#Test iterator conversions

JArrayList = @jimport(java.util.ArrayList)
a=JArrayList(())
jcall(a, "add", jboolean, (JObject,), "abc")
jcall(a, "add", jboolean, (JObject,), "cde")
jcall(a, "add", jboolean, (JObject,), "efg")

t=Array{Any, 1}()
for i in jcall(a, "iterator", @jimport(java.util.Iterator), ())
	push!(t, unsafe_string(i))
end

@test length(t) == 3
@test t[1] == "abc"
@test t[2] == "cde"
@test t[3] == "efg"

#Different iterator type - ListIterator
t=Array{Any, 1}()
for i in jcall(a, "listIterator", @jimport(java.util.ListIterator), ())
	push!(t, unsafe_string(i))
end

@test length(t) == 3
@test t[1] == "abc"
@test t[2] == "cde"
@test t[3] == "efg"

#Empty List
a=JArrayList(())
t=Array{Any, 1}()
for i in jcall(a, "iterator", @jimport(java.util.Iterator), ())
	push!(t, unsafe_string(i))
end
@test length(t) == 0

# At the end, unload the JVM before exiting
JavaCall.destroy()
