module JProxies
    import JavaCall: JavaCall, JNI,
            javaclassname, metaclass, getreturntype, convert_args, convert_arg, geterror,
            JavaObject, JavaMetaClass,
            jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble,
            JObject, JClass, JMethod, JConstructor, JField, JString,
            @jimport, jcall, jfield, isnull,
            getname, getclass, listmethods, getreturntype, getparametertypes, classforname,
            narrow


    import Base: convert

    export JProxy, @class, interfacehas, staticproxy, @jimport

    include("proxy.jl")
end
