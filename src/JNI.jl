module JNI

import Libdl

# jnienv.jl exports
export JNINativeInterface, JNIEnv, JNIInvokeInterface, JavaVM
# jni_md.h exports
export jint, jlong, jbyte
# jni.h exports
export jboolean, jchar, jshort, jfloat, jdouble, jsize, jprimitive
# constant export
export JNI_TRUE, JNI_FALSE
export JNI_VERSION_1_1, JNI_VERSION_1_2, JNI_VERSION_1_4, JNI_VERSION_1_6, JNI_VERSION_1_8
# export JNI_VERSION_9, JNI_VERSION_10 # Intentionally excluded, use JNI.JNI_VERSION_9
export JNI_OK, JNI_ERR, JNI_EDETACHED, JNI_EVERSION, JNI_ENOMEM, JNI_EEXIST, JNI_EINV
# Legacy exports
export jnifunc

include("jnienv.jl")

const jniref = Ref(JNINativeInterface())
global jnifunc

const penv = Ref(Ptr{JNIEnv}(C_NULL))
const pjvm = Ref(Ptr{JavaVM}(C_NULL))
const jvmfunc = Ref{JNIInvokeInterface}()

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

const JNI_VERSION_1_1 = convert(Cint, 0x00010001)
const JNI_VERSION_1_2 = convert(Cint, 0x00010002)
const JNI_VERSION_1_4 = convert(Cint, 0x00010004)
const JNI_VERSION_1_6 = convert(Cint, 0x00010006)
const JNI_VERSION_1_8 = convert(Cint, 0x00010008)
const JNI_VERSION_9   = convert(Cint, 0x00090000)
const JNI_VERSION_10  = convert(Cint, 0x000a0000)

const JNI_TRUE = convert(Cchar, 1)
const JNI_FALSE = convert(Cchar, 0)

# Return Values
const JNI_OK           = convert(Cint, 0)               #/* success */
const JNI_ERR          = convert(Cint, -1)              #/* unknown error */
const JNI_EDETACHED    = convert(Cint, -2)              #/* thread detached from the VM */
const JNI_EVERSION     = convert(Cint, -3)              #/* JNI version error */
const JNI_ENOMEM       = convert(Cint, -4)              #/* not enough memory */
const JNI_EEXIST       = convert(Cint, -5)              #/* VM already created */
const JNI_EINVAL       = convert(Cint, -6)              #/* invalid arguments */

# There is likely over specification here
PtrIsCopy = Union{Ptr{jboolean},Ref{jboolean},Array{jboolean,}}
AnyString = Union{AbstractString,Cstring,Ptr{UInt8}}

struct JNIError <: Exception
    msg::String
end

struct JavaVMOption
    optionString::Ptr{UInt8}
    extraInfo::Ptr{Nothing}
end

struct JavaVMInitArgs
    version::Cint
    nOptions::Cint
    options::Ptr{JavaVMOption}
    ignoreUnrecognized::Cchar
end

function load_jni(penv::Ptr{JNIEnv})
    jnienv = unsafe_load(penv)
    jniref[] = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
    global jnifunc = jniref[]
end
is_jni_loaded() = jniref[].GetVersion != C_NULL
is_env_loaded() = penv[] != C_NULL


"""
    init_new_vm(opts)

Initialize a new Java virtual machine.
"""
function init_new_vm(libpath,opts)
    libjvm = load_libjvm(libpath)
    create = Libdl.dlsym(libjvm, :JNI_CreateJavaVM)
    opt = [JavaVMOption(pointer(x), C_NULL) for x in opts]
    vm_args = JavaVMInitArgs(JNI_VERSION_1_8, convert(Cint, length(opts)),
                             convert(Ptr{JavaVMOption}, pointer(opt)), JNI_TRUE)
    res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), pjvm, penv,
                Ref(vm_args))
    res < 0 && throw(JNIError("Unable to initialise Java VM: $(res)"))
    jvm = unsafe_load(pjvm[])
    global jvmfunc[] = unsafe_load(jvm.JNIInvokeInterface_)
    JNI.load_jni(penv[])
    return
end

