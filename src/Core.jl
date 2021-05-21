module Core

export callinstancemethod

using JavaCall.JNI
using JavaCall.Signatures
using JavaCall.CodeGeneration

callinstancemethod(receiver::jobject, methodname::Symbol, rettype::Any, argtypes::Vector{Any}, args::Vararg{Any, N}) where N =
    callinstancemethod(Val(rettype), receiver, methodname, rettype, argtypes, args...)

for (type, method) in [
        (:jboolean, :call_boolean_method_a),
        (:jbyte, :call_byte_method_a),
        (:jchar, :call_char_method_a),
        (:jint, :call_int_method_a),
        (:jlong, :call_long_method_a),
        (:jfloat, :call_float_method_a),
        (:jdouble, :call_double_method_a),
        (:jobject, :call_object_method_a)
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

end
