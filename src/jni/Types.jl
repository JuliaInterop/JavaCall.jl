module Types

export jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble, jsize, jprimitive,
    jvoid, jobject, jclass, jthrowable, jweak, jmethodID, jfieldID, jstring, jarray,
    JNINativeMethod, jobjectArray, jbooleanArray, jbyteArray, jshortArray, jintArray,
    jlongArray, jfloatArray, jdoubleArray, jcharArray, jvalue, jobjectRefType

# jni_md.h
const jint = Cint
#ifdef _LP64 /* 64-bit Solaris */
# typedef long jlong;
const jlong = Clonglong
const jbyte = Cchar

# jni.h

const jboolean = Cuchar
const jchar = Cushort
const jshort = Cshort
const jfloat = Cfloat
const jdouble = Cdouble
const jsize = jint
const jprimitive = Union{jboolean, jchar, jshort, jfloat, jdouble, jint, jlong}

const jvoid = Nothing

const jobject = Ptr{Nothing}
const jclass = Ptr{Nothing}
const jthrowable = Ptr{Nothing}
const jweak = Ptr{Nothing}
const jmethodID = Ptr{Nothing}
const jfieldID = Ptr{Nothing}
const jstring = Ptr{Nothing}
const jarray = Ptr{Nothing}
const JNINativeMethod = Ptr{Nothing}
const jobjectArray = Ptr{Nothing}
const jbooleanArray = Ptr{Nothing}
const jbyteArray = Ptr{Nothing}
const jshortArray = Ptr{Nothing}
const jintArray = Ptr{Nothing}
const jlongArray = Ptr{Nothing}
const jfloatArray = Ptr{Nothing}
const jdoubleArray = Ptr{Nothing}
const jcharArray = Ptr{Nothing}
const jvalue = Int64

@enum jobjectRefType begin
    JNIInvalidRefType    = 0
    JNILocalRefType      = 1
    JNIGlobalRefType     = 2
    JNIWeakGlobalRefType = 3
end

end