"""
    init_current_vm()

Allow initialization from running VM. Uses the first VM it finds.
"""
function init_current_vm(libpath)
    libjvm = load_libjvm(libpath)
    pnum = Array{Cint}(undef, 1)
    ccall(Libdl.dlsym(libjvm, :JNI_GetCreatedJavaVMs), Cint, (Ptr{Ptr{JavaVM}}, Cint, Ptr{Cint}), pjvm, 1, pnum)
    jvm = unsafe_load(pjvm[])
    global jvmfunc[] = unsafe_load(jvm.JNIInvokeInterface_)
    ccall(jvmfunc[].GetEnv, Cint, (Ptr{Nothing}, Ptr{Ptr{JNIEnv}}, Cint), pjvm[], penv, JNI.JNI_VERSION_1_8)
    JNI.load_jni(penv)
end

function load_libjvm(libpath::AbstractString)
    libjvm = Libdl.dlopen(libpath)
    @debug("Loaded $libpath")
    libjvm
end

function load_libjvm(libpaths::NTuple{N,String}) where N
    Libdl.dlopen.(libpaths)
    load_libjvm(libpaths[end])
end

function destroy()
    if !is_env_loaded()
        throw(JNIError("Called destroy without initialising Java VM"))
    end
    res = ccall(jvmfunc[].DestroyJavaVM, Cint, (Ptr{Nothing},), pjvm[])
    res < 0 && throw(JavaCallError("Unable to destroy Java VM"))
    penv[] = C_NULL
    pjvm[] = C_NULL
    nothing
end


# === Below Generated by make_jni2.jl ===

GetVersion() =
  ccall(jniref[].GetVersion, jint, (Ptr{JNIEnv},), penv[])

DefineClass(name::AnyString, loader::jobject, buf::Array{jbyte,1}, len::Integer) =
  ccall(jniref[].DefineClass, jclass, (Ptr{JNIEnv}, Cstring, jobject, Ptr{jbyte}, jsize,), penv[], name, loader, buf, len)

FindClass(name::AnyString) =
  ccall(jniref[].FindClass, jclass, (Ptr{JNIEnv}, Cstring,), penv[], name)

FromReflectedMethod(method::jobject) =
  ccall(jniref[].FromReflectedMethod, jmethodID, (Ptr{JNIEnv}, jobject,), penv[], method)

FromReflectedField(field::jobject) =
  ccall(jniref[].FromReflectedField, jfieldID, (Ptr{JNIEnv}, jobject,), penv[], field)

ToReflectedMethod(cls::jclass, methodID::jmethodID, isStatic::jboolean) =
  ccall(jniref[].ToReflectedMethod, jobject, (Ptr{JNIEnv}, jclass, jmethodID, jboolean,), penv[], cls, methodID, isStatic)

GetSuperclass(sub::jclass) =
  ccall(jniref[].GetSuperclass, jclass, (Ptr{JNIEnv}, jclass,), penv[], sub)

IsAssignableFrom(sub::jclass, sup::jclass) =
  ccall(jniref[].IsAssignableFrom, jboolean, (Ptr{JNIEnv}, jclass, jclass,), penv[], sub, sup)

ToReflectedField(cls::jclass, fieldID::jfieldID, isStatic::jboolean) =
  ccall(jniref[].ToReflectedField, jobject, (Ptr{JNIEnv}, jclass, jfieldID, jboolean,), penv[], cls, fieldID, isStatic)

Throw(obj::jthrowable) =
  ccall(jniref[].Throw, jint, (Ptr{JNIEnv}, jthrowable,), penv[], obj)

ThrowNew(clazz::jclass, msg::AnyString) =
  ccall(jniref[].ThrowNew, jint, (Ptr{JNIEnv}, jclass, Cstring,), penv[], clazz, msg)

ExceptionOccurred() =
  ccall(jniref[].ExceptionOccurred, jthrowable, (Ptr{JNIEnv},), penv[])

ExceptionDescribe() =
  ccall(jniref[].ExceptionDescribe, Nothing, (Ptr{JNIEnv},), penv[])

ExceptionClear() =
  ccall(jniref[].ExceptionClear, Nothing, (Ptr{JNIEnv},), penv[])

FatalError(msg::AnyString) =
  ccall(jniref[].FatalError, Nothing, (Ptr{JNIEnv}, Cstring,), penv[], msg)

PushLocalFrame(capacity::jint) =
  ccall(jniref[].PushLocalFrame, jint, (Ptr{JNIEnv}, jint,), penv[], capacity)

PopLocalFrame(result::jobject) =
  ccall(jniref[].PopLocalFrame, jobject, (Ptr{JNIEnv}, jobject,), penv[], result)

