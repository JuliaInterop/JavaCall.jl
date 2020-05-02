module JNI

# jnienv.jl exports
export JNINativeInterface, JNIEnv, JNIInvokeInterface, JavaVM, JavaCallError
# jni_md.h exports
export jint, jlong, jbyte
# jni.h exports
export jboolean, jchar, jshort, jfloat, jdouble, jsize, jprimitive

include("jnienv.jl")

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
jprimitive = Union{jboolean, jchar, jshort, jfloat, jdouble, jint, jlong}

jobject = Ptr{Nothing}
jclass = Ptr{Nothing}
jthrowable = Ptr{Nothing}
jweak = Ptr{Nothing}
jmethodID = Ptr{Nothing}
jfieldID = Ptr{Nothing}
jstring = Ptr{Nothing}
jarray = Ptr{Nothing}
JNINativeMethod = Ptr{Nothing}
jobjectArray = Ptr{Nothing}
jbooleanArray = Ptr{Nothing}
jbyteArray = Ptr{Nothing}
jshortArray = Ptr{Nothing}
jintArray = Ptr{Nothing}
jlongArray = Ptr{Nothing}
jfloatArray = Ptr{Nothing}
jdoubleArray = Ptr{Nothing}
jcharArray = Ptr{Nothing}
jvalue = Int64

@enum jobjectRefType begin
    JNIInvalidRefType    = 0
    JNILocalRefType      = 1
    JNIGlobalRefType     = 2
    JNIWeakGlobalRefType = 3
end

export GetVersion
GetVersion(env::Ptr{JNIEnv}) =
  ccall(Main.JavaCall.jnifunc.GetVersion, jint, (Ptr{JNIEnv},), env)

export DefineClass
DefineClass(env::Ptr{JNIEnv}, name::AbstractString, loader::jobject, buf::Array{jbyte,1}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.DefineClass, jclass, (Ptr{JNIEnv}, Cstring, jobject, Ptr{jbyte}, jsize,), env, String(name), loader, buf, len)

export FindClass
FindClass(env::Ptr{JNIEnv}, name::AbstractString) =
  ccall(Main.JavaCall.jnifunc.FindClass, jclass, (Ptr{JNIEnv}, Cstring,), env, String(name))

export FromReflectedMethod
FromReflectedMethod(env::Ptr{JNIEnv}, method::jobject) =
  ccall(Main.JavaCall.jnifunc.FromReflectedMethod, jmethodID, (Ptr{JNIEnv}, jobject,), env, method)

export FromReflectedField
FromReflectedField(env::Ptr{JNIEnv}, field::jobject) =
  ccall(Main.JavaCall.jnifunc.FromReflectedField, jfieldID, (Ptr{JNIEnv}, jobject,), env, field)

export ToReflectedMethod
ToReflectedMethod(env::Ptr{JNIEnv}, cls::jclass, methodID::jmethodID, isStatic::jboolean) =
  ccall(Main.JavaCall.jnifunc.ToReflectedMethod, jobject, (Ptr{JNIEnv}, jclass, jmethodID, jboolean,), env, cls, methodID, isStatic)

export GetSuperclass
GetSuperclass(env::Ptr{JNIEnv}, sub::jclass) =
  ccall(Main.JavaCall.jnifunc.GetSuperclass, jclass, (Ptr{JNIEnv}, jclass,), env, sub)

export IsAssignableFrom
IsAssignableFrom(env::Ptr{JNIEnv}, sub::jclass, sup::jclass) =
  ccall(Main.JavaCall.jnifunc.IsAssignableFrom, jboolean, (Ptr{JNIEnv}, jclass, jclass,), env, sub, sup)

export ToReflectedField
ToReflectedField(env::Ptr{JNIEnv}, cls::jclass, fieldID::jfieldID, isStatic::jboolean) =
  ccall(Main.JavaCall.jnifunc.ToReflectedField, jobject, (Ptr{JNIEnv}, jclass, jfieldID, jboolean,), env, cls, fieldID, isStatic)

export Throw
Throw(env::Ptr{JNIEnv}, obj::jthrowable) =
  ccall(Main.JavaCall.jnifunc.Throw, jint, (Ptr{JNIEnv}, jthrowable,), env, obj)

export ThrowNew
ThrowNew(env::Ptr{JNIEnv}, clazz::jclass, msg::AbstractString) =
  ccall(Main.JavaCall.jnifunc.ThrowNew, jint, (Ptr{JNIEnv}, jclass, Cstring,), env, clazz, String(msg))

export ExceptionOccurred
ExceptionOccurred(env::Ptr{JNIEnv}) =
  ccall(Main.JavaCall.jnifunc.ExceptionOccurred, jthrowable, (Ptr{JNIEnv},), env)

