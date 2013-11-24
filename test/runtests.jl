using Base.Test
using JavaCall
JavaCall.init(["-Xmx 128M"])
jlm = @jvimport "java.lang.Math"

@test_approx_eq 1.0 jcall(jlm, "sin", jdouble, (jdouble,), pi/2)
@test_approx_eq 1.0 jcall(jlm, "min", jdouble, (jdouble,jdouble), 1,2)
@test 1 == jcall(jlm, "abs", jint, (jint,), -1)


# At the end, unload the JVM before exiting
JavaCall.destroy()