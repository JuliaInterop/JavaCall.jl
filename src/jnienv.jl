

immutable JNINativeInterface #struct JNINativeInterface_ {
    
    reserved0::Ptr{Void} # void *reserved0;
    
    reserved1::Ptr{Void} #void *reserved1;
    reserved2::Ptr{Void} #void *reserved2;
    reserved3::Ptr{Void} #void *reserved3;

    GetVersion::Ptr{Void} #jint ( *GetVersion)(JNIEnv *env);
    DefineClass::Ptr{Void} #jclass ( *DefineClass) (JNIEnv *env, const char *name, jobject loader, const jbyte *buf, jsize len);
    FindClass::Ptr{Void} #jclass ( *FindClass) (JNIEnv *env, const char *name);
    FromReflectedMethod::Ptr{Void} #jmethodID ( *FromReflectedMethod) (JNIEnv *env, jobject method);
    FromReflectedField::Ptr{Void} #jfieldID ( *FromReflectedField)(JNIEnv *env, jobject field);
    ToReflectedMethod::Ptr{Void} #jobject ( *ToReflectedMethod) (JNIEnv *env, jclass cls, jmethodID methodID, jboolean isStatic);

    GetSuperClass::Ptr{Void}  #jclass ( *GetSuperclass) (JNIEnv *env, jclass sub);
    IsAssignableFrom::Ptr{Void} #jboolean ( *IsAssignableFrom) (JNIEnv *env, jclass sub, jclass sup);

    ToReflectedField::Ptr{Void} #jobject ( *ToReflectedField)(JNIEnv *env, jclass cls, jfieldID fieldID, jboolean isStatic);

    Throw::Ptr{Void} #jint ( *Throw) (JNIEnv *env, jthrowable obj);
    ThrowNew::Ptr{Void} #jint ( *ThrowNew)(JNIEnv *env, jclass clazz, const char *msg);
    ExceptionOccurred::Ptr{Void} #jthrowable ( *ExceptionOccurred) (JNIEnv *env);
    ExceptionDescribe::Ptr{Void} #void ( *ExceptionDescribe)(JNIEnv *env);
    ExceptionClear::Ptr{Void} #void ( *ExceptionClear) (JNIEnv *env);
    FatalError::Ptr{Void} #void ( *FatalError) (JNIEnv *env, const char *msg);

    PushLocalFrame::Ptr{Void} #jint ( *PushLocalFrame) (JNIEnv *env, jint capacity);
    PopLocalFrame::Ptr{Void} #jobject ( *PopLocalFrame) (JNIEnv *env, jobject result);

    NewGlobalRef::Ptr{Void} #jobject ( *NewGlobalRef) (JNIEnv *env, jobject lobj);
    DeleteGlobalRef::Ptr{Void} #void ( *DeleteGlobalRef) (JNIEnv *env, jobject gref);
    DeleteLocalRef::Ptr{Void} #void ( *DeleteLocalRef) (JNIEnv *env, jobject obj);
    IsSameObject::Ptr{Void} #jboolean ( *IsSameObject) (JNIEnv *env, jobject obj1, jobject obj2);
    NewLocalRef::Ptr{Void} #jobject ( *NewLocalRef) (JNIEnv *env, jobject ref);
    EnsureLocalCapacity::Ptr{Void} #jint ( *EnsureLocalCapacity) (JNIEnv *env, jint capacity);

    AllocObject::Ptr{Void} #jobject ( *AllocObject) (JNIEnv *env, jclass clazz);
    NewObject::Ptr{Void} #jobject ( *NewObject) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    NewObjectV::Ptr{Void} #jobject ( *NewObjectV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    NewObjectA::Ptr{Void} #jobject ( *NewObjectA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    GetObjectClass::Ptr{Void} #jclass ( *GetObjectClass) (JNIEnv *env, jobject obj);
    IsInstanceOf::Ptr{Void} #jboolean ( *IsInstanceOf) (JNIEnv *env, jobject obj, jclass clazz);

    GetMethodID::Ptr{Void} #jmethodID ( *GetMethodID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);

    CallObjectMethod::Ptr{Void} #jobject ( *CallObjectMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallObjectMethodV::Ptr{Void} #jobject ( *CallObjectMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallObjectMethodA::Ptr{Void} #jobject ( *CallObjectMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue * args);

    CallBooleanMethod::Ptr{Void} #jboolean ( *CallBooleanMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallBooleanMethodV::Ptr{Void} #jboolean ( *CallBooleanMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallBooleanMethodA::Ptr{Void} #jboolean ( *CallBooleanMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue * args);

    CallByteMethod::Ptr{Void} #jbyte ( *CallByteMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallByteMethodV::Ptr{Void} #jbyte ( *CallByteMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallByteMethodA::Ptr{Void} #jbyte ( *CallByteMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallCharMethod::Ptr{Void} #jchar ( *CallCharMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallCharMethodV::Ptr{Void} #jchar ( *CallCharMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallCharMethodA::Ptr{Void} #jchar ( *CallCharMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallShortMethod::Ptr{Void} #jshort ( *CallShortMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallShortMethodV::Ptr{Void} #jshort ( *CallShortMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallShortMethodA::Ptr{Void} #jshort ( *CallShortMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallIntMethod::Ptr{Void} #jint ( *CallIntMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallIntMethodV::Ptr{Void} #jint ( *CallIntMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallIntMethodA::Ptr{Void} #jint ( *CallIntMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallLongMethod::Ptr{Void} #jlong ( *CallLongMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallLongMethodV::Ptr{Void} #jlong ( *CallLongMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallLongMethodA::Ptr{Void} #jlong ( *CallLongMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallFloatMethod::Ptr{Void} #jfloat ( *CallFloatMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallFloatMEthodV::Ptr{Void} #jfloat ( *CallFloatMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallFloatMethodA::Ptr{Void} #jfloat ( *CallFloatMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallDoubleMethod::Ptr{Void} #jdouble ( *CallDoubleMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallDoubleMethodV::Ptr{Void} #jdouble ( *CallDoubleMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallDoubleMethodA::Ptr{Void} #jdouble ( *CallDoubleMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallVoidMethod::Ptr{Void} #void ( *CallVoidMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallVoidMethodV::Ptr{Void} #void ( *CallVoidMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallVoidMethodA::Ptr{Void} #void ( *CallVoidMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue * args);

    CallNonvirtualObjectMethod::Ptr{Void} #jobject ( *CallNonvirtualObjectMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualObjectMethodV::Ptr{Void} #jobject ( *CallNonvirtualObjectMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualObjectMEthodA::Ptr{Void} #jobject ( *CallNonvirtualObjectMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue * args);

    CallNonvirtualBooleanMethod::Ptr{Void} #jboolean ( *CallNonvirtualBooleanMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualBooleanMethodV::Ptr{Void} #jboolean ( *CallNonvirtualBooleanMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualBooleanMethodA::Ptr{Void} #jboolean ( *CallNonvirtualBooleanMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue * args);

    CallNonvirtualByteMethod::Ptr{Void} #jbyte ( *CallNonvirtualByteMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualByteMethodV::Ptr{Void} #jbyte ( *CallNonvirtualByteMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualByteMethodA::Ptr{Void} #jbyte ( *CallNonvirtualByteMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualCharMethod::Ptr{Void} #jchar ( *CallNonvirtualCharMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualCharMethodV::Ptr{Void} #jchar ( *CallNonvirtualCharMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualCharMethodA::Ptr{Void} #jchar ( *CallNonvirtualCharMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualShortMethod::Ptr{Void} #jshort ( *CallNonvirtualShortMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualShortMethodV::Ptr{Void} #jshort ( *CallNonvirtualShortMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualShortMethodA::Ptr{Void} #jshort ( *CallNonvirtualShortMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualIntMethod::Ptr{Void} #jint ( *CallNonvirtualIntMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualIntMethodV::Ptr{Void} #jint ( *CallNonvirtualIntMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualIntMethodA::Ptr{Void} #jint ( *CallNonvirtualIntMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualLongMethod::Ptr{Void} #jlong ( *CallNonvirtualLongMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonVirtualLongMethodV::Ptr{Void} #jlong ( *CallNonvirtualLongMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualLongMethodA::Ptr{Void} #jlong ( *CallNonvirtualLongMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonVirtualFloatMethod::Ptr{Void} #jfloat ( *CallNonvirtualFloatMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualFloatMethodV::Ptr{Void} #jfloat ( *CallNonvirtualFloatMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualFloatMethodA::Ptr{Void} #jfloat ( *CallNonvirtualFloatMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualDoubleMethod::Ptr{Void} # jdouble ( *CallNonvirtualDoubleMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualDoubleMethodV::Ptr{Void} # jdouble ( *CallNonvirtualDoubleMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualDoubleMethodA::Ptr{Void} # jdouble ( *CallNonvirtualDoubleMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID,  const jvalue *args);

    CallNonvirtualVoidMethod::Ptr{Void} # void ( *CallNonvirtualVoidMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualVoidMethodV::Ptr{Void} # void ( *CallNonvirtualVoidMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualVoidMethodA::Ptr{Void} # void ( *CallNonvirtualVoidMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue * args);

    GetFieldID::Ptr{Void} # jfieldID ( *GetFieldID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);

    GetObjectField::Ptr{Void} # jobject ( *GetObjectField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetBooleanField::Ptr{Void} # jboolean ( *GetBooleanField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetByteField::Ptr{Void} # jbyte ( *GetByteField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetCharField::Ptr{Void} # jchar ( *GetCharField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetShortField::Ptr{Void} # jshort ( *GetShortField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetIntField::Ptr{Void} # jint ( *GetIntField)  (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetLongField::Ptr{Void} # jlong ( *GetLongField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetFloatField::Ptr{Void} # jfloat ( *GetFloatField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetDoubleField::Ptr{Void} # jdouble ( *GetDoubleField) (JNIEnv *env, jobject obj, jfieldID fieldID);

    SetObjectField::Ptr{Void} # void ( *SetObjectField) (JNIEnv *env, jobject obj, jfieldID fieldID, jobject val);
    SetBooleanField::Ptr{Void} # void ( *SetBooleanField) (JNIEnv *env, jobject obj, jfieldID fieldID, jboolean val);
    SetByteField::Ptr{Void} # void ( *SetByteField)  (JNIEnv *env, jobject obj, jfieldID fieldID, jbyte val);
    SetCharField::Ptr{Void} # void ( *SetCharField) (JNIEnv *env, jobject obj, jfieldID fieldID, jchar val);
    SetShortField::Ptr{Void} # void ( *SetShortField) (JNIEnv *env, jobject obj, jfieldID fieldID, jshort val);
    SetIntField::Ptr{Void} # void ( *SetIntField) (JNIEnv *env, jobject obj, jfieldID fieldID, jint val);
    SetLongField::Ptr{Void} # void ( *SetLongField) (JNIEnv *env, jobject obj, jfieldID fieldID, jlong val);
    SetFloatField::Ptr{Void} # void ( *SetFloatField) (JNIEnv *env, jobject obj, jfieldID fieldID, jfloat val);
    SetDoubleField::Ptr{Void} # void ( *SetDoubleField) (JNIEnv *env, jobject obj, jfieldID fieldID, jdouble val);

    GetStaticMethodID::Ptr{Void} # jmethodID ( *GetStaticMethodID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);

    CallStaticObjectMethod::Ptr{Void} # jobject ( *CallStaticObjectMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticObjectMethodV::Ptr{Void} #jobject ( *CallStaticObjectMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticObjectMethodA::Ptr{Void} # jobject ( *CallStaticObjectMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticBooleanMethod::Ptr{Void} # jboolean ( *CallStaticBooleanMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticBooleanMethodV::Ptr{Void} # jboolean ( *CallStaticBooleanMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticBooleanMethodA::Ptr{Void} # jboolean ( *CallStaticBooleanMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticByteMethod::Ptr{Void} #jbyte ( *CallStaticByteMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticByteMethodV::Ptr{Void} # jbyte ( *CallStaticByteMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticByteMethodA::Ptr{Void} #jbyte ( *CallStaticByteMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticCharMethod::Ptr{Void} # jchar ( *CallStaticCharMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticCharMethodV::Ptr{Void} # jchar ( *CallStaticCharMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticCharMethodA::Ptr{Void} # jchar ( *CallStaticCharMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticShortMethod::Ptr{Void} # jshort ( *CallStaticShortMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticShortMethodV::Ptr{Void} # jshort ( *CallStaticShortMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticShortMethodA::Ptr{Void} # jshort ( *CallStaticShortMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticIntMethod::Ptr{Void} #jint ( *CallStaticIntMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticIntMethodV::Ptr{Void} # jint ( *CallStaticIntMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticIntMethodA::Ptr{Void} # jint ( *CallStaticIntMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticLongMethod::Ptr{Void} # jlong ( *CallStaticLongMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticLongMethodV::Ptr{Void} # jlong ( *CallStaticLongMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticLongMethodA::Ptr{Void} # jlong ( *CallStaticLongMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticFloatMethod::Ptr{Void} # jfloat ( *CallStaticFloatMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticFloatMethodV::Ptr{Void} # jfloat ( *CallStaticFloatMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticFloatMethodA::Ptr{Void} # jfloat ( *CallStaticFloatMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticDoubleMethod::Ptr{Void} # jdouble ( *CallStaticDoubleMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticDoubleMethodV::Ptr{Void} # jdouble ( *CallStaticDoubleMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticDoubleMethodA::Ptr{Void} # jdouble ( *CallStaticDoubleMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticVoidMethod::Ptr{Void} # void ( *CallStaticVoidMethod) (JNIEnv *env, jclass cls, jmethodID methodID, ...);
    CallStaticVoidMethodV::Ptr{Void} # void ( *CallStaticVoidMethodV) (JNIEnv *env, jclass cls, jmethodID methodID, va_list args);
    CallStaticVoidMethodA::Ptr{Void} # void ( *CallStaticVoidMethodA) (JNIEnv *env, jclass cls, jmethodID methodID, const jvalue * args);

    GetStaticFieldID::Ptr{Void} # jfieldID ( *GetStaticFieldID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);
    GetStaticObjectField::Ptr{Void} # jobject ( *GetStaticObjectField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticBooleanField::Ptr{Void} # jboolean ( *GetStaticBooleanField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticByteField::Ptr{Void} # jbyte ( *GetStaticByteField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticCharField::Ptr{Void} # jchar ( *GetStaticCharField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticShortField::Ptr{Void} # jshort ( *GetStaticShortField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticIntField::Ptr{Void} # jint ( *GetStaticIntField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticLongField::Ptr{Void} # jlong ( *GetStaticLongField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticFloatField::Ptr{Void} # jfloat ( *GetStaticFloatField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticDoubleField::Ptr{Void} # jdouble ( *GetStaticDoubleField) (JNIEnv *env, jclass clazz, jfieldID fieldID);

    SetStaticObjectField::Ptr{Void} # void ( *SetStaticObjectField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jobject value);
    SetStaticBooleanField::Ptr{Void} # void ( *SetStaticBooleanField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jboolean value);
    SetStaticByteField::Ptr{Void} # void ( *SetStaticByteField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jbyte value);
    SetStaticCharField::Ptr{Void} # void ( *SetStaticCharField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jchar value);
    SetStaticShortField::Ptr{Void} # void ( *SetStaticShortField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jshort value);
    SetStaticIntField::Ptr{Void} # void ( *SetStaticIntField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jint value);
    SetStaticLongField::Ptr{Void} # void ( *SetStaticLongField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jlong value);
    SetStaticFloatField::Ptr{Void} # void ( *SetStaticFloatField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jfloat value);
    SetStaticDoubleField::Ptr{Void} # void ( *SetStaticDoubleField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jdouble value);

    NewString::Ptr{Void} #::Ptr{Void} # jstring ( *NewString) (JNIEnv *env, const jchar *unicode, jsize len);
    GetStringLength::Ptr{Void} # jsize ( *GetStringLength) (JNIEnv *env, jstring str);
    GetStringChars::Ptr{Void} # const jchar *( *GetStringChars) (JNIEnv *env, jstring str, jboolean *isCopy);
    ReleaseStringChars::Ptr{Void} # void ( *ReleaseStringChars) (JNIEnv *env, jstring str, const jchar *chars);

    NewStringUTF::Ptr{Void} # jstring ( *NewStringUTF) (JNIEnv *env, const char *utf);
    GetStringUTFLength::Ptr{Void} # jsize ( *GetStringUTFLength) (JNIEnv *env, jstring str);
    GetStringUTFChars::Ptr{Void} # const char* ( *GetStringUTFChars) (JNIEnv *env, jstring str, jboolean *isCopy);
    ReleaseStringUTFChars::Ptr{Void} # void ( *ReleaseStringUTFChars) (JNIEnv *env, jstring str, const char* chars);


    GetArrayLength::Ptr{Void} # jsize ( *GetArrayLength ) (JNIEnv *env, jarray array);

    NewObjectArray::Ptr{Void} # jobjectArray ( *NewObjectArray) (JNIEnv *env, jsize len, jclass clazz, jobject init);
    GetObjectArrayElement::Ptr{Void} # jobject ( *GetObjectArrayElement) (JNIEnv *env, jobjectArray array, jsize index);
    SetObjectArrayElement::Ptr{Void} # void ( *SetObjectArrayElement) (JNIEnv *env, jobjectArray array, jsize index, jobject val);

    NewBooleanArray::Ptr{Void} # jbooleanArray ( *NewBooleanArray) (JNIEnv *env, jsize len);
    NewByteArray::Ptr{Void} # jbyteArray ( *NewByteArray) (JNIEnv *env, jsize len);
    NewCharArray::Ptr{Void} # jcharArray ( *NewCharArray) (JNIEnv *env, jsize len);
    NewShortArray::Ptr{Void} # jshortArray ( *NewShortArray) (JNIEnv *env, jsize len);
    NewIntArray::Ptr{Void} # jintArray ( *NewIntArray) (JNIEnv *env, jsize len);
    NewLongArray::Ptr{Void} # jlongArray ( *NewLongArray) (JNIEnv *env, jsize len);
    NewFloatArray::Ptr{Void} # jfloatArray ( *NewFloatArray) (JNIEnv *env, jsize len);
    NewDoubleArray::Ptr{Void} # jdoubleArray ( *NewDoubleArray) (JNIEnv *env, jsize len);

    GetBooleanArrayElements::Ptr{Void} # jboolean * ( *GetBooleanArrayElements) (JNIEnv *env, jbooleanArray array, jboolean *isCopy);
    GetByteArrayElements::Ptr{Void} # jbyte * ( *GetByteArrayElements) (JNIEnv *env, jbyteArray array, jboolean *isCopy);
    GetCharArrayElements::Ptr{Void} # jchar * ( *GetCharArrayElements) (JNIEnv *env, jcharArray array, jboolean *isCopy);
    GetShortArrayElements::Ptr{Void} # jshort * ( *GetShortArrayElements) (JNIEnv *env, jshortArray array, jboolean *isCopy);
    GetIntArrayElements::Ptr{Void} # jint * ( *GetIntArrayElements) (JNIEnv *env, jintArray array, jboolean *isCopy);
    GetLongArrayElements::Ptr{Void} # jlong * ( *GetLongArrayElements ) (JNIEnv *env, jlongArray array, jboolean *isCopy);
    GetFloatArrayElements::Ptr{Void} # jfloat * ( *GetFloatArrayElements) (JNIEnv *env, jfloatArray array, jboolean *isCopy);
    GetDoubleArrayElements::Ptr{Void} # jdouble * ( *GetDoubleArrayElements) (JNIEnv *env, jdoubleArray array, jboolean *isCopy);

    ReleaseBooleanArrayElements::Ptr{Void} # void ( *ReleaseBooleanArrayElements ) (JNIEnv *env, jbooleanArray array, jboolean *elems, jint mode);
    ReleaseByteArrayElements::Ptr{Void} # void ( *ReleaseByteArrayElements ) (JNIEnv *env, jbyteArray array, jbyte *elems, jint mode);
    ReleaseCharArrayElements::Ptr{Void} # void ( *ReleaseCharArrayElements ) (JNIEnv *env, jcharArray array, jchar *elems, jint mode);
    ReleaseShortArrayElements::Ptr{Void} # void ( *ReleaseShortArrayElements) (JNIEnv *env, jshortArray array, jshort *elems, jint mode);
    ReleaseIntArrayElements::Ptr{Void} # void ( *ReleaseIntArrayElements) (JNIEnv *env, jintArray array, jint *elems, jint mode);
    ReleaseLongArrayElements::Ptr{Void} # void ( *ReleaseLongArrayElements ) (JNIEnv *env, jlongArray array, jlong *elems, jint mode);
    ReleaseFloatArrayElements::Ptr{Void} # void ( *ReleaseFloatArrayElements) (JNIEnv *env, jfloatArray array, jfloat *elems, jint mode);
    ReleaseDoubleArrayElements::Ptr{Void} # void ( *ReleaseDoubleArrayElements ) (JNIEnv *env, jdoubleArray array, jdouble *elems, jint mode);

    GetBooleanArrayRegion::Ptr{Void} # void ( *GetBooleanArrayRegion ) (JNIEnv *env, jbooleanArray array, jsize start, jsize l, jboolean *buf);
    GetByteArrayRegion::Ptr{Void} # void ( *GetByteArrayRegion) (JNIEnv *env, jbyteArray array, jsize start, jsize len, jbyte *buf);
    vGetCharArrayRegion::Ptr{Void} # void ( *GetCharArrayRegion) (JNIEnv *env, jcharArray array, jsize start, jsize len, jchar *buf);
    GetShortArrayRegion::Ptr{Void} # void ( *GetShortArrayRegion ) (JNIEnv *env, jshortArray array, jsize start, jsize len, jshort *buf);
    GetIntArrayRegion::Ptr{Void} # void ( *GetIntArrayRegion ) (JNIEnv *env, jintArray array, jsize start, jsize len, jint *buf);
    GetLongArrayRegion::Ptr{Void} # void ( *GetLongArrayRegion) (JNIEnv *env, jlongArray array, jsize start, jsize len, jlong *buf);
    GetFloatArrayRegion::Ptr{Void} # void ( *GetFloatArrayRegion) (JNIEnv *env, jfloatArray array, jsize start, jsize len, jfloat *buf);
    GetDoubleArrayRegion::Ptr{Void} # void ( *GetDoubleArrayRegion) (JNIEnv *env, jdoubleArray array, jsize start, jsize len, jdouble *buf);

    SetBooleanArrayRegion::Ptr{Void} # void ( *SetBooleanArrayRegion )(JNIEnv *env, jbooleanArray array, jsize start, jsize l, const jboolean *buf);
    SetByteArrayRegion::Ptr{Void} # void ( *SetByteArrayRegion) (JNIEnv *env, jbyteArray array, jsize start, jsize len, const jbyte *buf);
    SetCharArrayRegion::Ptr{Void} # void ( *SetCharArrayRegion) (JNIEnv *env, jcharArray array, jsize start, jsize len, const jchar *buf);
    SetShortArrayRegion::Ptr{Void} # void ( *SetShortArrayRegion ) (JNIEnv *env, jshortArray array, jsize start, jsize len, const jshort *buf);
    SetIntArrayRegion::Ptr{Void} # void ( *SetIntArrayRegion) (JNIEnv *env, jintArray array, jsize start, jsize len, const jint *buf);
    SetLongArrayRegion::Ptr{Void} # void ( *SetLongArrayRegion) (JNIEnv *env, jlongArray array, jsize start, jsize len, const jlong *buf);
    SetFloatArrayRegion::Ptr{Void} # void ( *SetFloatArrayRegion ) (JNIEnv *env, jfloatArray array, jsize start, jsize len, const jfloat *buf);
    SetDoubleArrayRegion::Ptr{Void} # void ( *SetDoubleArrayRegion) (JNIEnv *env, jdoubleArray array, jsize start, jsize len, const jdouble *buf);

    RegisterNatives::Ptr{Void} # jint ( *RegisterNatives) (JNIEnv *env, jclass clazz, const JNINativeMethod *methods, jint nMethods);
    UnregisterNatives::Ptr{Void} # jint ( *UnregisterNatives ) (JNIEnv *env, jclass clazz);

    MonitorEnter::Ptr{Void} # jint ( *MonitorEnter) (JNIEnv *env, jobject obj);
    MonitorExit::Ptr{Void} # jint ( *MonitorExit ) (JNIEnv *env, jobject obj);

    GetJavaVM::Ptr{Void} # jint ( *GetJavaVM) (JNIEnv *env, JavaVM **vm);

    GetStringRegion::Ptr{Void} # void ( *GetStringRegion ) (JNIEnv *env, jstring str, jsize start, jsize len, jchar *buf);
    GetStringUTFRegion::Ptr{Void} # void ( *GetStringUTFRegion) (JNIEnv *env, jstring str, jsize start, jsize len, char *buf);

    GetPrimitiveArrayCritical::Ptr{Void} # void * ( *GetPrimitiveArrayCritical) (JNIEnv *env, jarray array, jboolean *isCopy);
    ReleasePrimitiveArrayCritical::Ptr{Void} # void ( *ReleasePrimitiveArrayCritical ) (JNIEnv *env, jarray array, void *carray, jint mode);

    GetStringCritical::Ptr{Void} # const jchar * ( *GetStringCritical ) (JNIEnv *env, jstring string, jboolean *isCopy);
    ReleaseStringCritical::Ptr{Void} # void ( *ReleaseStringCritical ) (JNIEnv *env, jstring string, const jchar *cstring);

    NewWeakGlobalRef::Ptr{Void} # jweak ( *NewWeakGlobalRef) (JNIEnv *env, jobject obj);
    DeleteWeakGlobalRef::Ptr{Void} # void ( *DeleteWeakGlobalRef) (JNIEnv *env, jweak ref);

    ExceptionCheck::Ptr{Void} # jboolean ( *ExceptionCheck) (JNIEnv *env);

    NewDirectByteBuffer::Ptr{Void} # jobject ( *NewDirectByteBuffer ) (JNIEnv* env, void* address, jlong capacity);
    GetDirectBufferAddress::Ptr{Void} # void* ( *GetDirectBufferAddress ) (JNIEnv* env, jobject buf);
    GetDirectBufferCapacity::Ptr{Void} # jlong ( *GetDirectBufferCapacity) (JNIEnv* env, jobject buf);

    #/* New JNI 1.6 Features */

    GetObjectRefType::Ptr{Void} # jobjectRefType ( *GetObjectRefType) (JNIEnv* env, jobject obj);
end #};

immutable JNIEnv
    JNINativeInterface_::Ptr{JNINativeInterface}
end

immutable JNIInvokeInterface #struct JNIInvokeInterface_ {
    reserved0::Ptr{Void} #void *reserved0;
    reserved1::Ptr{Void} #vvoid *reserved1;
    reserved2::Ptr{Void} #vvoid *reserved2;

    DestroyJavaVM::Ptr{Void} #jint (JNICALL *DestroyJavaVM)(JavaVM *vm);

    AttachCurrentThread::Ptr{Void} #jint (JNICALL *AttachCurrentThread)(JavaVM *vm, void **penv, void *args);

    DetachCurrentThread::Ptr{Void} #jint (JNICALL *DetachCurrentThread)(JavaVM *vm);

    GetEnv::Ptr{Void} #jint (JNICALL *GetEnv)(JavaVM *vm, void **penv, jint version);

    AttachCurrentThreadAsDaemon::Ptr{Void} #jint (JNICALL *AttachCurrentThreadAsDaemon)(JavaVM *vm, void **penv, void *args);
end

immutable JavaVM
    JNIInvokeInterface_::Ptr{JNIInvokeInterface}
end