export ExceptionDescribe
ExceptionDescribe(env::Ptr{JNIEnv}) =
  ccall(Main.JavaCall.jnifunc.ExceptionDescribe, Nothing, (Ptr{JNIEnv},), env)

export ExceptionClear
ExceptionClear(env::Ptr{JNIEnv}) =
  ccall(Main.JavaCall.jnifunc.ExceptionClear, Nothing, (Ptr{JNIEnv},), env)

export FatalError
FatalError(env::Ptr{JNIEnv}, msg::AbstractString) =
  ccall(Main.JavaCall.jnifunc.FatalError, Nothing, (Ptr{JNIEnv}, Cstring,), env, String(msg))

export PushLocalFrame
PushLocalFrame(env::Ptr{JNIEnv}, capacity::jint) =
  ccall(Main.JavaCall.jnifunc.PushLocalFrame, jint, (Ptr{JNIEnv}, jint,), env, capacity)

export PopLocalFrame
PopLocalFrame(env::Ptr{JNIEnv}, result::jobject) =
  ccall(Main.JavaCall.jnifunc.PopLocalFrame, jobject, (Ptr{JNIEnv}, jobject,), env, result)

export NewGlobalRef
NewGlobalRef(env::Ptr{JNIEnv}, lobj::jobject) =
  ccall(Main.JavaCall.jnifunc.NewGlobalRef, jobject, (Ptr{JNIEnv}, jobject,), env, lobj)

export DeleteGlobalRef
DeleteGlobalRef(env::Ptr{JNIEnv}, gref::jobject) =
  ccall(Main.JavaCall.jnifunc.DeleteGlobalRef, Nothing, (Ptr{JNIEnv}, jobject,), env, gref)

export DeleteLocalRef
DeleteLocalRef(env::Ptr{JNIEnv}, obj::jobject) =
  ccall(Main.JavaCall.jnifunc.DeleteLocalRef, Nothing, (Ptr{JNIEnv}, jobject,), env, obj)

export IsSameObject
IsSameObject(env::Ptr{JNIEnv}, obj1::jobject, obj2::jobject) =
  ccall(Main.JavaCall.jnifunc.IsSameObject, jboolean, (Ptr{JNIEnv}, jobject, jobject,), env, obj1, obj2)

export NewLocalRef
NewLocalRef(env::Ptr{JNIEnv}, ref::jobject) =
  ccall(Main.JavaCall.jnifunc.NewLocalRef, jobject, (Ptr{JNIEnv}, jobject,), env, ref)

export EnsureLocalCapacity
EnsureLocalCapacity(env::Ptr{JNIEnv}, capacity::jint) =
  ccall(Main.JavaCall.jnifunc.EnsureLocalCapacity, jint, (Ptr{JNIEnv}, jint,), env, capacity)

export AllocObject
AllocObject(env::Ptr{JNIEnv}, clazz::jclass) =
  ccall(Main.JavaCall.jnifunc.AllocObject, jobject, (Ptr{JNIEnv}, jclass,), env, clazz)

export NewObjectA
NewObjectA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.NewObjectA, jobject, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export GetObjectClass
GetObjectClass(env::Ptr{JNIEnv}, obj::jobject) =
  ccall(Main.JavaCall.jnifunc.GetObjectClass, jclass, (Ptr{JNIEnv}, jobject,), env, obj)

export IsInstanceOf
IsInstanceOf(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass) =
  ccall(Main.JavaCall.jnifunc.IsInstanceOf, jboolean, (Ptr{JNIEnv}, jobject, jclass,), env, obj, clazz)

export GetMethodID
GetMethodID(env::Ptr{JNIEnv}, clazz::jclass, name::AbstractString, sig::AbstractString) =
  ccall(Main.JavaCall.jnifunc.GetMethodID, jmethodID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), env, clazz, String(name), String(sig))

export CallObjectMethodA
CallObjectMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallObjectMethodA, jobject, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallBooleanMethodA
CallBooleanMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallBooleanMethodA, jboolean, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallByteMethodA
CallByteMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallByteMethodA, jbyte, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallCharMethodA
CallCharMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallCharMethodA, jchar, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallShortMethodA
CallShortMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallShortMethodA, jshort, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallIntMethodA
CallIntMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallIntMethodA, jint, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallLongMethodA
CallLongMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallLongMethodA, jlong, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallFloatMethodA
CallFloatMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallFloatMethodA, jfloat, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallDoubleMethodA
CallDoubleMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallDoubleMethodA, jdouble, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallVoidMethodA
CallVoidMethodA(env::Ptr{JNIEnv}, obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallVoidMethodA, Nothing, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), env, obj, methodID, args)

