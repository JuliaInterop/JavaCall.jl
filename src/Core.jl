module Core

export callinstancemethod, callstaticmethod, callconstructor

using JavaCall.JNI
using JavaCall.Signatures
using JavaCall.CodeGeneration

dispatch_rettype(::Type{jboolean}) = jboolean
dispatch_rettype(::Type{jbyte}) = jbyte
dispatch_rettype(::Type{jchar}) = jchar
dispatch_rettype(::Type{jshort}) = jshort
dispatch_rettype(::Type{jint}) = jint
dispatch_rettype(::Type{jlong}) = jlong
dispatch_rettype(::Type{jfloat}) = jfloat
dispatch_rettype(::Type{jdouble}) = jdouble
dispatch_rettype(::Type{jvoid}) = jvoid
# Default return type for all types is jobject when calling a method
dispatch_rettype(::T) where {T} = jobject

callinstancemethod(receiver::jobject, methodname::Symbol, rettype::Any, argtypes::Vector{Any}, args::Vararg{Any, N}) where N =
    callinstancemethod(Val(dispatch_rettype(rettype)), receiver, methodname, rettype, argtypes, args...)

for (type, method) in [
        (:jboolean, :call_boolean_method_a),
        (:jbyte, :call_byte_method_a),
        (:jchar, :call_char_method_a),
        (:jshort, :call_short_method_a),
        (:jint, :call_int_method_a),
        (:jlong, :call_long_method_a),
        (:jfloat, :call_float_method_a),
        (:jdouble, :call_double_method_a),
        (:jobject, :call_object_method_a),
        (:jvoid, :call_void_method_a)
    ]  
    params = [
        :(::Val{$type}), 
        :(receiver::Any), 
        :(methodname::Symbol), 
        :(rettype::Any),
        :(argtypes::Vector{Any}),
        :(args::Vararg{Any, N})
    ]
    body = quote
        @assert length(args) == length(argtypes)

        receiver_class = JNI.get_object_class(receiver)
        methodsignature = MethodSignature(rettype, argtypes)
        method = JNI.get_method_id(receiver_class, string(methodname), signature(methodsignature))
        JNI.$method(receiver, method, jvalue[args...])
    end
    eval(generatemethod(:callinstancemethod, params, body, :N))
end

callstaticmethod(class::jclass, methodname::Symbol, rettype::Any, argtypes::Vector{Any}, args::Vararg{Any, N}) where N =
    callstaticmethod(Val(dispatch_rettype(rettype)), class, methodname, rettype, argtypes, args...)

for (type, method) in [
        (:jboolean, :call_static_boolean_method_a),
        (:jbyte, :call_static_byte_method_a),
        (:jchar, :call_static_char_method_a),
        (:jshort, :call_static_short_method_a),
        (:jint, :call_static_int_method_a),
        (:jlong, :call_static_long_method_a),
        (:jfloat, :call_static_float_method_a),
        (:jdouble, :call_static_double_method_a),
        (:jobject, :call_static_object_method_a),
        (:jvoid, :call_static_void_method_a)
    ]  
    params = [
        :(::Val{$type}), 
        :(class::jclass), 
        :(methodname::Symbol), 
        :(rettype::Any),
        :(argtypes::Vector{Any}),
        :(args::Vararg{Any, N})
    ]
    body = quote
        @assert length(args) == length(argtypes)

        methodsignature = MethodSignature(rettype, argtypes)
        method = JNI.get_static_method_id(class, string(methodname), signature(methodsignature))
        JNI.$method(class, method, jvalue[args...])
    end
    eval(generatemethod(:callstaticmethod, params, body, :N))
end

callinstancemethod(receiver::jobject, methodname::Symbol, rettype::Any, signature::String, args::Vararg{Any, N}) where N =
    callinstancemethod(Val(dispatch_rettype(rettype)), receiver, methodname, signature, args...)

for (type, method) in [
        (:jboolean, :call_boolean_method_a),
        (:jbyte, :call_byte_method_a),
        (:jchar, :call_char_method_a),
        (:jshort, :call_short_method_a),
        (:jint, :call_int_method_a),
        (:jlong, :call_long_method_a),
        (:jfloat, :call_float_method_a),
        (:jdouble, :call_double_method_a),
        (:jobject, :call_object_method_a),
        (:jvoid, :call_void_method_a)
    ]  
    params = [
        :(::Val{$type}), 
        :(receiver::Any), 
        :(methodname::Symbol), 
        :(signature::String),
        :(args::Vararg{Any, N})
    ]
    body = quote
        receiver_class = JNI.get_object_class(receiver)
        method = JNI.get_method_id(receiver_class, string(methodname), signature)
        JNI.$method(receiver, method, jvalue[args...])
    end
    eval(generatemethod(:callinstancemethod, params, body, :N))
end

callstaticmethod(class::jclass, methodname::Symbol, rettype::Any, signature::String, args::Vararg{Any, N}) where N =
    callstaticmethod(Val(dispatch_rettype(rettype)), class, methodname, signature, args...)

for (type, method) in [
    (:jboolean, :call_static_boolean_method_a),
    (:jbyte, :call_static_byte_method_a),
    (:jchar, :call_static_char_method_a),
    (:jshort, :call_static_short_method_a),
    (:jint, :call_static_int_method_a),
    (:jlong, :call_static_long_method_a),
    (:jfloat, :call_static_float_method_a),
    (:jdouble, :call_static_double_method_a),
    (:jobject, :call_static_object_method_a),
    (:jvoid, :call_static_void_method_a)
]  
    params = [
        :(::Val{$type}), 
        :(class::jclass), 
        :(methodname::Symbol), 
        :(signature::String),
        :(args::Vararg{Any, N})
    ]
    body = quote
        method = JNI.get_static_method_id(class, string(methodname), signature)
        JNI.$method(class, method, jvalue[args...])
    end
    eval(generatemethod(:callstaticmethod, params, body, :N))
end

function callconstructor(class::jclass, signature::String, args::Vararg{Any, N}) where N
    # Construct name is always <init> as specified by the JNI reference
    constructor = JNI.get_method_id(class, "<init>", signature)
    JNI.new_object_a(class, constructor, jvalue[args...])
end

end
