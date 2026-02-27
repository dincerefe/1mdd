// 🔐 Native API Key Storage - Security Layer
package com.dincerefe.digitaldiary

object NativeConfig {
    init {
        System.loadLibrary("native_config")
    }
    
    // These methods are implemented in C++ to hide API keys from reverse engineering
    external fun getFirebaseApiKey(): String
    external fun getFirebaseAppId(): String
    external fun getFirebaseProjectId(): String
}