export CallNonvirtualObjectMethodA
CallNonvirtualObjectMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualObjectMethodA, jobject, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualBooleanMethodA
CallNonvirtualBooleanMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualBooleanMethodA, jboolean, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualByteMethodA
CallNonvirtualByteMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualByteMethodA, jbyte, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualCharMethodA
CallNonvirtualCharMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualCharMethodA, jchar, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualShortMethodA
CallNonvirtualShortMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualShortMethodA, jshort, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualIntMethodA
CallNonvirtualIntMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualIntMethodA, jint, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualLongMethodA
CallNonvirtualLongMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualLongMethodA, jlong, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualFloatMethodA
CallNonvirtualFloatMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualFloatMethodA, jfloat, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualDoubleMethodA
CallNonvirtualDoubleMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualDoubleMethodA, jdouble, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export CallNonvirtualVoidMethodA
CallNonvirtualVoidMethodA(env::Ptr{JNIEnv}, obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallNonvirtualVoidMethodA, Nothing, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), env, obj, clazz, methodID, args)

export GetFieldID
GetFieldID(env::Ptr{JNIEnv}, clazz::jclass, name::AbstractString, sig::AbstractString) =
  ccall(Main.JavaCall.jnifunc.GetFieldID, jfieldID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), env, clazz, String(name), String(sig))

export GetObjectField
GetObjectField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetObjectField, jobject, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetBooleanField
GetBooleanField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetBooleanField, jboolean, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetByteField
GetByteField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetByteField, jbyte, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetCharField
GetCharField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetCharField, jchar, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetShortField
GetShortField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetShortField, jshort, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetIntField
GetIntField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetIntField, jint, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetLongField
GetLongField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetLongField, jlong, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetFloatField
GetFloatField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetFloatField, jfloat, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export GetDoubleField
GetDoubleField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetDoubleField, jdouble, (Ptr{JNIEnv}, jobject, jfieldID,), env, obj, fieldID)

export SetObjectField
SetObjectField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jobject) =
  ccall(Main.JavaCall.jnifunc.SetObjectField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jobject,), env, obj, fieldID, val)

export SetBooleanField
SetBooleanField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jboolean) =
  ccall(Main.JavaCall.jnifunc.SetBooleanField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jboolean,), env, obj, fieldID, val)

export SetByteField
SetByteField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jbyte) =
  ccall(Main.JavaCall.jnifunc.SetByteField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jbyte,), env, obj, fieldID, val)

export SetCharField
SetCharField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jchar) =
  ccall(Main.JavaCall.jnifunc.SetCharField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jchar,), env, obj, fieldID, val)

export SetShortField
SetShortField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jshort) =
  ccall(Main.JavaCall.jnifunc.SetShortField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jshort,), env, obj, fieldID, val)

export SetIntField
SetIntField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jint) =
  ccall(Main.JavaCall.jnifunc.SetIntField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jint,), env, obj, fieldID, val)

export SetLongField
SetLongField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jlong) =
  ccall(Main.JavaCall.jnifunc.SetLongField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jlong,), env, obj, fieldID, val)

export SetFloatField
SetFloatField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jfloat) =
  ccall(Main.JavaCall.jnifunc.SetFloatField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jfloat,), env, obj, fieldID, val)

export SetDoubleField
SetDoubleField(env::Ptr{JNIEnv}, obj::jobject, fieldID::jfieldID, val::jdouble) =
  ccall(Main.JavaCall.jnifunc.SetDoubleField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jdouble,), env, obj, fieldID, val)

export GetStaticMethodID
GetStaticMethodID(env::Ptr{JNIEnv}, clazz::jclass, name::AbstractString, sig::AbstractString) =
  ccall(Main.JavaCall.jnifunc.GetStaticMethodID, jmethodID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), env, clazz, String(name), String(sig))

export CallStaticObjectMethodA
CallStaticObjectMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticObjectMethodA, jobject, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticBooleanMethodA
CallStaticBooleanMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticBooleanMethodA, jboolean, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticByteMethodA
CallStaticByteMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticByteMethodA, jbyte, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticCharMethodA
CallStaticCharMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticCharMethodA, jchar, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticShortMethodA
CallStaticShortMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticShortMethodA, jshort, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticIntMethodA
CallStaticIntMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticIntMethodA, jint, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticLongMethodA
CallStaticLongMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticLongMethodA, jlong, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticFloatMethodA
CallStaticFloatMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticFloatMethodA, jfloat, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticDoubleMethodA
CallStaticDoubleMethodA(env::Ptr{JNIEnv}, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticDoubleMethodA, jdouble, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, clazz, methodID, args)

export CallStaticVoidMethodA
CallStaticVoidMethodA(env::Ptr{JNIEnv}, cls::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(Main.JavaCall.jnifunc.CallStaticVoidMethodA, Nothing, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), env, cls, methodID, args)

