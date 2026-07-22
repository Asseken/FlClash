// core.cpp - JNI bridge that dynamically loads libclash*.so via dlopen/dlsym.
// No compile-time DT_NEEDED dependency on libclash.so, so the loaded library
// can have any filename (e.g. libclashn1928.so).

#include <jni.h>
#include <dlfcn.h>
#include <android/log.h>
#include <cstdlib>
#include <cstring>

#include "jni_helper.h"

#define LOG_TAG "CoreBridge"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ---- Typedefs for libclash.so exported C functions (from libclash.h) ----

typedef void        (*invokeAction_fn)(void*, char*);
typedef unsigned char (*startTUN_fn)(void*, int, char*, char*, char*);
typedef void        (*quickSetup_fn)(void*, char*, char*);
typedef void        (*setEventListener_fn)(void*);
typedef char*       (*getTraffic_fn)(unsigned char);
typedef char*       (*getTotalTraffic_fn)(unsigned char);
typedef char*       (*getDirectTraffic_fn)();
typedef char*       (*getDirectTotalTraffic_fn)();
typedef void        (*stopTun_fn)();
typedef void        (*suspend_fn)(unsigned char);
typedef void        (*forceGC_fn)();
typedef void        (*updateDns_fn)(char*);

// ---- Loaded function pointers (initially NULL = stub/no-op) ----

static invokeAction_fn         g_invokeAction = nullptr;
static startTUN_fn             g_startTUN = nullptr;
static quickSetup_fn           g_quickSetup = nullptr;
static setEventListener_fn     g_setEventListener = nullptr;
static getTraffic_fn           g_getTraffic = nullptr;
static getTotalTraffic_fn      g_getTotalTraffic = nullptr;
static getDirectTraffic_fn     g_getDirectTraffic = nullptr;
static getDirectTotalTraffic_fn g_getDirectTotalTraffic = nullptr;
static stopTun_fn              g_stopTun = nullptr;
static suspend_fn              g_suspend = nullptr;
static forceGC_fn              g_forceGC = nullptr;
static updateDns_fn            g_updateDns = nullptr;

// ---- JNI method ID cache (from JNI_OnLoad / JNI setup) ----

static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_process;
static jmethodID m_invoke_interface_result;

// ---- JNI callback implementations passed to libclash.so as bride callbacks ----

static void release_jni_object_impl(void *obj) {
    ATTACH_JNI();
    del_global(static_cast<jobject>(obj));
}

static void free_string_impl(char *str) {
    free(str);
}

static void call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(tun_interface),
                        m_tun_interface_protect,
                        fd);
}

static char*
call_tun_interface_resolve_process_impl(void *tun_interface, const int protocol,
                                        const char *source,
                                        const char *target,
                                        const int uid) {
    // Push a local frame so that all local refs created inside (new_string,
    // CallObjectMethod, etc.) are freed when we PopLocalFrame. This callback is
    // called from Go / C on a non-Java thread and local refs would otherwise
    // accumulate and overflow the local reference table (default 512 entries).
    ATTACH_JNI();
    if (env->PushLocalFrame(16) < 0) {
        // Out of memory — bail out gracefully
        return nullptr;
    }
    const auto packageName = reinterpret_cast<jstring>(env->CallObjectMethod(
            static_cast<jobject>(tun_interface),
            m_tun_interface_resolve_process,
            protocol,
            new_string(source),
            new_string(target),
            uid));
    // get_string() malloc's the result in native heap, so it survives the pop.
    char *result = get_string(packageName);
    env->PopLocalFrame(nullptr);
    return result;
}

static void call_invoke_interface_result_impl(void *invoke_interface, const char *data) {
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(invoke_interface),
                        m_invoke_interface_result,
                        new_string(data));
}

