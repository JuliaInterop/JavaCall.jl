

struct JNINativeInterface #struct JNINativeInterface_ {

    reserved0::Ptr{Nothing} # void *reserved0;

    reserved1::Ptr{Nothing} #void *reserved1;
    reserved2::Ptr{Nothing} #void *reserved2;
    reserved3::Ptr{Nothing} #void *reserved3;

    GetVersion::Ptr{Nothing} #jint ( *GetVersion)(JNIEnv *env);
    DefineClass::Ptr{Nothing} #jclass ( *DefineClass) (JNIEnv *env, const char *name, jobject loader, const jbyte *buf, jsize len);
    FindClass::Ptr{Nothing} #jclass ( *FindClass) (JNIEnv *env, const char *name);
    FromReflectedMethod::Ptr{Nothing} #jmethodID ( *FromReflectedMethod) (JNIEnv *env, jobject method);
    FromReflectedField::Ptr{Nothing} #jfieldID ( *FromReflectedField)(JNIEnv *env, jobject field);
    ToReflectedMethod::Ptr{Nothing} #jobject ( *ToReflectedMethod) (JNIEnv *env, jclass cls, jmethodID methodID, jboolean isStatic);

    GetSuperClass::Ptr{Nothing}  #jclass ( *GetSuperclass) (JNIEnv *env, jclass sub);
    IsAssignableFrom::Ptr{Nothing} #jboolean ( *IsAssignableFrom) (JNIEnv *env, jclass sub, jclass sup);

    ToReflectedField::Ptr{Nothing} #jobject ( *ToReflectedField)(JNIEnv *env, jclass cls, jfieldID fieldID, jboolean isStatic);

    Throw::Ptr{Nothing} #jint ( *Throw) (JNIEnv *env, jthrowable obj);
    ThrowNew::Ptr{Nothing} #jint ( *ThrowNew)(JNIEnv *env, jclass clazz, const char *msg);
    ExceptionOccurred::Ptr{Nothing} #jthrowable ( *ExceptionOccurred) (JNIEnv *env);
    ExceptionDescribe::Ptr{Nothing} #void ( *ExceptionDescribe)(JNIEnv *env);
    ExceptionClear::Ptr{Nothing} #void ( *ExceptionClear) (JNIEnv *env);
    FatalError::Ptr{Nothing} #void ( *FatalError) (JNIEnv *env, const char *msg);

    PushLocalFrame::Ptr{Nothing} #jint ( *PushLocalFrame) (JNIEnv *env, jint capacity);
    PopLocalFrame::Ptr{Nothing} #jobject ( *PopLocalFrame) (JNIEnv *env, jobject result);

    NewGlobalRef::Ptr{Nothing} #jobject ( *NewGlobalRef) (JNIEnv *env, jobject lobj);
    DeleteGlobalRef::Ptr{Nothing} #void ( *DeleteGlobalRef) (JNIEnv *env, jobject gref);
    DeleteLocalRef::Ptr{Nothing} #void ( *DeleteLocalRef) (JNIEnv *env, jobject obj);
    IsSameObject::Ptr{Nothing} #jboolean ( *IsSameObject) (JNIEnv *env, jobject obj1, jobject obj2);
    NewLocalRef::Ptr{Nothing} #jobject ( *NewLocalRef) (JNIEnv *env, jobject ref);
    EnsureLocalCapacity::Ptr{Nothing} #jint ( *EnsureLocalCapacity) (JNIEnv *env, jint capacity);

    AllocObject::Ptr{Nothing} #jobject ( *AllocObject) (JNIEnv *env, jclass clazz);
    NewObject::Ptr{Nothing} #jobject ( *NewObject) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    NewObjectV::Ptr{Nothing} #jobject ( *NewObjectV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    NewObjectA::Ptr{Nothing} #jobject ( *NewObjectA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    GetObjectClass::Ptr{Nothing} #jclass ( *GetObjectClass) (JNIEnv *env, jobject obj);
    IsInstanceOf::Ptr{Nothing} #jboolean ( *IsInstanceOf) (JNIEnv *env, jobject obj, jclass clazz);

    GetMethodID::Ptr{Nothing} #jmethodID ( *GetMethodID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);

    CallObjectMethod::Ptr{Nothing} #jobject ( *CallObjectMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallObjectMethodV::Ptr{Nothing} #jobject ( *CallObjectMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallObjectMethodA::Ptr{Nothing} #jobject ( *CallObjectMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue * args);

    CallBooleanMethod::Ptr{Nothing} #jboolean ( *CallBooleanMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallBooleanMethodV::Ptr{Nothing} #jboolean ( *CallBooleanMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallBooleanMethodA::Ptr{Nothing} #jboolean ( *CallBooleanMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue * args);

    CallByteMethod::Ptr{Nothing} #jbyte ( *CallByteMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallByteMethodV::Ptr{Nothing} #jbyte ( *CallByteMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallByteMethodA::Ptr{Nothing} #jbyte ( *CallByteMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallCharMethod::Ptr{Nothing} #jchar ( *CallCharMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallCharMethodV::Ptr{Nothing} #jchar ( *CallCharMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallCharMethodA::Ptr{Nothing} #jchar ( *CallCharMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallShortMethod::Ptr{Nothing} #jshort ( *CallShortMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallShortMethodV::Ptr{Nothing} #jshort ( *CallShortMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallShortMethodA::Ptr{Nothing} #jshort ( *CallShortMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallIntMethod::Ptr{Nothing} #jint ( *CallIntMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallIntMethodV::Ptr{Nothing} #jint ( *CallIntMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallIntMethodA::Ptr{Nothing} #jint ( *CallIntMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallLongMethod::Ptr{Nothing} #jlong ( *CallLongMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallLongMethodV::Ptr{Nothing} #jlong ( *CallLongMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallLongMethodA::Ptr{Nothing} #jlong ( *CallLongMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallFloatMethod::Ptr{Nothing} #jfloat ( *CallFloatMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallFloatMEthodV::Ptr{Nothing} #jfloat ( *CallFloatMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallFloatMethodA::Ptr{Nothing} #jfloat ( *CallFloatMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallDoubleMethod::Ptr{Nothing} #jdouble ( *CallDoubleMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallDoubleMethodV::Ptr{Nothing} #jdouble ( *CallDoubleMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallDoubleMethodA::Ptr{Nothing} #jdouble ( *CallDoubleMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue *args);

    CallVoidMethod::Ptr{Nothing} #void ( *CallVoidMethod) (JNIEnv *env, jobject obj, jmethodID methodID, ...);
    CallVoidMethodV::Ptr{Nothing} #void ( *CallVoidMethodV) (JNIEnv *env, jobject obj, jmethodID methodID, va_list args);
    CallVoidMethodA::Ptr{Nothing} #void ( *CallVoidMethodA) (JNIEnv *env, jobject obj, jmethodID methodID, const jvalue * args);

    CallNonvirtualObjectMethod::Ptr{Nothing} #jobject ( *CallNonvirtualObjectMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualObjectMethodV::Ptr{Nothing} #jobject ( *CallNonvirtualObjectMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualObjectMEthodA::Ptr{Nothing} #jobject ( *CallNonvirtualObjectMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue * args);

    CallNonvirtualBooleanMethod::Ptr{Nothing} #jboolean ( *CallNonvirtualBooleanMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualBooleanMethodV::Ptr{Nothing} #jboolean ( *CallNonvirtualBooleanMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualBooleanMethodA::Ptr{Nothing} #jboolean ( *CallNonvirtualBooleanMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue * args);

    CallNonvirtualByteMethod::Ptr{Nothing} #jbyte ( *CallNonvirtualByteMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualByteMethodV::Ptr{Nothing} #jbyte ( *CallNonvirtualByteMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualByteMethodA::Ptr{Nothing} #jbyte ( *CallNonvirtualByteMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualCharMethod::Ptr{Nothing} #jchar ( *CallNonvirtualCharMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualCharMethodV::Ptr{Nothing} #jchar ( *CallNonvirtualCharMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualCharMethodA::Ptr{Nothing} #jchar ( *CallNonvirtualCharMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualShortMethod::Ptr{Nothing} #jshort ( *CallNonvirtualShortMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualShortMethodV::Ptr{Nothing} #jshort ( *CallNonvirtualShortMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualShortMethodA::Ptr{Nothing} #jshort ( *CallNonvirtualShortMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualIntMethod::Ptr{Nothing} #jint ( *CallNonvirtualIntMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualIntMethodV::Ptr{Nothing} #jint ( *CallNonvirtualIntMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualIntMethodA::Ptr{Nothing} #jint ( *CallNonvirtualIntMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualLongMethod::Ptr{Nothing} #jlong ( *CallNonvirtualLongMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonVirtualLongMethodV::Ptr{Nothing} #jlong ( *CallNonvirtualLongMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualLongMethodA::Ptr{Nothing} #jlong ( *CallNonvirtualLongMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonVirtualFloatMethod::Ptr{Nothing} #jfloat ( *CallNonvirtualFloatMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualFloatMethodV::Ptr{Nothing} #jfloat ( *CallNonvirtualFloatMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualFloatMethodA::Ptr{Nothing} #jfloat ( *CallNonvirtualFloatMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue *args);

    CallNonvirtualDoubleMethod::Ptr{Nothing} # jdouble ( *CallNonvirtualDoubleMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualDoubleMethodV::Ptr{Nothing} # jdouble ( *CallNonvirtualDoubleMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualDoubleMethodA::Ptr{Nothing} # jdouble ( *CallNonvirtualDoubleMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID,  const jvalue *args);

    CallNonvirtualVoidMethod::Ptr{Nothing} # void ( *CallNonvirtualVoidMethod) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, ...);
    CallNonvirtualVoidMethodV::Ptr{Nothing} # void ( *CallNonvirtualVoidMethodV) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, va_list args);
    CallNonvirtualVoidMethodA::Ptr{Nothing} # void ( *CallNonvirtualVoidMethodA) (JNIEnv *env, jobject obj, jclass clazz, jmethodID methodID, const jvalue * args);

    GetFieldID::Ptr{Nothing} # jfieldID ( *GetFieldID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);

    GetObjectField::Ptr{Nothing} # jobject ( *GetObjectField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetBooleanField::Ptr{Nothing} # jboolean ( *GetBooleanField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetByteField::Ptr{Nothing} # jbyte ( *GetByteField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetCharField::Ptr{Nothing} # jchar ( *GetCharField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetShortField::Ptr{Nothing} # jshort ( *GetShortField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetIntField::Ptr{Nothing} # jint ( *GetIntField)  (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetLongField::Ptr{Nothing} # jlong ( *GetLongField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetFloatField::Ptr{Nothing} # jfloat ( *GetFloatField) (JNIEnv *env, jobject obj, jfieldID fieldID);
    GetDoubleField::Ptr{Nothing} # jdouble ( *GetDoubleField) (JNIEnv *env, jobject obj, jfieldID fieldID);

    SetObjectField::Ptr{Nothing} # void ( *SetObjectField) (JNIEnv *env, jobject obj, jfieldID fieldID, jobject val);
    SetBooleanField::Ptr{Nothing} # void ( *SetBooleanField) (JNIEnv *env, jobject obj, jfieldID fieldID, jboolean val);
    SetByteField::Ptr{Nothing} # void ( *SetByteField)  (JNIEnv *env, jobject obj, jfieldID fieldID, jbyte val);
    SetCharField::Ptr{Nothing} # void ( *SetCharField) (JNIEnv *env, jobject obj, jfieldID fieldID, jchar val);
    SetShortField::Ptr{Nothing} # void ( *SetShortField) (JNIEnv *env, jobject obj, jfieldID fieldID, jshort val);
    SetIntField::Ptr{Nothing} # void ( *SetIntField) (JNIEnv *env, jobject obj, jfieldID fieldID, jint val);
    SetLongField::Ptr{Nothing} # void ( *SetLongField) (JNIEnv *env, jobject obj, jfieldID fieldID, jlong val);
    SetFloatField::Ptr{Nothing} # void ( *SetFloatField) (JNIEnv *env, jobject obj, jfieldID fieldID, jfloat val);
    SetDoubleField::Ptr{Nothing} # void ( *SetDoubleField) (JNIEnv *env, jobject obj, jfieldID fieldID, jdouble val);

    GetStaticMethodID::Ptr{Nothing} # jmethodID ( *GetStaticMethodID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);

    CallStaticObjectMethod::Ptr{Nothing} # jobject ( *CallStaticObjectMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticObjectMethodV::Ptr{Nothing} #jobject ( *CallStaticObjectMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticObjectMethodA::Ptr{Nothing} # jobject ( *CallStaticObjectMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticBooleanMethod::Ptr{Nothing} # jboolean ( *CallStaticBooleanMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticBooleanMethodV::Ptr{Nothing} # jboolean ( *CallStaticBooleanMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticBooleanMethodA::Ptr{Nothing} # jboolean ( *CallStaticBooleanMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticByteMethod::Ptr{Nothing} #jbyte ( *CallStaticByteMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticByteMethodV::Ptr{Nothing} # jbyte ( *CallStaticByteMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticByteMethodA::Ptr{Nothing} #jbyte ( *CallStaticByteMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticCharMethod::Ptr{Nothing} # jchar ( *CallStaticCharMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticCharMethodV::Ptr{Nothing} # jchar ( *CallStaticCharMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticCharMethodA::Ptr{Nothing} # jchar ( *CallStaticCharMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticShortMethod::Ptr{Nothing} # jshort ( *CallStaticShortMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticShortMethodV::Ptr{Nothing} # jshort ( *CallStaticShortMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticShortMethodA::Ptr{Nothing} # jshort ( *CallStaticShortMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticIntMethod::Ptr{Nothing} #jint ( *CallStaticIntMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticIntMethodV::Ptr{Nothing} # jint ( *CallStaticIntMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticIntMethodA::Ptr{Nothing} # jint ( *CallStaticIntMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticLongMethod::Ptr{Nothing} # jlong ( *CallStaticLongMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticLongMethodV::Ptr{Nothing} # jlong ( *CallStaticLongMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticLongMethodA::Ptr{Nothing} # jlong ( *CallStaticLongMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticFloatMethod::Ptr{Nothing} # jfloat ( *CallStaticFloatMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticFloatMethodV::Ptr{Nothing} # jfloat ( *CallStaticFloatMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticFloatMethodA::Ptr{Nothing} # jfloat ( *CallStaticFloatMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticDoubleMethod::Ptr{Nothing} # jdouble ( *CallStaticDoubleMethod) (JNIEnv *env, jclass clazz, jmethodID methodID, ...);
    CallStaticDoubleMethodV::Ptr{Nothing} # jdouble ( *CallStaticDoubleMethodV) (JNIEnv *env, jclass clazz, jmethodID methodID, va_list args);
    CallStaticDoubleMethodA::Ptr{Nothing} # jdouble ( *CallStaticDoubleMethodA) (JNIEnv *env, jclass clazz, jmethodID methodID, const jvalue *args);

    CallStaticVoidMethod::Ptr{Nothing} # void ( *CallStaticVoidMethod) (JNIEnv *env, jclass cls, jmethodID methodID, ...);
    CallStaticVoidMethodV::Ptr{Nothing} # void ( *CallStaticVoidMethodV) (JNIEnv *env, jclass cls, jmethodID methodID, va_list args);
    CallStaticVoidMethodA::Ptr{Nothing} # void ( *CallStaticVoidMethodA) (JNIEnv *env, jclass cls, jmethodID methodID, const jvalue * args);

    GetStaticFieldID::Ptr{Nothing} # jfieldID ( *GetStaticFieldID) (JNIEnv *env, jclass clazz, const char *name, const char *sig);
    GetStaticObjectField::Ptr{Nothing} # jobject ( *GetStaticObjectField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticBooleanField::Ptr{Nothing} # jboolean ( *GetStaticBooleanField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticByteField::Ptr{Nothing} # jbyte ( *GetStaticByteField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticCharField::Ptr{Nothing} # jchar ( *GetStaticCharField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticShortField::Ptr{Nothing} # jshort ( *GetStaticShortField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticIntField::Ptr{Nothing} # jint ( *GetStaticIntField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticLongField::Ptr{Nothing} # jlong ( *GetStaticLongField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticFloatField::Ptr{Nothing} # jfloat ( *GetStaticFloatField) (JNIEnv *env, jclass clazz, jfieldID fieldID);
    GetStaticDoubleField::Ptr{Nothing} # jdouble ( *GetStaticDoubleField) (JNIEnv *env, jclass clazz, jfieldID fieldID);

    SetStaticObjectField::Ptr{Nothing} # void ( *SetStaticObjectField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jobject value);
    SetStaticBooleanField::Ptr{Nothing} # void ( *SetStaticBooleanField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jboolean value);
    SetStaticByteField::Ptr{Nothing} # void ( *SetStaticByteField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jbyte value);
    SetStaticCharField::Ptr{Nothing} # void ( *SetStaticCharField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jchar value);
    SetStaticShortField::Ptr{Nothing} # void ( *SetStaticShortField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jshort value);
    SetStaticIntField::Ptr{Nothing} # void ( *SetStaticIntField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jint value);
    SetStaticLongField::Ptr{Nothing} # void ( *SetStaticLongField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jlong value);
    SetStaticFloatField::Ptr{Nothing} # void ( *SetStaticFloatField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jfloat value);
    SetStaticDoubleField::Ptr{Nothing} # void ( *SetStaticDoubleField) (JNIEnv *env, jclass clazz, jfieldID fieldID, jdouble value);

    NewString::Ptr{Nothing} #::Ptr{Nothing} # jstring ( *NewString) (JNIEnv *env, const jchar *unicode, jsize len);
    GetStringLength::Ptr{Nothing} # jsize ( *GetStringLength) (JNIEnv *env, jstring str);
    GetStringChars::Ptr{Nothing} # const jchar *( *GetStringChars) (JNIEnv *env, jstring str, jboolean *isCopy);
    ReleaseStringChars::Ptr{Nothing} # void ( *ReleaseStringChars) (JNIEnv *env, jstring str, const jchar *chars);

    NewStringUTF::Ptr{Nothing} # jstring ( *NewStringUTF) (JNIEnv *env, const char *utf);
    GetStringUTFLength::Ptr{Nothing} # jsize ( *GetStringUTFLength) (JNIEnv *env, jstring str);
    GetStringUTFChars::Ptr{Nothing} # const char* ( *GetStringUTFChars) (JNIEnv *env, jstring str, jboolean *isCopy);
    ReleaseStringUTFChars::Ptr{Nothing} # void ( *ReleaseStringUTFChars) (JNIEnv *env, jstring str, const char* chars);


    GetArrayLength::Ptr{Nothing} # jsize ( *GetArrayLength ) (JNIEnv *env, jarray array);

    NewObjectArray::Ptr{Nothing} # jobjectArray ( *NewObjectArray) (JNIEnv *env, jsize len, jclass clazz, jobject init);
    GetObjectArrayElement::Ptr{Nothing} # jobject ( *GetObjectArrayElement) (JNIEnv *env, jobjectArray array, jsize index);
    SetObjectArrayElement::Ptr{Nothing} # void ( *SetObjectArrayElement) (JNIEnv *env, jobjectArray array, jsize index, jobject val);

    NewBooleanArray::Ptr{Nothing} # jbooleanArray ( *NewBooleanArray) (JNIEnv *env, jsize len);
    NewByteArray::Ptr{Nothing} # jbyteArray ( *NewByteArray) (JNIEnv *env, jsize len);
    NewCharArray::Ptr{Nothing} # jcharArray ( *NewCharArray) (JNIEnv *env, jsize len);
    NewShortArray::Ptr{Nothing} # jshortArray ( *NewShortArray) (JNIEnv *env, jsize len);
    NewIntArray::Ptr{Nothing} # jintArray ( *NewIntArray) (JNIEnv *env, jsize len);
    NewLongArray::Ptr{Nothing} # jlongArray ( *NewLongArray) (JNIEnv *env, jsize len);
    NewFloatArray::Ptr{Nothing} # jfloatArray ( *NewFloatArray) (JNIEnv *env, jsize len);
    NewDoubleArray::Ptr{Nothing} # jdoubleArray ( *NewDoubleArray) (JNIEnv *env, jsize len);

    GetBooleanArrayElements::Ptr{Nothing} # jboolean * ( *GetBooleanArrayElements) (JNIEnv *env, jbooleanArray array, jboolean *isCopy);
    GetByteArrayElements::Ptr{Nothing} # jbyte * ( *GetByteArrayElements) (JNIEnv *env, jbyteArray array, jboolean *isCopy);
    GetCharArrayElements::Ptr{Nothing} # jchar * ( *GetCharArrayElements) (JNIEnv *env, jcharArray array, jboolean *isCopy);
    GetShortArrayElements::Ptr{Nothing} # jshort * ( *GetShortArrayElements) (JNIEnv *env, jshortArray array, jboolean *isCopy);
    GetIntArrayElements::Ptr{Nothing} # jint * ( *GetIntArrayElements) (JNIEnv *env, jintArray array, jboolean *isCopy);
    GetLongArrayElements::Ptr{Nothing} # jlong * ( *GetLongArrayElements ) (JNIEnv *env, jlongArray array, jboolean *isCopy);
    GetFloatArrayElements::Ptr{Nothing} # jfloat * ( *GetFloatArrayElements) (JNIEnv *env, jfloatArray array, jboolean *isCopy);
    GetDoubleArrayElements::Ptr{Nothing} # jdouble * ( *GetDoubleArrayElements) (JNIEnv *env, jdoubleArray array, jboolean *isCopy);

    ReleaseBooleanArrayElements::Ptr{Nothing} # void ( *ReleaseBooleanArrayElements ) (JNIEnv *env, jbooleanArray array, jboolean *elems, jint mode);
    ReleaseByteArrayElements::Ptr{Nothing} # void ( *ReleaseByteArrayElements ) (JNIEnv *env, jbyteArray array, jbyte *elems, jint mode);
    ReleaseCharArrayElements::Ptr{Nothing} # void ( *ReleaseCharArrayElements ) (JNIEnv *env, jcharArray array, jchar *elems, jint mode);
    ReleaseShortArrayElements::Ptr{Nothing} # void ( *ReleaseShortArrayElements) (JNIEnv *env, jshortArray array, jshort *elems, jint mode);
    ReleaseIntArrayElements::Ptr{Nothing} # void ( *ReleaseIntArrayElements) (JNIEnv *env, jintArray array, jint *elems, jint mode);
    ReleaseLongArrayElements::Ptr{Nothing} # void ( *ReleaseLongArrayElements ) (JNIEnv *env, jlongArray array, jlong *elems, jint mode);
    ReleaseFloatArrayElements::Ptr{Nothing} # void ( *ReleaseFloatArrayElements) (JNIEnv *env, jfloatArray array, jfloat *elems, jint mode);
    ReleaseDoubleArrayElements::Ptr{Nothing} # void ( *ReleaseDoubleArrayElements ) (JNIEnv *env, jdoubleArray array, jdouble *elems, jint mode);

    GetBooleanArrayRegion::Ptr{Nothing} # void ( *GetBooleanArrayRegion ) (JNIEnv *env, jbooleanArray array, jsize start, jsize l, jboolean *buf);
    GetByteArrayRegion::Ptr{Nothing} # void ( *GetByteArrayRegion) (JNIEnv *env, jbyteArray array, jsize start, jsize len, jbyte *buf);
    vGetCharArrayRegion::Ptr{Nothing} # void ( *GetCharArrayRegion) (JNIEnv *env, jcharArray array, jsize start, jsize len, jchar *buf);
    GetShortArrayRegion::Ptr{Nothing} # void ( *GetShortArrayRegion ) (JNIEnv *env, jshortArray array, jsize start, jsize len, jshort *buf);
    GetIntArrayRegion::Ptr{Nothing} # void ( *GetIntArrayRegion ) (JNIEnv *env, jintArray array, jsize start, jsize len, jint *buf);
    GetLongArrayRegion::Ptr{Nothing} # void ( *GetLongArrayRegion) (JNIEnv *env, jlongArray array, jsize start, jsize len, jlong *buf);
    GetFloatArrayRegion::Ptr{Nothing} # void ( *GetFloatArrayRegion) (JNIEnv *env, jfloatArray array, jsize start, jsize len, jfloat *buf);
    GetDoubleArrayRegion::Ptr{Nothing} # void ( *GetDoubleArrayRegion) (JNIEnv *env, jdoubleArray array, jsize start, jsize len, jdouble *buf);

    SetBooleanArrayRegion::Ptr{Nothing} # void ( *SetBooleanArrayRegion )(JNIEnv *env, jbooleanArray array, jsize start, jsize l, const jboolean *buf);
    SetByteArrayRegion::Ptr{Nothing} # void ( *SetByteArrayRegion) (JNIEnv *env, jbyteArray array, jsize start, jsize len, const jbyte *buf);
    SetCharArrayRegion::Ptr{Nothing} # void ( *SetCharArrayRegion) (JNIEnv *env, jcharArray array, jsize start, jsize len, const jchar *buf);
    SetShortArrayRegion::Ptr{Nothing} # void ( *SetShortArrayRegion ) (JNIEnv *env, jshortArray array, jsize start, jsize len, const jshort *buf);
    SetIntArrayRegion::Ptr{Nothing} # void ( *SetIntArrayRegion) (JNIEnv *env, jintArray array, jsize start, jsize len, const jint *buf);
    SetLongArrayRegion::Ptr{Nothing} # void ( *SetLongArrayRegion) (JNIEnv *env, jlongArray array, jsize start, jsize len, const jlong *buf);
    SetFloatArrayRegion::Ptr{Nothing} # void ( *SetFloatArrayRegion ) (JNIEnv *env, jfloatArray array, jsize start, jsize len, const jfloat *buf);
    SetDoubleArrayRegion::Ptr{Nothing} # void ( *SetDoubleArrayRegion) (JNIEnv *env, jdoubleArray array, jsize start, jsize len, const jdouble *buf);

    RegisterNatives::Ptr{Nothing} # jint ( *RegisterNatives) (JNIEnv *env, jclass clazz, const JNINativeMethod *methods, jint nMethods);
    UnregisterNatives::Ptr{Nothing} # jint ( *UnregisterNatives ) (JNIEnv *env, jclass clazz);

    MonitorEnter::Ptr{Nothing} # jint ( *MonitorEnter) (JNIEnv *env, jobject obj);
    MonitorExit::Ptr{Nothing} # jint ( *MonitorExit ) (JNIEnv *env, jobject obj);

    GetJavaVM::Ptr{Nothing} # jint ( *GetJavaVM) (JNIEnv *env, JavaVM **vm);

    GetStringRegion::Ptr{Nothing} # void ( *GetStringRegion ) (JNIEnv *env, jstring str, jsize start, jsize len, jchar *buf);
    GetStringUTFRegion::Ptr{Nothing} # void ( *GetStringUTFRegion) (JNIEnv *env, jstring str, jsize start, jsize len, char *buf);

    GetPrimitiveArrayCritical::Ptr{Nothing} # void * ( *GetPrimitiveArrayCritical) (JNIEnv *env, jarray array, jboolean *isCopy);
    ReleasePrimitiveArrayCritical::Ptr{Nothing} # void ( *ReleasePrimitiveArrayCritical ) (JNIEnv *env, jarray array, void *carray, jint mode);

    GetStringCritical::Ptr{Nothing} # const jchar * ( *GetStringCritical ) (JNIEnv *env, jstring string, jboolean *isCopy);
    ReleaseStringCritical::Ptr{Nothing} # void ( *ReleaseStringCritical ) (JNIEnv *env, jstring string, const jchar *cstring);

    NewWeakGlobalRef::Ptr{Nothing} # jweak ( *NewWeakGlobalRef) (JNIEnv *env, jobject obj);
    DeleteWeakGlobalRef::Ptr{Nothing} # void ( *DeleteWeakGlobalRef) (JNIEnv *env, jweak ref);

    ExceptionCheck::Ptr{Nothing} # jboolean ( *ExceptionCheck) (JNIEnv *env);

    NewDirectByteBuffer::Ptr{Nothing} # jobject ( *NewDirectByteBuffer ) (JNIEnv* env, void* address, jlong capacity);
    GetDirectBufferAddress::Ptr{Nothing} # void* ( *GetDirectBufferAddress ) (JNIEnv* env, jobject buf);
    GetDirectBufferCapacity::Ptr{Nothing} # jlong ( *GetDirectBufferCapacity) (JNIEnv* env, jobject buf);

    #/* New JNI 1.6 Features */

    GetObjectRefType::Ptr{Nothing} # jobjectRefType ( *GetObjectRefType) (JNIEnv* env, jobject obj);
end #};

struct JNIEnv
    JNINativeInterface_::Ptr{JNINativeInterface}
end

struct JNIInvokeInterface #struct JNIInvokeInterface_ {
    reserved0::Ptr{Nothing} #void *reserved0;
    reserved1::Ptr{Nothing} #vvoid *reserved1;
    reserved2::Ptr{Nothing} #vvoid *reserved2;

    DestroyJavaVM::Ptr{Nothing} #jint (JNICALL *DestroyJavaVM)(JavaVM *vm);

    AttachCurrentThread::Ptr{Nothing} #jint (JNICALL *AttachCurrentThread)(JavaVM *vm, void **penv, void *args);

    DetachCurrentThread::Ptr{Nothing} #jint (JNICALL *DetachCurrentThread)(JavaVM *vm);

    GetEnv::Ptr{Nothing} #jint (JNICALL *GetEnv)(JavaVM *vm, void **penv, jint version);

    AttachCurrentThreadAsDaemon::Ptr{Nothing} #jint (JNICALL *AttachCurrentThreadAsDaemon)(JavaVM *vm, void **penv, void *args);
end

struct JavaVM
    JNIInvokeInterface_::Ptr{JNIInvokeInterface}
end

struct JavaCallError <: Exception
    msg::String
end