export GetStaticFieldID
GetStaticFieldID(env::Ptr{JNIEnv}, clazz::jclass, name::AbstractString, sig::AbstractString) =
  ccall(Main.JavaCall.jnifunc.GetStaticFieldID, jfieldID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), env, clazz, String(name), String(sig))

export GetStaticObjectField
GetStaticObjectField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticObjectField, jobject, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticBooleanField
GetStaticBooleanField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticBooleanField, jboolean, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticByteField
GetStaticByteField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticByteField, jbyte, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticCharField
GetStaticCharField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticCharField, jchar, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticShortField
GetStaticShortField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticShortField, jshort, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticIntField
GetStaticIntField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticIntField, jint, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticLongField
GetStaticLongField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticLongField, jlong, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticFloatField
GetStaticFloatField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticFloatField, jfloat, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export GetStaticDoubleField
GetStaticDoubleField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID) =
  ccall(Main.JavaCall.jnifunc.GetStaticDoubleField, jdouble, (Ptr{JNIEnv}, jclass, jfieldID,), env, clazz, fieldID)

export SetStaticObjectField
SetStaticObjectField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jobject) =
  ccall(Main.JavaCall.jnifunc.SetStaticObjectField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jobject,), env, clazz, fieldID, value)

export SetStaticBooleanField
SetStaticBooleanField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jboolean) =
  ccall(Main.JavaCall.jnifunc.SetStaticBooleanField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jboolean,), env, clazz, fieldID, value)

export SetStaticByteField
SetStaticByteField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jbyte) =
  ccall(Main.JavaCall.jnifunc.SetStaticByteField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jbyte,), env, clazz, fieldID, value)

export SetStaticCharField
SetStaticCharField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jchar) =
  ccall(Main.JavaCall.jnifunc.SetStaticCharField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jchar,), env, clazz, fieldID, value)

export SetStaticShortField
SetStaticShortField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jshort) =
  ccall(Main.JavaCall.jnifunc.SetStaticShortField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jshort,), env, clazz, fieldID, value)

export SetStaticIntField
SetStaticIntField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jint) =
  ccall(Main.JavaCall.jnifunc.SetStaticIntField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jint,), env, clazz, fieldID, value)

export SetStaticLongField
SetStaticLongField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jlong) =
  ccall(Main.JavaCall.jnifunc.SetStaticLongField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jlong,), env, clazz, fieldID, value)

export SetStaticFloatField
SetStaticFloatField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jfloat) =
  ccall(Main.JavaCall.jnifunc.SetStaticFloatField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jfloat,), env, clazz, fieldID, value)

export SetStaticDoubleField
SetStaticDoubleField(env::Ptr{JNIEnv}, clazz::jclass, fieldID::jfieldID, value::jdouble) =
  ccall(Main.JavaCall.jnifunc.SetStaticDoubleField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jdouble,), env, clazz, fieldID, value)

export NewString
NewString(env::Ptr{JNIEnv}, unicode::Array{jchar,1}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewString, jstring, (Ptr{JNIEnv}, Ptr{jchar}, jsize,), env, unicode, len)

export GetStringLength
GetStringLength(env::Ptr{JNIEnv}, str::jstring) =
  ccall(Main.JavaCall.jnifunc.GetStringLength, jsize, (Ptr{JNIEnv}, jstring,), env, str)

export GetStringChars
GetStringChars(env::Ptr{JNIEnv}, str::jstring, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetStringChars, Ptr{jchar}, (Ptr{JNIEnv}, jstring, Ptr{jboolean},), env, str, isCopy)

export ReleaseStringChars
ReleaseStringChars(env::Ptr{JNIEnv}, str::jstring, chars::Array{jchar,1}) =
  ccall(Main.JavaCall.jnifunc.ReleaseStringChars, Nothing, (Ptr{JNIEnv}, jstring, Ptr{jchar},), env, str, chars)

export NewStringUTF
NewStringUTF(env::Ptr{JNIEnv}, utf::AbstractString) =
  ccall(Main.JavaCall.jnifunc.NewStringUTF, jstring, (Ptr{JNIEnv}, Cstring,), env, String(utf))

export GetStringUTFLength
GetStringUTFLength(env::Ptr{JNIEnv}, str::jstring) =
  ccall(Main.JavaCall.jnifunc.GetStringUTFLength, jsize, (Ptr{JNIEnv}, jstring,), env, str)

export GetStringUTFChars
GetStringUTFChars(env::Ptr{JNIEnv}, str::jstring, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetStringUTFChars, Cstring, (Ptr{JNIEnv}, jstring, Ptr{jboolean},), env, str, isCopy)

