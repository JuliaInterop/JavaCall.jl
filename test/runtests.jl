using Base.Test
using JavaCall
JavaCall.init(["-Xmx 128M"])
jlm = @jvimport "java.lang.Math"

@test_approx_eq 1.0 jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
@test_approx_eq 1.0 jcall(jlm, "min", jdouble, (jdouble,jdouble), 1,2)
@test 1 == jcall(jlm, "abs", jint, (jint,), -1)

a=JString("how are you")
@test a.ptr != C_NULL
@test 11==ccall(JavaCall.jnifunc.GetStringUTFLength, jint, (Ptr{JavaCall.JNIEnv}, Ptr{Void}), JavaCall.penv, a.ptr)
b=ccall(JavaCall.jnifunc.GetStringUTFChars, Ptr{Uint8}, (Ptr{JavaCall.JNIEnv}, Ptr{Void}, Ptr{Void}), JavaCall.penv, a.ptr, C_NULL)
@test bytestring(b) == "how are you"

jnu = @jvimport "java.net.URL"
gurl = jnu((JString,), "http://www.google.com")
@test "www.google.com"==jcall(gurl, "getHost", JString,())

jni=@jvimport "java.net.URI"
guri=jcall(gurl, "toURI", jni,())
@test typeof(guri)==jni

h=jcall(guri, "hashCode", jint,())
typeof(h)==jint

# At the end, unload the JVM before exiting
JavaCall.destroy()