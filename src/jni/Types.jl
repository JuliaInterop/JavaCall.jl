module Types

export jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble, jsize,
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

const jboolean = Cuchar         # typedef unsigned char   jboolean;
const jchar = Cushort           # typedef unsigned short  jchar;
const jshort = Cshort           # typedef short           jshort;
const jfloat = Cfloat           # typedef float           jfloat;
const jdouble = Cdouble         # typedef double          jdouble;

const jsize = jint              # typedef jint            jsize;

const jvoid = Cvoid

struct _jobject end             # struct _jobject;

const jobject = Ptr{_jobject}   # typedef struct _jobject *jobject;
const jclass = jobject          # typedef jobject jclass;
const jthrowable = jobject      # typedef jobject jthrowable;
const jstring = jobject         # typedef jobject jstring;
const jarray = jobject          # typedef jobject jarray;

const jbooleanArray = jarray    # typedef jarray jbooleanArray;
const jbyteArray = jarray       # typedef jarray jbyteArray;
const jcharArray = jarray       # typedef jarray jcharArray;
const jshortArray = jarray      # typedef jarray jshortArray;
const jintArray = jarray        # typedef jarray jintArray;
const jlongArray = jarray       # typedef jarray jlongArray;
const jfloatArray = jarray      # typedef jarray jfloatArray;
const jdoubleArray = jarray     # typedef jarray jdoubleArray;
const jobjectArray = jarray     # typedef jarray jobjectArray;

const jweak = jobject           # typedef jobject jweak;

const jvalue = Union{           # typedef union jvalue {
    jboolean,                   #   jboolean z;
    jbyte,                      #   jbyte    b;
    jchar,                      #   jchar    c;
    jshort,                     #   jshort   s;
    jint,                       #   jint     i;
    jlong,                      #   jlong    j;
    jfloat,                     #   jfloat   f;
    jdouble,                    #   jdouble  d;
    jobject                     #   jobject  l;
}                               # } jvalue;

struct _jfieldID end                # struct _jfieldID;
const jfieldID = Ptr{_jfieldID}     # typedef struct _jfieldID *jfieldID;

struct _jmethodID end               # struct _jmethodID;
const jmethodID = Ptr{_jmethodID}   # typedef struct _jmethodID *jmethodID;

@enum jobjectRefType begin          # typedef enum _jobjectType {
    JNIInvalidRefType    = 0        #   JNIInvalidRefType    = 0,
    JNILocalRefType      = 1        #   JNILocalRefType      = 1,
    JNIGlobalRefType     = 2        #   JNIGlobalRefType     = 2,
    JNIWeakGlobalRefType = 3        #   JNIWeakGlobalRefType = 3
end                                 # } jobjectRefType;

struct JNINativeMethod      # typedef struct {
    name::Cstring           #   char *name;
    signature::Cstring      #   char *name;
    fnPtr::Ptr{Cvoid}       #   void *fnPtr;
end                         # } JNINativeMethod;

end
