module JNI

export init_new_vm, destroy_vm, is_jni_loaded, is_env_loaded,
    # Types.jl    
    jint, jlong, jbyte, jboolean, jchar, jshort, jfloat, jdouble, jsize,
    jvoid, jobject, jclass, jthrowable, jweak, jmethodID, jfieldID, jstring, jarray,
    JNINativeMethod, jobjectArray, jbooleanArray, jbyteArray, jshortArray, jintArray,
    jlongArray, jfloatArray, jdoubleArray, jcharArray, jvalue, jobjectRefType,
    # Constants.jl
    JNI_FALSE, JNI_TRUE

include("Threads.jl")
include("Constants.jl")
include("Types.jl")
include("Interfaces.jl")

import Libdl

using .Threads
using .Constants
using .Types
using .Interfaces

# Global variables

# JavaVM **
const jvmptrref = Ref(Ptr{JavaVM}(C_NULL))
# JNIEnv ** (array of JNIEnv used by different threads)
const jnienvptrs = [Ptr{JNIEnv}(C_NULL)]

const jninativeinterfaceref = Ref(JNINativeInterface())
const jniinvokeinterfaceref = Ref(JNIInvokeInterface())

# API Structs
const Char = UInt8

struct JavaVMOption
    optionString::Ptr{Char}
    extraInfo::Ptr{Nothing}
end

JavaVMOption(optionString::Ptr{Char}) = JavaVMOption(optionString, C_NULL)

struct JavaVMInitArgs
    version::jint
    nOptions::jint
    options::Ptr{JavaVMOption}
    ignoreUnrecognized::jboolean
end

JavaVMInitArgs(version::jint, jopts::Vector{JavaVMOption}, ignoreUnrecognized::jboolean) =
    JavaVMInitArgs(version, convert(jint, length(jopts)), convert(Ptr{JavaVMOption}, pointer(jopts)), ignoreUnrecognized)

struct JNIError <: Exception
    msg::String
end

# JNI API
"""
    init_new_vm(opts)

Initialize a new Java virtual machine.
"""
function init_new_vm(libpath,opts)
    libjvm = Libdl.dlopen(libpath)
    create = Libdl.dlsym(libjvm, :JNI_CreateJavaVM)
	jopts = [JavaVMOption(pointer(x)) for x in opts]
    Threads.resize_nthreads!(jnienvptrs)
    GC.@preserve jvmptrref jnienvptrs jopts begin
        vm_args = JavaVMInitArgs(JNI_VERSION_1_8, jopts, JNI_TRUE)
        res = @ccall $create(jvmptrref::Ref{Ptr{JavaVM}}, jnienvptrs::Ref{Ptr{JNIEnv}}, Ref(vm_args)::Ptr{JavaVMInitArgs})::Cint
        res < 0 && throw(JNIError("Unable to initialise Java VM: $(res)"))
    end
    jvm = unsafe_load(jvmptrref[])
    jniinvokeinterfaceref[] = unsafe_load(jvm)
    jnienv = unsafe_load(jnienvptrs[1])
    jninativeinterfaceref[] = unsafe_load(jnienv)
    _attachthreads()
    return
end

function destroy_vm()
    if !is_env_loaded()
        throw(JNIError("Called destroy without initialising Java VM"))
    end
    _detachthreads()
    destroy_fn = jniinvokeinterfaceref[].DestroyJavaVM
    res = @ccall $destroy_fn(jvmptrref[]::Ptr{JavaVM})::Cint
    res < 0 && throw(JavaCallError("Unable to destroy Java VM"))
    _resetglobalvars()
    nothing
end

is_jni_loaded() = jninativeinterfaceref[].GetVersion != C_NULL
is_env_loaded() = jnienvptrs[1] != C_NULL

# Include file with generated jni interface
include("generated_jni_interface.jl")

# Private functions

function _resetglobalvars()
    jniinvokeinterfaceref[] = JNIInvokeInterface()
    empty!(jnienvptrs)
    push!(jnienvptrs, Ptr{JNIEnv}(C_NULL))
    jninativeinterfaceref[] = JNINativeInterface()
    jvmptrref[] = Ptr{JavaVM}(C_NULL)
end

function _attachthreads()
    Threads.@threads for i=1:Threads.nthreads()
        _attachthread(Ref(jnienvptrs, Threads.threadid()))
    end
end  

function _attachthread(ppenv_thread = Ref{Ptr{JNIEnv}}(C_NULL))
    res = ccall(jniinvokeinterfaceref[].AttachCurrentThread, Cint, (Ptr{Nothing}, Ptr{Ptr{JNIEnv}}, Ptr{Nothing}), jvmptrref[], ppenv_thread, C_NULL)
    res < 0 && throw(JNIError("Unable to attach thread id: $(Threads.threadid())"))
    return ppenv_thread[]
end

function _detachthreads()
    Threads.@threads for i=1:Threads.nthreads()
        _detachthread()
    end
    nothing
end  

function _detachthread()
    res = ccall(jniinvokeinterfaceref[].DetachCurrentThread, Cint, (Ptr{JavaVM},), jvmptrref[])
    res < 0 && throw(JNIError("Unable to detach thread id: $(Threads.threadid())"))
    nothing
end

end