NewGlobalRef(lobj::jobject) =
  ccall(jniref[].NewGlobalRef, jobject, (Ptr{JNIEnv}, jobject,), penv[], lobj)

DeleteGlobalRef(gref::jobject) =
  ccall(jniref[].DeleteGlobalRef, Nothing, (Ptr{JNIEnv}, jobject,), penv[], gref)

DeleteLocalRef(obj::jobject) =
  ccall(jniref[].DeleteLocalRef, Nothing, (Ptr{JNIEnv}, jobject,), penv[], obj)

IsSameObject(obj1::jobject, obj2::jobject) =
  ccall(jniref[].IsSameObject, jboolean, (Ptr{JNIEnv}, jobject, jobject,), penv[], obj1, obj2)

NewLocalRef(ref::jobject) =
  ccall(jniref[].NewLocalRef, jobject, (Ptr{JNIEnv}, jobject,), penv[], ref)

EnsureLocalCapacity(capacity::jint) =
  ccall(jniref[].EnsureLocalCapacity, jint, (Ptr{JNIEnv}, jint,), penv[], capacity)

AllocObject(clazz::jclass) =
  ccall(jniref[].AllocObject, jobject, (Ptr{JNIEnv}, jclass,), penv[], clazz)

NewObjectA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].NewObjectA, jobject, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

GetObjectClass(obj::jobject) =
  ccall(jniref[].GetObjectClass, jclass, (Ptr{JNIEnv}, jobject,), penv[], obj)

IsInstanceOf(obj::jobject, clazz::jclass) =
  ccall(jniref[].IsInstanceOf, jboolean, (Ptr{JNIEnv}, jobject, jclass,), penv[], obj, clazz)

GetMethodID(clazz::jclass, name::AnyString, sig::AnyString) =
  ccall(jniref[].GetMethodID, jmethodID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), penv[], clazz, name, sig)

CallObjectMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallObjectMethodA, jobject, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallBooleanMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallBooleanMethodA, jboolean, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallByteMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallByteMethodA, jbyte, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallCharMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallCharMethodA, jchar, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallShortMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallShortMethodA, jshort, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallIntMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallIntMethodA, jint, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallLongMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallLongMethodA, jlong, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallFloatMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallFloatMethodA, jfloat, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallDoubleMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallDoubleMethodA, jdouble, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallVoidMethodA(obj::jobject, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallVoidMethodA, Nothing, (Ptr{JNIEnv}, jobject, jmethodID, Ptr{jvalue},), penv[], obj, methodID, args)

CallNonvirtualObjectMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualObjectMethodA, jobject, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualBooleanMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualBooleanMethodA, jboolean, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualByteMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualByteMethodA, jbyte, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualCharMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualCharMethodA, jchar, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualShortMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualShortMethodA, jshort, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualIntMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualIntMethodA, jint, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualLongMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualLongMethodA, jlong, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualFloatMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualFloatMethodA, jfloat, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualDoubleMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualDoubleMethodA, jdouble, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

CallNonvirtualVoidMethodA(obj::jobject, clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallNonvirtualVoidMethodA, Nothing, (Ptr{JNIEnv}, jobject, jclass, jmethodID, Ptr{jvalue},), penv[], obj, clazz, methodID, args)

GetFieldID(clazz::jclass, name::AnyString, sig::AnyString) =
  ccall(jniref[].GetFieldID, jfieldID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), penv[], clazz, name, sig)

GetObjectField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetObjectField, jobject, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetBooleanField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetBooleanField, jboolean, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetByteField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetByteField, jbyte, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetCharField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetCharField, jchar, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetShortField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetShortField, jshort, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetIntField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetIntField, jint, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetLongField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetLongField, jlong, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetFloatField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetFloatField, jfloat, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

GetDoubleField(obj::jobject, fieldID::jfieldID) =
  ccall(jniref[].GetDoubleField, jdouble, (Ptr{JNIEnv}, jobject, jfieldID,), penv[], obj, fieldID)

SetObjectField(obj::jobject, fieldID::jfieldID, val::jobject) =
  ccall(jniref[].SetObjectField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jobject,), penv[], obj, fieldID, val)

SetBooleanField(obj::jobject, fieldID::jfieldID, val::jboolean) =
  ccall(jniref[].SetBooleanField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jboolean,), penv[], obj, fieldID, val)

