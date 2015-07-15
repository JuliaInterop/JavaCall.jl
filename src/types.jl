# jni_md.h
typealias jint Cint
#ifdef _LP64 /* 64-bit Solaris */
# typedef long jlong;
typealias jlong Clonglong
typealias jbyte Cchar
 
# jni.h

typealias jboolean Cuchar
typealias jchar Cushort
typealias jshort Cshort
typealias jfloat Cfloat
typealias jdouble Cdouble
typealias jsize jint
jprimitive = Union(jboolean, jchar, jshort, jfloat, jdouble, jint, jlong)

immutable JavaMetaClass{T}
    ptr::Ptr{Void}
end

#The metaclass, sort of equivalent to a the 
JavaMetaClass(T, ptr) = JavaMetaClass{T}(ptr)

type JavaObject{T}
    ptr::Ptr{Void}
    
    function JavaObject(ptr)
        j=new(ptr)
        finalizer(j, deleteref)
        return j
    end 

    JavaObject(argtypes::Tuple, args...) = jnew(T, argtypes, args...)

end

JavaObject(T, ptr) = JavaObject{T}(ptr)

function deleteref(x::JavaObject)
    if x.ptr == C_NULL; return; end
    if (penv==C_NULL); return; end
    #ccall(:jl_,Void,(Any,),x)
    ccall(jnifunc.DeleteLocalRef, Void, (Ptr{JNIEnv}, Ptr{Void}), penv, x.ptr)
    x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize
    return
end


isnull(obj::JavaObject) = obj.ptr == C_NULL
isnull(obj::JavaMetaClass) = obj.ptr == C_NULL

typealias JClass JavaObject{symbol("java.lang.Class")}
typealias JObject JavaObject{symbol("java.lang.Object")}
typealias JMethod JavaObject{symbol("java.lang.reflect.Method")}
typealias JString JavaObject{symbol("java.lang.String")}


function JString(str::String)
    jstring = ccall(jnifunc.NewStringUTF, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, utf8(str))
    if jstring == C_NULL
        geterror()
    else 
        return JString(jstring)
    end
end
# Convert a reference to a java.lang.String into a Julia string. Copies the underlying byte buffer
function bytestring(jstr::JString)  #jstr must be a jstring obtained via a JNI call
    if isnull(jstr); return ""; end #Return empty string to keep type stability. But this is questionable
    pIsCopy = Array(jboolean, 1)
    buf::Ptr{Uint8} = ccall(jnifunc.GetStringUTFChars, Ptr{Uint8}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{jboolean}), penv, jstr.ptr, pIsCopy)
    s=bytestring(buf)
    ccall(jnifunc.ReleaseStringUTFChars, Void, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}), penv, jstr.ptr, buf)
    return s
end

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = @compat Int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(@compat Int(v))
