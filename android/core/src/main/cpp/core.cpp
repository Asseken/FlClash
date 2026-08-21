#include <jni.h>

#include <android/log.h>
#include <dlfcn.h>

#include <cstdlib>
#include <cstring>

#include "jni_helper.h"

// The Go core is no longer linked through DT_NEEDED. nativeInitClash opens the
// chosen libclash*.so at runtime and resolves every exported symbol once, so
// the core file can carry a versioned name and be upgraded without rebuilding
// the JNI bridge. The callback function pointers defined by the Go core
// (bride.c globals) are located through dlsym and repointed at the JNI
// implementations below, so libcore.so keeps no link-time dependency on
// libclash.so.

typedef unsigned char (*start_tun_fn)(void *callback, int fd, char *stack,
                                      char *address, char *dns);
typedef void (*invoke_method_fn)(void *callback, char *params);
typedef void (*quick_setup_fn)(void *callback, char *init_params,
                               char *setup_params);
typedef void (*set_event_listener_fn)(void *listener);
typedef char *(*get_total_traffic_fn)(unsigned char only_statistics_proxy);
typedef char *(*get_traffic_fn)(unsigned char only_statistics_proxy);
typedef char *(*get_direct_total_traffic_fn)(void);
typedef char *(*get_direct_traffic_fn)(void);
typedef void (*stop_tun_fn)(void);
typedef void (*suspend_fn)(unsigned char suspended);
typedef void (*force_gc_fn)(void);
typedef void (*update_dns_fn)(char *dns);

static void *clash_handle = nullptr;

static start_tun_fn fn_start_tun = nullptr;
static invoke_method_fn fn_invoke_method = nullptr;
static quick_setup_fn fn_quick_setup = nullptr;
static set_event_listener_fn fn_set_event_listener = nullptr;
static get_total_traffic_fn fn_get_total_traffic = nullptr;
static get_traffic_fn fn_get_traffic = nullptr;
static get_direct_total_traffic_fn fn_get_direct_total_traffic = nullptr;
static get_direct_traffic_fn fn_get_direct_traffic = nullptr;
static stop_tun_fn fn_stop_tun = nullptr;
static suspend_fn fn_suspend = nullptr;
static force_gc_fn fn_force_gc = nullptr;
static update_dns_fn fn_update_dns = nullptr;

static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_process;
static jmethodID m_invoke_interface_result;

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

static char *
call_tun_interface_resolve_process_impl(void *tun_interface, const int protocol,
                                        const char *source,
                                        const char *target,
                                        const int uid) {
    ATTACH_JNI();
    const auto source_string = new_string(source);
    const auto target_string = new_string(target);
    const auto package_name = reinterpret_cast<jstring>(env->CallObjectMethod(
            static_cast<jobject>(tun_interface),
            m_tun_interface_resolve_process,
            protocol,
            source_string,
            target_string,
            uid));
    env->DeleteLocalRef(source_string);
    env->DeleteLocalRef(target_string);
    const auto result = get_string(package_name);
    if (package_name != nullptr) {
        env->DeleteLocalRef(package_name);
    }
    return result;
}