SetByteField(obj::jobject, fieldID::jfieldID, val::jbyte) =
  ccall(jniref[].SetByteField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jbyte,), penv[], obj, fieldID, val)

SetCharField(obj::jobject, fieldID::jfieldID, val::jchar) =
  ccall(jniref[].SetCharField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jchar,), penv[], obj, fieldID, val)

SetShortField(obj::jobject, fieldID::jfieldID, val::jshort) =
  ccall(jniref[].SetShortField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jshort,), penv[], obj, fieldID, val)

SetIntField(obj::jobject, fieldID::jfieldID, val::jint) =
  ccall(jniref[].SetIntField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jint,), penv[], obj, fieldID, val)

SetLongField(obj::jobject, fieldID::jfieldID, val::jlong) =
  ccall(jniref[].SetLongField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jlong,), penv[], obj, fieldID, val)

SetFloatField(obj::jobject, fieldID::jfieldID, val::jfloat) =
  ccall(jniref[].SetFloatField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jfloat,), penv[], obj, fieldID, val)

SetDoubleField(obj::jobject, fieldID::jfieldID, val::jdouble) =
  ccall(jniref[].SetDoubleField, Nothing, (Ptr{JNIEnv}, jobject, jfieldID, jdouble,), penv[], obj, fieldID, val)

GetStaticMethodID(clazz::jclass, name::AnyString, sig::AnyString) =
  ccall(jniref[].GetStaticMethodID, jmethodID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), penv[], clazz, name, sig)

CallStaticObjectMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticObjectMethodA, jobject, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticBooleanMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticBooleanMethodA, jboolean, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticByteMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticByteMethodA, jbyte, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticCharMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticCharMethodA, jchar, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticShortMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticShortMethodA, jshort, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticIntMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticIntMethodA, jint, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticLongMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticLongMethodA, jlong, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticFloatMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticFloatMethodA, jfloat, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticDoubleMethodA(clazz::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticDoubleMethodA, jdouble, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], clazz, methodID, args)

CallStaticVoidMethodA(cls::jclass, methodID::jmethodID, args::Array{jvalue,1}) =
  ccall(jniref[].CallStaticVoidMethodA, Nothing, (Ptr{JNIEnv}, jclass, jmethodID, Ptr{jvalue},), penv[], cls, methodID, args)

GetStaticFieldID(clazz::jclass, name::AnyString, sig::AnyString) =
  ccall(jniref[].GetStaticFieldID, jfieldID, (Ptr{JNIEnv}, jclass, Cstring, Cstring,), penv[], clazz, name, sig)

GetStaticObjectField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticObjectField, jobject, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticBooleanField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticBooleanField, jboolean, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticByteField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticByteField, jbyte, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticCharField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticCharField, jchar, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticShortField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticShortField, jshort, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticIntField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticIntField, jint, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticLongField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticLongField, jlong, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticFloatField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticFloatField, jfloat, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

GetStaticDoubleField(clazz::jclass, fieldID::jfieldID) =
  ccall(jniref[].GetStaticDoubleField, jdouble, (Ptr{JNIEnv}, jclass, jfieldID,), penv[], clazz, fieldID)

SetStaticObjectField(clazz::jclass, fieldID::jfieldID, value::jobject) =
  ccall(jniref[].SetStaticObjectField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jobject,), penv[], clazz, fieldID, value)

SetStaticBooleanField(clazz::jclass, fieldID::jfieldID, value::jboolean) =
  ccall(jniref[].SetStaticBooleanField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jboolean,), penv[], clazz, fieldID, value)

SetStaticByteField(clazz::jclass, fieldID::jfieldID, value::jbyte) =
  ccall(jniref[].SetStaticByteField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jbyte,), penv[], clazz, fieldID, value)

SetStaticCharField(clazz::jclass, fieldID::jfieldID, value::jchar) =
  ccall(jniref[].SetStaticCharField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jchar,), penv[], clazz, fieldID, value)

SetStaticShortField(clazz::jclass, fieldID::jfieldID, value::jshort) =
  ccall(jniref[].SetStaticShortField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jshort,), penv[], clazz, fieldID, value)

SetStaticIntField(clazz::jclass, fieldID::jfieldID, value::jint) =
  ccall(jniref[].SetStaticIntField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jint,), penv[], clazz, fieldID, value)

SetStaticLongField(clazz::jclass, fieldID::jfieldID, value::jlong) =
  ccall(jniref[].SetStaticLongField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jlong,), penv[], clazz, fieldID, value)

