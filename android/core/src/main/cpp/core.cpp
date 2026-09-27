#include <jni.h>

#include <android/log.h>
#include <dlfcn.h>

#include <cstring>

#include "jni_helper.h"
#include "libclash.h"

// The Go Core is opened at runtime instead of being linked through DT_NEEDED, so
// the file that gets loaded can carry a versioned name and be replaced without
// rebuilding this bridge. nativeInitClash resolves every entry point the vendored
// Core headers declare, and repoints the callback globals from bride.h at the JNI
// implementations below. The function pointer types come from libclash.h, so a
// Core ABI change breaks the build instead of mismatching silently at call time.

static void *clash_handle = nullptr;

static decltype(&startTUN) fn_start_tun = nullptr;
static decltype(&invokeMethod) fn_invoke_method = nullptr;
static decltype(&quickSetup) fn_quick_setup = nullptr;
static decltype(&setEventListener) fn_set_event_listener = nullptr;
static decltype(&getTotalTraffic) fn_get_total_traffic = nullptr;
static decltype(&getTraffic) fn_get_traffic = nullptr;
static decltype(&getDirectTotalTraffic) fn_get_direct_total_traffic = nullptr;
static decltype(&getDirectTraffic) fn_get_direct_traffic = nullptr;
static decltype(&stopTun) fn_stop_tun = nullptr;
static decltype(&suspend) fn_suspend = nullptr;
static decltype(&forceGC) fn_force_gc = nullptr;
static decltype(&updateDns) fn_update_dns = nullptr;

static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_uid;
static jmethodID m_tun_interface_resolve_package;
static jmethodID m_invoke_interface_result;

static void release_jni_object_impl(void *obj) {
    ATTACH_JNI();
    del_global(static_cast<jobject>(obj));
}

static void free_string_impl(char *str) {
    free(str);
}

static int call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    // ART aborts the process on a call through a null object, so a callback
    // that was already released has to stop here rather than at the JNI call.
    if (tun_interface == nullptr) {
        return 0;
    }
    ATTACH_JNI();
    const auto accepted = env->CallBooleanMethod(static_cast<jobject>(tun_interface),
                                                 m_tun_interface_protect,
                                                 fd);
    if (jni_clear_exception(env)) {
        return 0;
    }
    return accepted == JNI_TRUE ? 1 : 0;
}

static int call_tun_interface_resolve_uid_impl(void *tun_interface, const int protocol,
                                               const char *source,
                                               const char *target) {
    if (tun_interface == nullptr) {
        return -1;
    }
    ATTACH_JNI();
    const auto source_string = new_string(source);
    const auto target_string = new_string(target);
    const auto uid = env->CallIntMethod(static_cast<jobject>(tun_interface),
                                        m_tun_interface_resolve_uid,
                                        protocol,
                                        source_string,
                                        target_string);
    const auto failed = jni_clear_exception(env);
    if (source_string != nullptr) {
        env->DeleteLocalRef(source_string);
    }
    if (target_string != nullptr) {
        env->DeleteLocalRef(target_string);
    }
    return failed ? -1 : uid;
}

static char *call_tun_interface_resolve_package_impl(void *tun_interface, const int uid) {
    if (tun_interface == nullptr) {
        return strdup("");
    }
    ATTACH_JNI();
    const auto package_name = reinterpret_cast<jstring>(env->CallObjectMethod(
            static_cast<jobject>(tun_interface),
            m_tun_interface_resolve_package,
            uid));
    jni_clear_exception(env);
    const auto result = get_string(package_name);
    if (package_name != nullptr) {
        env->DeleteLocalRef(package_name);
    }
    return result;
}