// ---- nativeInitClash: dlopen + dlsym, called after System.load(libcore.so) ----

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_follow_clash_core_Core_nativeInitClash(JNIEnv *env, jobject /*thiz*/,
                                                jstring libPath) {
    const char *path = env->GetStringUTFChars(libPath, nullptr);
    LOGD("dlopen: %s", path);

    void *handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if (!handle) {
        LOGE("dlopen failed: %s", dlerror());
        env->ReleaseStringUTFChars(libPath, path);
        return JNI_FALSE;
    }
    LOGD("dlopen succeeded");

    // Resolve all Go-exported C functions (from libclash.h).
    // Critical symbols: if any of these fails to resolve, the core cannot function.
    // Non-critical symbols stay NULL and the corresponding JNI methods are no-ops.

    g_invokeAction      = (invokeAction_fn)     dlsym(handle, "invokeAction");
    g_startTUN          = (startTUN_fn)         dlsym(handle, "startTUN");
    g_quickSetup        = (quickSetup_fn)       dlsym(handle, "quickSetup");
    g_setEventListener  = (setEventListener_fn) dlsym(handle, "setEventListener");
    g_getTraffic        = (getTraffic_fn)       dlsym(handle, "getTraffic");
    g_getTotalTraffic   = (getTotalTraffic_fn)  dlsym(handle, "getTotalTraffic");
    g_getDirectTraffic  = (getDirectTraffic_fn) dlsym(handle, "getDirectTraffic");
    g_getDirectTotalTraffic = (getDirectTotalTraffic_fn) dlsym(handle, "getDirectTotalTraffic");
    g_stopTun           = (stopTun_fn)          dlsym(handle, "stopTun");
    g_suspend           = (suspend_fn)          dlsym(handle, "suspend");
    g_forceGC           = (forceGC_fn)          dlsym(handle, "forceGC");
    g_updateDns         = (updateDns_fn)        dlsym(handle, "updateDns");

    // Require the four entry-point functions — without these the core is unusable.
    if (!g_invokeAction || !g_startTUN || !g_quickSetup || !g_setEventListener) {
        LOGE("Critical symbol(s) missing: invokeAction=%p startTUN=%p quickSetup=%p setEventListener=%p",
             (void*)g_invokeAction, (void*)g_startTUN, (void*)g_quickSetup, (void*)g_setEventListener);
        dlclose(handle);
        env->ReleaseStringUTFChars(libPath, path);
        return JNI_FALSE;
    }

    // Set bride function POINTERS defined in libclash.so as extern variables.
    // These are global variables inside the loaded .so.
    void **protect_func_ptr         = (void**)dlsym(handle, "protect_func");
    void **resolve_process_func_ptr = (void**)dlsym(handle, "resolve_process_func");
    void **result_func_ptr          = (void**)dlsym(handle, "result_func");
    void **release_object_func_ptr  = (void**)dlsym(handle, "release_object_func");
    void **free_string_func_ptr     = (void**)dlsym(handle, "free_string_func");

    if (protect_func_ptr)
        *protect_func_ptr = (void*)&call_tun_interface_protect_impl;
    if (resolve_process_func_ptr)
        *resolve_process_func_ptr = (void*)&call_tun_interface_resolve_process_impl;
    if (result_func_ptr)
        *result_func_ptr = (void*)&call_invoke_interface_result_impl;
    if (release_object_func_ptr)
        *release_object_func_ptr = (void*)&release_jni_object_impl;
    if (free_string_func_ptr)
        *free_string_func_ptr = (void*)&free_string_impl;

    env->ReleaseStringUTFChars(libPath, path);
    LOGD("nativeInitClash completed");
    return JNI_TRUE;
}

// ---- JNI_OnLoad: JNI setup only, no libclash.so dependency ----

extern "C"
JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    initialize_jni(vm, env);

    const auto c_tun_interface = find_class("com/follow/clash/core/TunInterface");
    const auto c_invoke_interface = find_class("com/follow/clash/core/InvokeInterface");

    m_tun_interface_protect = find_method(c_tun_interface, "protect", "(I)V");
    m_tun_interface_resolve_process = find_method(c_tun_interface, "resolverProcess",
                                                  "(ILjava/lang/String;Ljava/lang/String;I)Ljava/lang/String;");
    m_invoke_interface_result = find_method(c_invoke_interface, "onResult",
                                            "(Ljava/lang/String;)V");

    LOGD("JNI_OnLoad complete");
    return JNI_VERSION_1_6;
}

// ---- JNI methods (call through function pointers or no-op if not loaded) ----

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_startTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
        jstring stack, jstring address, jstring dns) {
if (!g_startTUN) return;
const auto interface = new_global(cb);
g_startTUN(interface, fd, get_string(stack), get_string(address), get_string(dns));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_stopTun(JNIEnv *env, jobject thiz) {
if (g_stopTun) g_stopTun();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_forceGC(JNIEnv *env, jobject thiz) {
if (g_forceGC) g_forceGC();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_updateDNS(JNIEnv *env, jobject thiz, jstring dns) {
if (g_updateDns) g_updateDns(get_string(dns));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_invokeAction(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
if (!g_invokeAction) return;
const auto interface = new_global(cb);
g_invokeAction(interface, get_string(data));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_setEventListener(JNIEnv *env, jobject thiz, jobject cb) {
if (!g_setEventListener) return;
if (cb != nullptr) {
const auto interface = new_global(cb);
g_setEventListener(interface);
} else {
g_setEventListener(nullptr);
}
}

extern "C"
JNIEXPORT jstring JNICALL
        Java_com_follow_clash_core_Core_getTraffic(JNIEnv *env, jobject thiz,
const jboolean only_statistics_proxy) {
if (!g_getTraffic) return new_string("");
return new_string(g_getTraffic(only_statistics_proxy));
}

extern "C"
JNIEXPORT jstring JNICALL
        Java_com_follow_clash_core_Core_getTotalTraffic(JNIEnv *env, jobject thiz,
const jboolean only_statistics_proxy) {
if (!g_getTotalTraffic) return new_string("");
return new_string(g_getTotalTraffic(only_statistics_proxy));
}

extern "C"
JNIEXPORT jstring JNICALL
        Java_com_follow_clash_core_Core_getDirectTraffic(JNIEnv *env, jobject thiz) {
if (!g_getDirectTraffic) return new_string("");
return new_string(g_getDirectTraffic());
}

extern "C"
JNIEXPORT jstring JNICALL
        Java_com_follow_clash_core_Core_getDirectTotalTraffic(JNIEnv *env, jobject thiz) {
if (!g_getDirectTotalTraffic) return new_string("");
return new_string(g_getDirectTotalTraffic());
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_suspended(JNIEnv *env, jobject thiz, jboolean suspended) {
if (g_suspend) g_suspend(suspended);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_quickSetup(JNIEnv *env, jobject thiz,
        jstring init_params_string,
jstring setup_params_string, jobject cb) {
if (!g_quickSetup) return;
const auto interface = new_global(cb);
g_quickSetup(interface, get_string(init_params_string), get_string(setup_params_string));
}