export ReleaseStringUTFChars
ReleaseStringUTFChars(env::Ptr{JNIEnv}, str::jstring, chars::Ptr{UInt8}) =
  ccall(Main.JavaCall.jnifunc.ReleaseStringUTFChars, Nothing, (Ptr{JNIEnv}, jstring, Ptr{UInt8},), env, str, chars)

export GetArrayLength
GetArrayLength(env::Ptr{JNIEnv}, array::jarray) =
  ccall(Main.JavaCall.jnifunc.GetArrayLength, jsize, (Ptr{JNIEnv}, jarray,), env, array)

export NewObjectArray
NewObjectArray(env::Ptr{JNIEnv}, len::Integer, clazz::jclass, init::jobject) =
  ccall(Main.JavaCall.jnifunc.NewObjectArray, jobjectArray, (Ptr{JNIEnv}, jsize, jclass, jobject,), env, len, clazz, init)

export GetObjectArrayElement
GetObjectArrayElement(env::Ptr{JNIEnv}, array::jobjectArray, index::Integer) =
  ccall(Main.JavaCall.jnifunc.GetObjectArrayElement, jobject, (Ptr{JNIEnv}, jobjectArray, jsize,), env, array, index)

export SetObjectArrayElement
SetObjectArrayElement(env::Ptr{JNIEnv}, array::jobjectArray, index::Integer, val::jobject) =
  ccall(Main.JavaCall.jnifunc.SetObjectArrayElement, Nothing, (Ptr{JNIEnv}, jobjectArray, jsize, jobject,), env, array, index, val)

export NewBooleanArray
NewBooleanArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewBooleanArray, jbooleanArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewByteArray
NewByteArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewByteArray, jbyteArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewCharArray
NewCharArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewCharArray, jcharArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewShortArray
NewShortArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewShortArray, jshortArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewIntArray
NewIntArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewIntArray, jintArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewLongArray
NewLongArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewLongArray, jlongArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewFloatArray
NewFloatArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewFloatArray, jfloatArray, (Ptr{JNIEnv}, jsize,), env, len)

export NewDoubleArray
NewDoubleArray(env::Ptr{JNIEnv}, len::Integer) =
  ccall(Main.JavaCall.jnifunc.NewDoubleArray, jdoubleArray, (Ptr{JNIEnv}, jsize,), env, len)

export GetBooleanArrayElements
GetBooleanArrayElements(env::Ptr{JNIEnv}, array::jbooleanArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetBooleanArrayElements, Ptr{jboolean}, (Ptr{JNIEnv}, jbooleanArray, Ptr{jboolean},), env, array, isCopy)

export GetByteArrayElements
GetByteArrayElements(env::Ptr{JNIEnv}, array::jbyteArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetByteArrayElements, Ptr{jbyte}, (Ptr{JNIEnv}, jbyteArray, Ptr{jboolean},), env, array, isCopy)

export GetCharArrayElements
GetCharArrayElements(env::Ptr{JNIEnv}, array::jcharArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetCharArrayElements, Ptr{jchar}, (Ptr{JNIEnv}, jcharArray, Ptr{jboolean},), env, array, isCopy)

export GetShortArrayElements
GetShortArrayElements(env::Ptr{JNIEnv}, array::jshortArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetShortArrayElements, Ptr{jshort}, (Ptr{JNIEnv}, jshortArray, Ptr{jboolean},), env, array, isCopy)

export GetIntArrayElements
GetIntArrayElements(env::Ptr{JNIEnv}, array::jintArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetIntArrayElements, Ptr{jint}, (Ptr{JNIEnv}, jintArray, Ptr{jboolean},), env, array, isCopy)

export GetLongArrayElements
GetLongArrayElements(env::Ptr{JNIEnv}, array::jlongArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetLongArrayElements, Ptr{jlong}, (Ptr{JNIEnv}, jlongArray, Ptr{jboolean},), env, array, isCopy)

export GetFloatArrayElements
GetFloatArrayElements(env::Ptr{JNIEnv}, array::jfloatArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetFloatArrayElements, Ptr{jfloat}, (Ptr{JNIEnv}, jfloatArray, Ptr{jboolean},), env, array, isCopy)

export GetDoubleArrayElements
GetDoubleArrayElements(env::Ptr{JNIEnv}, array::jdoubleArray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetDoubleArrayElements, Ptr{jdouble}, (Ptr{JNIEnv}, jdoubleArray, Ptr{jboolean},), env, array, isCopy)

