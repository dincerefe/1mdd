// 🔐 Native Security Layer - API Keys Hidden in Native Code
// This makes reverse engineering MUCH harder
#include <jni.h>
#include <string>

// ⚠️ IMPORTANT: These are XOR-obfuscated but still extractable with advanced tools
// For MAXIMUM security, use Firebase App Check + Cloud Functions
// Never store sensitive keys client-side for critical operations

extern "C" {

// XOR obfuscation - simple but effective against casual reverse engineering
std::string deobfuscate(const unsigned char* obfuscated, int length) {
    std::string result;
    const unsigned char key = 0x5A; // XOR key
    for (int i = 0; i < length; i++) {
        result += (char)(obfuscated[i] ^ key);
    }
    return result;
}

JNIEXPORT jstring JNICALL
Java_com_dincerefe_digitaldiary_NativeConfig_getFirebaseApiKey(JNIEnv* env, jobject) {
    // XOR-obfuscated Android API key
    const unsigned char obfuscated[] = {
        0x1B, 0x13, 0x20, 0x3B, 0x09, 0x23, 0x18, 0x29, 0x29, 0x09, 0x1D, 0x09, 
        0x63, 0x6D, 0x3C, 0x22, 0x0B, 0x2D, 0x0F, 0x62, 0x77, 0x3B, 0x13, 0x6D, 
        0x3D, 0x6D, 0x38, 0x31, 0x63, 0x0B, 0x6A, 0x68, 0x1F, 0x1D, 0x6B, 0x32, 
        0x0A, 0x28, 0x03
    };
    std::string apiKey = deobfuscate(obfuscated, sizeof(obfuscated));
    return env->NewStringUTF(apiKey.c_str());
}

JNIEXPORT jstring JNICALL
Java_com_dincerefe_digitaldiary_NativeConfig_getFirebaseAppId(JNIEnv* env, jobject) {
    // XOR-obfuscated Android App ID
    const unsigned char obfuscated[] = {
        0x6B, 0x60, 0x62, 0x68, 0x6D, 0x6B, 0x6A, 0x62, 0x63, 0x68, 0x62, 0x68, 
        0x63, 0x69, 0x60, 0x3B, 0x34, 0x3E, 0x28, 0x35, 0x33, 0x3E, 0x60, 0x39, 
        0x6E, 0x63, 0x6A, 0x68, 0x68, 0x69, 0x6C, 0x3C, 0x3F, 0x62, 0x63, 0x6F, 
        0x69, 0x3F, 0x6D, 0x6D, 0x3F, 0x62, 0x62, 0x39, 0x39
    };
    std::string appId = deobfuscate(obfuscated, sizeof(obfuscated));
    return env->NewStringUTF(appId.c_str());
}

JNIEXPORT jstring JNICALL
Java_com_dincerefe_digitaldiary_NativeConfig_getFirebaseProjectId(JNIEnv* env, jobject) {
    // Plain text is OK for project ID (public info)
    std::string projectId = "digitaldiaryapp-591c2";
    return env->NewStringUTF(projectId.c_str());
}

}