SetStaticFloatField(clazz::jclass, fieldID::jfieldID, value::jfloat) =
  ccall(jniref[].SetStaticFloatField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jfloat,), penv[], clazz, fieldID, value)

SetStaticDoubleField(clazz::jclass, fieldID::jfieldID, value::jdouble) =
  ccall(jniref[].SetStaticDoubleField, Nothing, (Ptr{JNIEnv}, jclass, jfieldID, jdouble,), penv[], clazz, fieldID, value)

NewString(unicode::Array{jchar,1}, len::Integer) =
  ccall(jniref[].NewString, jstring, (Ptr{JNIEnv}, Ptr{jchar}, jsize,), penv[], unicode, len)

GetStringLength(str::jstring) =
  ccall(jniref[].GetStringLength, jsize, (Ptr{JNIEnv}, jstring,), penv[], str)

GetStringChars(str::jstring, isCopy::PtrIsCopy) =
  ccall(jniref[].GetStringChars, Ptr{jchar}, (Ptr{JNIEnv}, jstring, Ptr{jboolean},), penv[], str, isCopy)

ReleaseStringChars(str::jstring, chars::Array{jchar,1}) =
  ccall(jniref[].ReleaseStringChars, Nothing, (Ptr{JNIEnv}, jstring, Ptr{jchar},), penv[], str, chars)

NewStringUTF(utf::AnyString) =
  ccall(jniref[].NewStringUTF, jstring, (Ptr{JNIEnv}, Cstring,), penv[], utf)

GetStringUTFLength(str::jstring) =
  ccall(jniref[].GetStringUTFLength, jsize, (Ptr{JNIEnv}, jstring,), penv[], str)

GetStringUTFChars(str::jstring, isCopy::PtrIsCopy) =
  ccall(jniref[].GetStringUTFChars, Cstring, (Ptr{JNIEnv}, jstring, Ptr{jboolean},), penv[], str, isCopy)

## Prior to this module we used UInt8 instead of Cstring, must match return value of above
#ReleaseStringUTFChars(str::jstring, chars::Ptr{UInt8}) =
#  ccall(jniref[].ReleaseStringUTFChars, Nothing, (Ptr{JNIEnv}, jstring, Ptr{UInt8},), penv[], str, chars)
ReleaseStringUTFChars(str::jstring, chars::AnyString) =
  ccall(jniref[].ReleaseStringUTFChars, Nothing, (Ptr{JNIEnv}, jstring, Cstring,), penv[], str, chars)

GetArrayLength(array::jarray) =
  ccall(jniref[].GetArrayLength, jsize, (Ptr{JNIEnv}, jarray,), penv[], array)

NewObjectArray(len::Integer, clazz::jclass, init::jobject) =
  ccall(jniref[].NewObjectArray, jobjectArray, (Ptr{JNIEnv}, jsize, jclass, jobject,), penv[], len, clazz, init)

GetObjectArrayElement(array::jobjectArray, index::Integer) =
  ccall(jniref[].GetObjectArrayElement, jobject, (Ptr{JNIEnv}, jobjectArray, jsize,), penv[], array, index)

SetObjectArrayElement(array::jobjectArray, index::Integer, val::jobject) =
  ccall(jniref[].SetObjectArrayElement, Nothing, (Ptr{JNIEnv}, jobjectArray, jsize, jobject,), penv[], array, index, val)

