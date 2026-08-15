package com.taknoghte.taknoghte

import android.app.LocaleManager
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.taknoghte.taknoghte/locale"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setAppLocale") {
                val lang = call.argument<String>("lang") ?: "fa"
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val localeManager = getSystemService(LocaleManager::class.java)
                        localeManager?.applicationLocales = LocaleList.forLanguageTags(lang)
                    } else {
                        val locale = Locale(lang)
                        Locale.setDefault(locale)
                        val config = Configuration(resources.configuration)
                        config.setLocale(locale)
                        @Suppress("DEPRECATION")
                        resources.updateConfiguration(config, resources.displayMetrics)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("LOCALE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