static void call_invoke_interface_result_impl(void *invoke_interface, const char *data) {
    if (invoke_interface == nullptr) {
        return;
    }
    ATTACH_JNI();
    const auto value = new_string(data);
    env->CallVoidMethod(static_cast<jobject>(invoke_interface),
                        m_invoke_interface_result,
                        value);
    jni_clear_exception(env);
    if (value != nullptr) {
        env->DeleteLocalRef(value);
    }
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
        __android_log_print(ANDROID_LOG_ERROR, "Core", "dlopen failed for %s: %s", path, dlerror());
        env->ReleaseStringUTFChars(lib_path, path);
        return JNI_FALSE;
    }

    const auto resolve = [handle](const char *name) -> void * {
        void *symbol = dlsym(handle, name);
        if (symbol == nullptr) {
            __android_log_print(ANDROID_LOG_ERROR, "Core", "dlsym failed for %s: %s", name,
                                dlerror());
        }
        return symbol;
    };

    const auto new_start_tun = reinterpret_cast<decltype(&startTUN)>(resolve("startTUN"));
    const auto new_invoke_method =
            reinterpret_cast<decltype(&invokeMethod)>(resolve("invokeMethod"));
    const auto new_quick_setup = reinterpret_cast<decltype(&quickSetup)>(resolve("quickSetup"));
    const auto new_set_event_listener =
            reinterpret_cast<decltype(&setEventListener)>(resolve("setEventListener"));
    const auto new_get_total_traffic =
            reinterpret_cast<decltype(&getTotalTraffic)>(resolve("getTotalTraffic"));
    const auto new_get_traffic = reinterpret_cast<decltype(&getTraffic)>(resolve("getTraffic"));
    const auto new_get_direct_total_traffic =
            reinterpret_cast<decltype(&getDirectTotalTraffic)>(resolve("getDirectTotalTraffic"));
    const auto new_get_direct_traffic =
            reinterpret_cast<decltype(&getDirectTraffic)>(resolve("getDirectTraffic"));
    const auto new_stop_tun = reinterpret_cast<decltype(&stopTun)>(resolve("stopTun"));
    const auto new_suspend = reinterpret_cast<decltype(&suspend)>(resolve("suspend"));
    const auto new_force_gc = reinterpret_cast<decltype(&forceGC)>(resolve("forceGC"));
    const auto new_update_dns = reinterpret_cast<decltype(&updateDns)>(resolve("updateDns"));

    if (new_start_tun == nullptr || new_invoke_method == nullptr ||
        new_quick_setup == nullptr || new_set_event_listener == nullptr ||
        new_get_total_traffic == nullptr || new_get_traffic == nullptr ||
        new_get_direct_total_traffic == nullptr || new_get_direct_traffic == nullptr ||
        new_stop_tun == nullptr || new_suspend == nullptr || new_force_gc == nullptr ||
        new_update_dns == nullptr) {
        dlclose(handle);
        env->ReleaseStringUTFChars(lib_path, path);
        return JNI_FALSE;
    }

    // The Core defines its callback pointers as globals; write the JNI
    // implementations into those slots, which is what used to happen at link
    // time when this bridge depended on the Core directly.
    const auto bind = [handle](const char *name, void *impl) -> bool {
        void *slot = dlsym(handle, name);
        if (slot == nullptr) {
            __android_log_print(ANDROID_LOG_ERROR, "Core", "dlsym failed for %s: %s", name,
                                dlerror());
            return false;
        }
        *static_cast<void **>(slot) = impl;
        return true;
    };
    if (!bind("protect_func", reinterpret_cast<void *>(&call_tun_interface_protect_impl)) ||
        !bind("resolve_uid_func", reinterpret_cast<void *>(&call_tun_interface_resolve_uid_impl)) ||
        !bind("resolve_package_func",
              reinterpret_cast<void *>(&call_tun_interface_resolve_package_impl)) ||
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

    __android_log_print(ANDROID_LOG_INFO, "Core", "loaded Core from %s", path);
    env->ReleaseStringUTFChars(lib_path, path);
    return JNI_TRUE;
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_follow_clash_core_Core_nativeStartTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
                                         jstring stack, jstring address, jstring dns) {
    const auto interface = new_global(cb);
    return fn_start_tun(interface, fd, get_string(stack), get_string(address), get_string(dns))
           ? JNI_TRUE
           : JNI_FALSE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeStopTun(JNIEnv *env, jobject thiz) {
    fn_stop_tun();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeForceGC(JNIEnv *env, jobject thiz) {
    fn_force_gc();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeUpdateDNS(JNIEnv *env, jobject thiz, jstring dns) {
    fn_update_dns(get_string(dns));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeInvokeMethod(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
    const auto interface = new_global(cb);
    fn_invoke_method(interface, get_string(data));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeSetEventListener(JNIEnv *env, jobject thiz, jobject cb) {
    if (cb != nullptr) {
        const auto interface = new_global(cb);
        fn_set_event_listener(interface);
    } else {
        fn_set_event_listener(nullptr);
    }
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_nativeGetTraffic(JNIEnv *env, jobject thiz,
                                           const jboolean only_statistics_proxy) {
    scoped_string traffic = fn_get_traffic(static_cast<unsigned char>(only_statistics_proxy));
    return new_string(traffic);
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_nativeGetTotalTraffic(JNIEnv *env, jobject thiz,
                                                const jboolean only_statistics_proxy) {
    scoped_string traffic = fn_get_total_traffic(static_cast<unsigned char>(only_statistics_proxy));
    return new_string(traffic);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeSuspended(JNIEnv *env, jobject thiz, jboolean suspended) {
    fn_suspend(static_cast<unsigned char>(suspended));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_nativeQuickSetup(JNIEnv *env, jobject thiz, jstring init_params_string,
                                           jstring setup_params_string, jobject cb) {
    const auto interface = new_global(cb);
    fn_quick_setup(interface, get_string(init_params_string), get_string(setup_params_string));
}

extern "C"
JNIEXPORT jstring JNICALL
        Java_com_follow_clash_core_Core_nativeGetDirectTraffic(JNIEnv *env, jobject thiz) {
return new_string(fn_get_direct_traffic());
}

extern "C"
JNIEXPORT jstring JNICALL
        Java_com_follow_clash_core_Core_nativeGetDirectTotalTraffic(JNIEnv *env, jobject thiz) {
return new_string(fn_get_direct_total_traffic());
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

    m_tun_interface_protect = find_method(c_tun_interface, "protect", "(I)Z");
    m_tun_interface_resolve_uid = find_method(c_tun_interface, "resolveUid",
                                              "(ILjava/lang/String;Ljava/lang/String;)I");
    m_tun_interface_resolve_package = find_method(c_tun_interface, "resolvePackage",
                                                  "(I)Ljava/lang/String;");
    m_invoke_interface_result = find_method(c_invoke_interface, "onResult",
                                            "(Ljava/lang/String;)V");

    return JNI_VERSION_1_6;
}
