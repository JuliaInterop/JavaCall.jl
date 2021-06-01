# File to specify the project exports
# It is not a module as it is just included by the JavaCall module
# to facilitate the exports

export 
# Init Options
    defaultopts, fromcurrentvm, forjavahome, setfromcurrentvm!, unsetfromcurrentvm!,
    setjavahome!, unsetjavahome!, pushclasspath!, pushoptions!,
# JNI
    # Types.jl    
    jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble, jsize,
    jvoid, jobject, jclass, jthrowable, jweak, jmethodID, jfieldID, jstring, jarray,
    JNINativeMethod, jobjectArray, jbooleanArray, jbyteArray, jshortArray, jintArray,
    jlongArray, jfloatArray, jdoubleArray, jcharArray, jvalue, jobjectRefType,
    # Constants.jl
    JNI_FALSE, JNI_TRUE,
# Java VM
    init, destroy,
# Jimport
    @jimport,
# Java Lang
    JObject, JString, new_string, equals