export ReleaseBooleanArrayElements
ReleaseBooleanArrayElements(env::Ptr{JNIEnv}, array::jbooleanArray, elems::Array{jboolean,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseBooleanArrayElements, Nothing, (Ptr{JNIEnv}, jbooleanArray, Ptr{jboolean}, jint,), env, array, elems, mode)

export ReleaseByteArrayElements
ReleaseByteArrayElements(env::Ptr{JNIEnv}, array::jbyteArray, elems::Array{jbyte,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseByteArrayElements, Nothing, (Ptr{JNIEnv}, jbyteArray, Ptr{jbyte}, jint,), env, array, elems, mode)

export ReleaseCharArrayElements
ReleaseCharArrayElements(env::Ptr{JNIEnv}, array::jcharArray, elems::Array{jchar,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseCharArrayElements, Nothing, (Ptr{JNIEnv}, jcharArray, Ptr{jchar}, jint,), env, array, elems, mode)

export ReleaseShortArrayElements
ReleaseShortArrayElements(env::Ptr{JNIEnv}, array::jshortArray, elems::Array{jshort,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseShortArrayElements, Nothing, (Ptr{JNIEnv}, jshortArray, Ptr{jshort}, jint,), env, array, elems, mode)

export ReleaseIntArrayElements
ReleaseIntArrayElements(env::Ptr{JNIEnv}, array::jintArray, elems::Array{jint,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseIntArrayElements, Nothing, (Ptr{JNIEnv}, jintArray, Ptr{jint}, jint,), env, array, elems, mode)

export ReleaseLongArrayElements
ReleaseLongArrayElements(env::Ptr{JNIEnv}, array::jlongArray, elems::Array{jlong,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseLongArrayElements, Nothing, (Ptr{JNIEnv}, jlongArray, Ptr{jlong}, jint,), env, array, elems, mode)

export ReleaseFloatArrayElements
ReleaseFloatArrayElements(env::Ptr{JNIEnv}, array::jfloatArray, elems::Array{jfloat,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseFloatArrayElements, Nothing, (Ptr{JNIEnv}, jfloatArray, Ptr{jfloat}, jint,), env, array, elems, mode)

export ReleaseDoubleArrayElements
ReleaseDoubleArrayElements(env::Ptr{JNIEnv}, array::jdoubleArray, elems::Array{jdouble,1}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleaseDoubleArrayElements, Nothing, (Ptr{JNIEnv}, jdoubleArray, Ptr{jdouble}, jint,), env, array, elems, mode)

export GetBooleanArrayRegion
GetBooleanArrayRegion(env::Ptr{JNIEnv}, array::jbooleanArray, start::Integer, l::Integer, buf::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetBooleanArrayRegion, Nothing, (Ptr{JNIEnv}, jbooleanArray, jsize, jsize, Ptr{jboolean},), env, array, start, l, buf)

export GetByteArrayRegion
GetByteArrayRegion(env::Ptr{JNIEnv}, array::jbyteArray, start::Integer, len::Integer, buf::Array{jbyte,1}) =
  ccall(Main.JavaCall.jnifunc.GetByteArrayRegion, Nothing, (Ptr{JNIEnv}, jbyteArray, jsize, jsize, Ptr{jbyte},), env, array, start, len, buf)

export GetCharArrayRegion
GetCharArrayRegion(env::Ptr{JNIEnv}, array::jcharArray, start::Integer, len::Integer, buf::Array{jchar,1}) =
  ccall(Main.JavaCall.jnifunc.GetCharArrayRegion, Nothing, (Ptr{JNIEnv}, jcharArray, jsize, jsize, Ptr{jchar},), env, array, start, len, buf)

export GetShortArrayRegion
GetShortArrayRegion(env::Ptr{JNIEnv}, array::jshortArray, start::Integer, len::Integer, buf::Array{jshort,1}) =
  ccall(Main.JavaCall.jnifunc.GetShortArrayRegion, Nothing, (Ptr{JNIEnv}, jshortArray, jsize, jsize, Ptr{jshort},), env, array, start, len, buf)

export GetIntArrayRegion
GetIntArrayRegion(env::Ptr{JNIEnv}, array::jintArray, start::Integer, len::Integer, buf::Array{jint,1}) =
  ccall(Main.JavaCall.jnifunc.GetIntArrayRegion, Nothing, (Ptr{JNIEnv}, jintArray, jsize, jsize, Ptr{jint},), env, array, start, len, buf)

export GetLongArrayRegion
GetLongArrayRegion(env::Ptr{JNIEnv}, array::jlongArray, start::Integer, len::Integer, buf::Array{jlong,1}) =
  ccall(Main.JavaCall.jnifunc.GetLongArrayRegion, Nothing, (Ptr{JNIEnv}, jlongArray, jsize, jsize, Ptr{jlong},), env, array, start, len, buf)

export GetFloatArrayRegion
GetFloatArrayRegion(env::Ptr{JNIEnv}, array::jfloatArray, start::Integer, len::Integer, buf::Array{jfloat,1}) =
  ccall(Main.JavaCall.jnifunc.GetFloatArrayRegion, Nothing, (Ptr{JNIEnv}, jfloatArray, jsize, jsize, Ptr{jfloat},), env, array, start, len, buf)

export GetDoubleArrayRegion
GetDoubleArrayRegion(env::Ptr{JNIEnv}, array::jdoubleArray, start::Integer, len::Integer, buf::Array{jdouble,1}) =
  ccall(Main.JavaCall.jnifunc.GetDoubleArrayRegion, Nothing, (Ptr{JNIEnv}, jdoubleArray, jsize, jsize, Ptr{jdouble},), env, array, start, len, buf)

export SetBooleanArrayRegion
SetBooleanArrayRegion(env::Ptr{JNIEnv}, array::jbooleanArray, start::Integer, l::Integer, buf::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.SetBooleanArrayRegion, Nothing, (Ptr{JNIEnv}, jbooleanArray, jsize, jsize, Ptr{jboolean},), env, array, start, l, buf)

export SetByteArrayRegion
SetByteArrayRegion(env::Ptr{JNIEnv}, array::jbyteArray, start::Integer, len::Integer, buf::Array{jbyte,1}) =
  ccall(Main.JavaCall.jnifunc.SetByteArrayRegion, Nothing, (Ptr{JNIEnv}, jbyteArray, jsize, jsize, Ptr{jbyte},), env, array, start, len, buf)

export SetCharArrayRegion
SetCharArrayRegion(env::Ptr{JNIEnv}, array::jcharArray, start::Integer, len::Integer, buf::Array{jchar,1}) =
  ccall(Main.JavaCall.jnifunc.SetCharArrayRegion, Nothing, (Ptr{JNIEnv}, jcharArray, jsize, jsize, Ptr{jchar},), env, array, start, len, buf)

export SetShortArrayRegion
SetShortArrayRegion(env::Ptr{JNIEnv}, array::jshortArray, start::Integer, len::Integer, buf::Array{jshort,1}) =
  ccall(Main.JavaCall.jnifunc.SetShortArrayRegion, Nothing, (Ptr{JNIEnv}, jshortArray, jsize, jsize, Ptr{jshort},), env, array, start, len, buf)

export SetIntArrayRegion
SetIntArrayRegion(env::Ptr{JNIEnv}, array::jintArray, start::Integer, len::Integer, buf::Array{jint,1}) =
  ccall(Main.JavaCall.jnifunc.SetIntArrayRegion, Nothing, (Ptr{JNIEnv}, jintArray, jsize, jsize, Ptr{jint},), env, array, start, len, buf)

export SetLongArrayRegion
SetLongArrayRegion(env::Ptr{JNIEnv}, array::jlongArray, start::Integer, len::Integer, buf::Array{jlong,1}) =
  ccall(Main.JavaCall.jnifunc.SetLongArrayRegion, Nothing, (Ptr{JNIEnv}, jlongArray, jsize, jsize, Ptr{jlong},), env, array, start, len, buf)

export SetFloatArrayRegion
SetFloatArrayRegion(env::Ptr{JNIEnv}, array::jfloatArray, start::Integer, len::Integer, buf::Array{jfloat,1}) =
  ccall(Main.JavaCall.jnifunc.SetFloatArrayRegion, Nothing, (Ptr{JNIEnv}, jfloatArray, jsize, jsize, Ptr{jfloat},), env, array, start, len, buf)

export SetDoubleArrayRegion
SetDoubleArrayRegion(env::Ptr{JNIEnv}, array::jdoubleArray, start::Integer, len::Integer, buf::Array{jdouble,1}) =
  ccall(Main.JavaCall.jnifunc.SetDoubleArrayRegion, Nothing, (Ptr{JNIEnv}, jdoubleArray, jsize, jsize, Ptr{jdouble},), env, array, start, len, buf)

export RegisterNatives
RegisterNatives(env::Ptr{JNIEnv}, clazz::jclass, methods::Array{JNINativeMethod,1}, nMethods::jint) =
  ccall(Main.JavaCall.jnifunc.RegisterNatives, jint, (Ptr{JNIEnv}, jclass, Ptr{JNINativeMethod}, jint,), env, clazz, methods, nMethods)

export UnregisterNatives
UnregisterNatives(env::Ptr{JNIEnv}, clazz::jclass) =
  ccall(Main.JavaCall.jnifunc.UnregisterNatives, jint, (Ptr{JNIEnv}, jclass,), env, clazz)

export MonitorEnter
MonitorEnter(env::Ptr{JNIEnv}, obj::jobject) =
  ccall(Main.JavaCall.jnifunc.MonitorEnter, jint, (Ptr{JNIEnv}, jobject,), env, obj)

export MonitorExit
MonitorExit(env::Ptr{JNIEnv}, obj::jobject) =
  ccall(Main.JavaCall.jnifunc.MonitorExit, jint, (Ptr{JNIEnv}, jobject,), env, obj)

export GetJavaVM
GetJavaVM(env::Ptr{JNIEnv}, vm::Array{JavaVM,1}) =
  ccall(Main.JavaCall.jnifunc.GetJavaVM, jint, (Ptr{JNIEnv}, Array{JavaVM,1},), env, vm)

export GetStringRegion
GetStringRegion(env::Ptr{JNIEnv}, str::jstring, start::Integer, len::Integer, buf::Array{jchar,1}) =
  ccall(Main.JavaCall.jnifunc.GetStringRegion, Nothing, (Ptr{JNIEnv}, jstring, jsize, jsize, Ptr{jchar},), env, str, start, len, buf)

export GetStringUTFRegion
GetStringUTFRegion(env::Ptr{JNIEnv}, str::jstring, start::Integer, len::Integer, buf::AbstractString) =
  ccall(Main.JavaCall.jnifunc.GetStringUTFRegion, Nothing, (Ptr{JNIEnv}, jstring, jsize, jsize, Cstring,), env, str, start, len, String(buf))

export GetPrimitiveArrayCritical
GetPrimitiveArrayCritical(env::Ptr{JNIEnv}, array::jarray, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetPrimitiveArrayCritical, Ptr{Nothing}, (Ptr{JNIEnv}, jarray, Ptr{jboolean},), env, array, isCopy)

export ReleasePrimitiveArrayCritical
ReleasePrimitiveArrayCritical(env::Ptr{JNIEnv}, array::jarray, carray::Ptr{Nothing}, mode::jint) =
  ccall(Main.JavaCall.jnifunc.ReleasePrimitiveArrayCritical, Nothing, (Ptr{JNIEnv}, jarray, Ptr{Nothing}, jint,), env, array, carray, mode)

export GetStringCritical
GetStringCritical(env::Ptr{JNIEnv}, string::jstring, isCopy::Array{jboolean,1}) =
  ccall(Main.JavaCall.jnifunc.GetStringCritical, Ptr{jchar}, (Ptr{JNIEnv}, jstring, Ptr{jboolean},), env, string, isCopy)

export ReleaseStringCritical
ReleaseStringCritical(env::Ptr{JNIEnv}, string::jstring, cstring::Array{jchar,1}) =
  ccall(Main.JavaCall.jnifunc.ReleaseStringCritical, Nothing, (Ptr{JNIEnv}, jstring, Ptr{jchar},), env, string, cstring)

export NewWeakGlobalRef
NewWeakGlobalRef(env::Ptr{JNIEnv}, obj::jobject) =
  ccall(Main.JavaCall.jnifunc.NewWeakGlobalRef, jweak, (Ptr{JNIEnv}, jobject,), env, obj)

export DeleteWeakGlobalRef
DeleteWeakGlobalRef(env::Ptr{JNIEnv}, ref::jweak) =
  ccall(Main.JavaCall.jnifunc.DeleteWeakGlobalRef, Nothing, (Ptr{JNIEnv}, jweak,), env, ref)

export ExceptionCheck
ExceptionCheck(env::Ptr{JNIEnv}) =
  ccall(Main.JavaCall.jnifunc.ExceptionCheck, jboolean, (Ptr{JNIEnv},), env)

export NewDirectByteBuffer
NewDirectByteBuffer(env::Ptr{JNIEnv}, address::Ptr{Nothing}, capacity::jlong) =
  ccall(Main.JavaCall.jnifunc.NewDirectByteBuffer, jobject, (Ptr{JNIEnv}, Ptr{Nothing}, jlong,), env, address, capacity)

export GetDirectBufferAddress
GetDirectBufferAddress(env::Ptr{JNIEnv}, buf::jobject) =
  ccall(Main.JavaCall.jnifunc.GetDirectBufferAddress, Ptr{Nothing}, (Ptr{JNIEnv}, jobject,), env, buf)

export GetDirectBufferCapacity
GetDirectBufferCapacity(env::Ptr{JNIEnv}, buf::jobject) =
  ccall(Main.JavaCall.jnifunc.GetDirectBufferCapacity, jlong, (Ptr{JNIEnv}, jobject,), env, buf)

export GetObjectRefType
GetObjectRefType(env::Ptr{JNIEnv}, obj::jobject) =
  ccall(Main.JavaCall.jnifunc.GetObjectRefType, jobjectRefType, (Ptr{JNIEnv}, jobject,), env, obj)

end