static void call_invoke_interface_result_impl(void *invoke_interface, const char *data) {
    ATTACH_JNI();
    const auto value = new_string(data);
    env->CallVoidMethod(static_cast<jobject>(invoke_interface),
                        m_invoke_interface_result,
                        value);
    env->DeleteLocalRef(value);
}

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

    return JNI_VERSION_1_6;
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_follow_clash_core_Core_nativeInitClash(JNIEnv *env, jobject thiz, jstring lib_path) {
    const auto path = env->GetStringUTFChars(lib_path, nullptr);
    if (path == nullptr) {
        return JNI_FALSE;
    }

    void *handle = dlopen(path, RTLD_NOW);
    if (handle == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR, "Core",
                            "dlopen failed for %s: %s", path, dlerror());
        env->ReleaseStringUTFChars(lib_path, path);
        return JNI_FALSE;
    }

    const auto resolve = [handle](const char *name) -> void * {
        void *symbol = dlsym(handle, name);
        if (symbol == nullptr) {
            __android_log_print(ANDROID_LOG_ERROR, "Core",
                                "dlsym failed for %s: %s", name, dlerror());
        }
        return symbol;
    };

    const auto new_start_tun = reinterpret_cast<start_tun_fn>(resolve("startTUN"));
    const auto new_invoke_method = reinterpret_cast<invoke_method_fn>(resolve("invokeMethod"));
    const auto new_quick_setup = reinterpret_cast<quick_setup_fn>(resolve("quickSetup"));
    const auto new_set_event_listener = reinterpret_cast<set_event_listener_fn>(resolve("setEventListener"));
    const auto new_get_total_traffic = reinterpret_cast<get_total_traffic_fn>(resolve("getTotalTraffic"));
    const auto new_get_traffic = reinterpret_cast<get_traffic_fn>(resolve("getTraffic"));
    const auto new_get_direct_total_traffic = reinterpret_cast<get_direct_total_traffic_fn>(resolve("getDirectTotalTraffic"));
    const auto new_get_direct_traffic = reinterpret_cast<get_direct_traffic_fn>(resolve("getDirectTraffic"));
    const auto new_stop_tun = reinterpret_cast<stop_tun_fn>(resolve("stopTun"));
    const auto new_suspend = reinterpret_cast<suspend_fn>(resolve("suspend"));
    const auto new_force_gc = reinterpret_cast<force_gc_fn>(resolve("forceGC"));
    const auto new_update_dns = reinterpret_cast<update_dns_fn>(resolve("updateDns"));

    if (new_start_tun == nullptr ||
        new_invoke_method == nullptr ||
        new_quick_setup == nullptr ||
        new_set_event_listener == nullptr ||
        new_get_total_traffic == nullptr ||
        new_get_traffic == nullptr ||
        new_get_direct_total_traffic == nullptr ||
        new_get_direct_traffic == nullptr ||
        new_stop_tun == nullptr ||
        new_suspend == nullptr ||
        new_force_gc == nullptr ||
        new_update_dns == nullptr) {
        dlclose(handle);
        env->ReleaseStringUTFChars(lib_path, path);
        return JNI_FALSE;
    }

    // The Go core defines its callback function pointers (bride.c globals) in
    // libclash.so. Repoint them at the JNI implementations above.
    const auto bind = [handle](const char *name, void *impl) -> bool {
        void *slot = dlsym(handle, name);
        if (slot == nullptr) {
            __android_log_print(ANDROID_LOG_ERROR, "Core",
                                "dlsym failed for %s: %s", name, dlerror());
            return false;
        }
        *static_cast<void **>(slot) = impl;
        return true;
    };
    if (!bind("protect_func", reinterpret_cast<void *>(&call_tun_interface_protect_impl)) ||
        !bind("resolve_process_func", reinterpret_cast<void *>(&call_tun_interface_resolve_process_impl)) ||
        !bind("result_func", reinterpret_cast<void *>(&call_invoke_interface_result_impl)) ||
        !bind("release_object_func", reinterpret_cast<void *>(&release_jni_object_impl)) ||
        !bind("free_string_func", reinterpret_cast<void *>(&free_string_impl))) {
        dlclose(handle);
        env->ReleaseStringUTFChars(lib_path, path);
        return JNI_FALSE;
    }

    if (clash_handle != nullptr) {
        dlclose(clash_handle);
    }
    clash_handle = handle;
    fn_start_tun = new_start_tun;
    fn_invoke_method = new_invoke_method;
    fn_quick_setup = new_quick_setup;
    fn_set_event_listener = new_set_event_listener;
    fn_get_total_traffic = new_get_total_traffic;
    fn_get_traffic = new_get_traffic;
    fn_get_direct_total_traffic = new_get_direct_total_traffic;
    fn_get_direct_traffic = new_get_direct_traffic;
    fn_stop_tun = new_stop_tun;
    fn_suspend = new_suspend;
    fn_force_gc = new_force_gc;
    fn_update_dns = new_update_dns;

    env->ReleaseStringUTFChars(lib_path, path);
    return JNI_TRUE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_startTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
                                         jstring stack, jstring address, jstring dns) {
    const auto interface = new_global(cb);
    fn_start_tun(interface, fd, get_string(stack), get_string(address), get_string(dns));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_stopTun(JNIEnv *env, jobject thiz) {
    fn_stop_tun();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_forceGC(JNIEnv *env, jobject thiz) {
    fn_force_gc();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_updateDNS(JNIEnv *env, jobject thiz, jstring dns) {
    fn_update_dns(get_string(dns));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_invokeAction(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
    const auto interface = new_global(cb);
    fn_invoke_method(interface, get_string(data));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_setEventListener(JNIEnv *env, jobject thiz, jobject cb) {
    if (cb != nullptr) {
        const auto interface = new_global(cb);
        fn_set_event_listener(interface);
    } else {
        fn_set_event_listener(nullptr);
    }
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTraffic(JNIEnv *env, jobject thiz,
                                           const jboolean only_statistics_proxy) {
    scoped_string traffic = fn_get_traffic(static_cast<unsigned char>(only_statistics_proxy));
    return new_string(traffic);
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTotalTraffic(JNIEnv *env, jobject thiz,
                                                const jboolean only_statistics_proxy) {
    scoped_string traffic = fn_get_total_traffic(static_cast<unsigned char>(only_statistics_proxy));
    return new_string(traffic);
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getDirectTraffic(JNIEnv *env, jobject thiz) {
    scoped_string traffic = fn_get_direct_traffic();
    return new_string(traffic);
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getDirectTotalTraffic(JNIEnv *env, jobject thiz) {
    scoped_string traffic = fn_get_direct_total_traffic();
    return new_string(traffic);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_suspended(JNIEnv *env, jobject thiz, jboolean suspended) {
    fn_suspend(static_cast<unsigned char>(suspended));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_quickSetup(JNIEnv *env, jobject thiz, jstring init_params_string,
                                           jstring setup_params_string, jobject cb) {
    const auto interface = new_global(cb);
    fn_quick_setup(interface, get_string(init_params_string), get_string(setup_params_string));
}