NewBooleanArray(len::Integer) =
  ccall(jniref[].NewBooleanArray, jbooleanArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewByteArray(len::Integer) =
  ccall(jniref[].NewByteArray, jbyteArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewCharArray(len::Integer) =
  ccall(jniref[].NewCharArray, jcharArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewShortArray(len::Integer) =
  ccall(jniref[].NewShortArray, jshortArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewIntArray(len::Integer) =
  ccall(jniref[].NewIntArray, jintArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewLongArray(len::Integer) =
  ccall(jniref[].NewLongArray, jlongArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewFloatArray(len::Integer) =
  ccall(jniref[].NewFloatArray, jfloatArray, (Ptr{JNIEnv}, jsize,), penv[], len)

NewDoubleArray(len::Integer) =
  ccall(jniref[].NewDoubleArray, jdoubleArray, (Ptr{JNIEnv}, jsize,), penv[], len)

GetBooleanArrayElements(array::jbooleanArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetBooleanArrayElements, Ptr{jboolean}, (Ptr{JNIEnv}, jbooleanArray, Ptr{jboolean},), penv[], array, isCopy)

GetByteArrayElements(array::jbyteArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetByteArrayElements, Ptr{jbyte}, (Ptr{JNIEnv}, jbyteArray, Ptr{jboolean},), penv[], array, isCopy)

GetCharArrayElements(array::jcharArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetCharArrayElements, Ptr{jchar}, (Ptr{JNIEnv}, jcharArray, Ptr{jboolean},), penv[], array, isCopy)

GetShortArrayElements(array::jshortArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetShortArrayElements, Ptr{jshort}, (Ptr{JNIEnv}, jshortArray, Ptr{jboolean},), penv[], array, isCopy)

GetIntArrayElements(array::jintArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetIntArrayElements, Ptr{jint}, (Ptr{JNIEnv}, jintArray, Ptr{jboolean},), penv[], array, isCopy)

GetLongArrayElements(array::jlongArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetLongArrayElements, Ptr{jlong}, (Ptr{JNIEnv}, jlongArray, Ptr{jboolean},), penv[], array, isCopy)

GetFloatArrayElements(array::jfloatArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetFloatArrayElements, Ptr{jfloat}, (Ptr{JNIEnv}, jfloatArray, Ptr{jboolean},), penv[], array, isCopy)

GetDoubleArrayElements(array::jdoubleArray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetDoubleArrayElements, Ptr{jdouble}, (Ptr{JNIEnv}, jdoubleArray, Ptr{jboolean},), penv[], array, isCopy)

ReleaseBooleanArrayElements(array::jbooleanArray, elems::Ptr{jboolean}, mode::jint) =
  ccall(jniref[].ReleaseBooleanArrayElements, Nothing, (Ptr{JNIEnv}, jbooleanArray, Ptr{jboolean}, jint,), penv[], array, elems, mode)

ReleaseByteArrayElements(array::jbyteArray, elems::Ptr{jbyte}, mode::jint) =
  ccall(jniref[].ReleaseByteArrayElements, Nothing, (Ptr{JNIEnv}, jbyteArray, Ptr{jbyte}, jint,), penv[], array, elems, mode)

ReleaseCharArrayElements(array::jcharArray, elems::Ptr{jchar}, mode::jint) =
  ccall(jniref[].ReleaseCharArrayElements, Nothing, (Ptr{JNIEnv}, jcharArray, Ptr{jchar}, jint,), penv[], array, elems, mode)

ReleaseShortArrayElements(array::jshortArray, elems::Ptr{jshort}, mode::jint) =
  ccall(jniref[].ReleaseShortArrayElements, Nothing, (Ptr{JNIEnv}, jshortArray, Ptr{jshort}, jint,), penv[], array, elems, mode)

ReleaseIntArrayElements(array::jintArray, elems::Ptr{jint}, mode::jint) =
  ccall(jniref[].ReleaseIntArrayElements, Nothing, (Ptr{JNIEnv}, jintArray, Ptr{jint}, jint,), penv[], array, elems, mode)

ReleaseLongArrayElements(array::jlongArray, elems::Ptr{jlong}, mode::jint) =
  ccall(jniref[].ReleaseLongArrayElements, Nothing, (Ptr{JNIEnv}, jlongArray, Ptr{jlong}, jint,), penv[], array, elems, mode)

ReleaseFloatArrayElements(array::jfloatArray, elems::Ptr{jfloat}, mode::jint) =
  ccall(jniref[].ReleaseFloatArrayElements, Nothing, (Ptr{JNIEnv}, jfloatArray, Ptr{jfloat}, jint,), penv[], array, elems, mode)

ReleaseDoubleArrayElements(array::jdoubleArray, elems::Ptr{jdouble}, mode::jint) =
  ccall(jniref[].ReleaseDoubleArrayElements, Nothing, (Ptr{JNIEnv}, jdoubleArray, Ptr{jdouble}, jint,), penv[], array, elems, mode)

GetBooleanArrayRegion(array::jbooleanArray, start::Integer, l::Integer, buf::Array{jboolean,1}) =
  ccall(jniref[].GetBooleanArrayRegion, Nothing, (Ptr{JNIEnv}, jbooleanArray, jsize, jsize, Ptr{jboolean},), penv[], array, start, l, buf)

GetByteArrayRegion(array::jbyteArray, start::Integer, len::Integer, buf::Array{jbyte,1}) =
  ccall(jniref[].GetByteArrayRegion, Nothing, (Ptr{JNIEnv}, jbyteArray, jsize, jsize, Ptr{jbyte},), penv[], array, start, len, buf)

GetCharArrayRegion(array::jcharArray, start::Integer, len::Integer, buf::Array{jchar,1}) =
  ccall(jniref[].GetCharArrayRegion, Nothing, (Ptr{JNIEnv}, jcharArray, jsize, jsize, Ptr{jchar},), penv[], array, start, len, buf)

GetShortArrayRegion(array::jshortArray, start::Integer, len::Integer, buf::Array{jshort,1}) =
  ccall(jniref[].GetShortArrayRegion, Nothing, (Ptr{JNIEnv}, jshortArray, jsize, jsize, Ptr{jshort},), penv[], array, start, len, buf)

GetIntArrayRegion(array::jintArray, start::Integer, len::Integer, buf::Array{jint,1}) =
  ccall(jniref[].GetIntArrayRegion, Nothing, (Ptr{JNIEnv}, jintArray, jsize, jsize, Ptr{jint},), penv[], array, start, len, buf)

GetLongArrayRegion(array::jlongArray, start::Integer, len::Integer, buf::Array{jlong,1}) =
  ccall(jniref[].GetLongArrayRegion, Nothing, (Ptr{JNIEnv}, jlongArray, jsize, jsize, Ptr{jlong},), penv[], array, start, len, buf)

GetFloatArrayRegion(array::jfloatArray, start::Integer, len::Integer, buf::Array{jfloat,1}) =
  ccall(jniref[].GetFloatArrayRegion, Nothing, (Ptr{JNIEnv}, jfloatArray, jsize, jsize, Ptr{jfloat},), penv[], array, start, len, buf)

GetDoubleArrayRegion(array::jdoubleArray, start::Integer, len::Integer, buf::Array{jdouble,1}) =
  ccall(jniref[].GetDoubleArrayRegion, Nothing, (Ptr{JNIEnv}, jdoubleArray, jsize, jsize, Ptr{jdouble},), penv[], array, start, len, buf)

SetBooleanArrayRegion(array::jbooleanArray, start::Integer, l::Integer, buf::Array{jboolean,1}) =
  ccall(jniref[].SetBooleanArrayRegion, Nothing, (Ptr{JNIEnv}, jbooleanArray, jsize, jsize, Ptr{jboolean},), penv[], array, start, l, buf)

SetByteArrayRegion(array::jbyteArray, start::Integer, len::Integer, buf::Array{jbyte,1}) =
  ccall(jniref[].SetByteArrayRegion, Nothing, (Ptr{JNIEnv}, jbyteArray, jsize, jsize, Ptr{jbyte},), penv[], array, start, len, buf)

SetCharArrayRegion(array::jcharArray, start::Integer, len::Integer, buf::Array{jchar,1}) =
  ccall(jniref[].SetCharArrayRegion, Nothing, (Ptr{JNIEnv}, jcharArray, jsize, jsize, Ptr{jchar},), penv[], array, start, len, buf)

SetShortArrayRegion(array::jshortArray, start::Integer, len::Integer, buf::Array{jshort,1}) =
  ccall(jniref[].SetShortArrayRegion, Nothing, (Ptr{JNIEnv}, jshortArray, jsize, jsize, Ptr{jshort},), penv[], array, start, len, buf)

SetIntArrayRegion(array::jintArray, start::Integer, len::Integer, buf::Array{jint,1}) =
  ccall(jniref[].SetIntArrayRegion, Nothing, (Ptr{JNIEnv}, jintArray, jsize, jsize, Ptr{jint},), penv[], array, start, len, buf)

SetLongArrayRegion(array::jlongArray, start::Integer, len::Integer, buf::Array{jlong,1}) =
  ccall(jniref[].SetLongArrayRegion, Nothing, (Ptr{JNIEnv}, jlongArray, jsize, jsize, Ptr{jlong},), penv[], array, start, len, buf)

SetFloatArrayRegion(array::jfloatArray, start::Integer, len::Integer, buf::Array{jfloat,1}) =
  ccall(jniref[].SetFloatArrayRegion, Nothing, (Ptr{JNIEnv}, jfloatArray, jsize, jsize, Ptr{jfloat},), penv[], array, start, len, buf)

SetDoubleArrayRegion(array::jdoubleArray, start::Integer, len::Integer, buf::Array{jdouble,1}) =
  ccall(jniref[].SetDoubleArrayRegion, Nothing, (Ptr{JNIEnv}, jdoubleArray, jsize, jsize, Ptr{jdouble},), penv[], array, start, len, buf)

RegisterNatives(clazz::jclass, methods::Array{JNINativeMethod,1}, nMethods::jint) =
  ccall(jniref[].RegisterNatives, jint, (Ptr{JNIEnv}, jclass, Ptr{JNINativeMethod}, jint,), penv[], clazz, methods, nMethods)

UnregisterNatives(clazz::jclass) =
  ccall(jniref[].UnregisterNatives, jint, (Ptr{JNIEnv}, jclass,), penv[], clazz)

MonitorEnter(obj::jobject) =
  ccall(jniref[].MonitorEnter, jint, (Ptr{JNIEnv}, jobject,), penv[], obj)

MonitorExit(obj::jobject) =
  ccall(jniref[].MonitorExit, jint, (Ptr{JNIEnv}, jobject,), penv[], obj)

GetJavaVM(vm::Array{JavaVM,1}) =
  ccall(jniref[].GetJavaVM, jint, (Ptr{JNIEnv}, Array{JavaVM,1},), penv[], vm)

GetStringRegion(str::jstring, start::Integer, len::Integer, buf::Array{jchar,1}) =
  ccall(jniref[].GetStringRegion, Nothing, (Ptr{JNIEnv}, jstring, jsize, jsize, Ptr{jchar},), penv[], str, start, len, buf)

GetStringUTFRegion(str::jstring, start::Integer, len::Integer, buf::AnyString) =
  ccall(jniref[].GetStringUTFRegion, Nothing, (Ptr{JNIEnv}, jstring, jsize, jsize, Cstring,), penv[], str, start, len, buf)

GetPrimitiveArrayCritical(array::jarray, isCopy::PtrIsCopy) =
  ccall(jniref[].GetPrimitiveArrayCritical, Ptr{Nothing}, (Ptr{JNIEnv}, jarray, Ptr{jboolean},), penv[], array, isCopy)

ReleasePrimitiveArrayCritical(array::jarray, carray::Ptr{Nothing}, mode::jint) =
  ccall(jniref[].ReleasePrimitiveArrayCritical, Nothing, (Ptr{JNIEnv}, jarray, Ptr{Nothing}, jint,), penv[], array, carray, mode)

GetStringCritical(string::jstring, isCopy::PtrIsCopy) =
  ccall(jniref[].GetStringCritical, Ptr{jchar}, (Ptr{JNIEnv}, jstring, Ptr{jboolean},), penv[], string, isCopy)

ReleaseStringCritical(string::jstring, cstring::Array{jchar,1}) =
  ccall(jniref[].ReleaseStringCritical, Nothing, (Ptr{JNIEnv}, jstring, Ptr{jchar},), penv[], string, cstring)

NewWeakGlobalRef(obj::jobject) =
  ccall(jniref[].NewWeakGlobalRef, jweak, (Ptr{JNIEnv}, jobject,), penv[], obj)

DeleteWeakGlobalRef(ref::jweak) =
  ccall(jniref[].DeleteWeakGlobalRef, Nothing, (Ptr{JNIEnv}, jweak,), penv[], ref)

ExceptionCheck() =
  ccall(jniref[].ExceptionCheck, jboolean, (Ptr{JNIEnv},), penv[])

NewDirectByteBuffer(address::Ptr{Nothing}, capacity::jlong) =
  ccall(jniref[].NewDirectByteBuffer, jobject, (Ptr{JNIEnv}, Ptr{Nothing}, jlong,), penv[], address, capacity)

GetDirectBufferAddress(buf::jobject) =
  ccall(jniref[].GetDirectBufferAddress, Ptr{Nothing}, (Ptr{JNIEnv}, jobject,), penv[], buf)

GetDirectBufferCapacity(buf::jobject) =
  ccall(jniref[].GetDirectBufferCapacity, jlong, (Ptr{JNIEnv}, jobject,), penv[], buf)

GetObjectRefType(obj::jobject) =
  ccall(jniref[].GetObjectRefType, jobjectRefType, (Ptr{JNIEnv}, jobject,), penv[], obj)


# === Above Generated by make_jni2.jl ===

end
