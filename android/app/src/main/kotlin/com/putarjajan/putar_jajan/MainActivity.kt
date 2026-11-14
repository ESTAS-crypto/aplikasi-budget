package com.putarjajan.putar_jajan

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.File
import java.io.ObjectInputStream

open class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.putarjajan.putar_jajan/app_icon"
        private const val THEME_PASAR_MALAM = "pasar_malam"
        private const val THEME_KUCING_MANIS = "kucing_manis"
        private const val PREF_THEME_KEY = "flutter.pj_theme_id"
        private const val MAIN_LAUNCHER_CLASS = "com.putarjajan.putar_jajan.MainActivity"
        private const val KUCING_LAUNCHER_CLASS = "com.putarjajan.putar_jajan.KucingLauncherActivity"
    }

    private var pendingLauncherThemeId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sanitizeFlutterSharedPreferences()
        syncInitialThemeFromPrefs()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLauncherTheme" -> {
                        val rawId = call.argument<String>("themeId")
                        val normalized = normalizeThemeId(rawId)
                        pendingLauncherThemeId = normalized
                        runOnUiThread { applyTaskDescription(normalized) }
                        result.success(true)
                    }
                    "getLauncherTheme" -> {
                        result.success(currentActiveLauncherTheme())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        pendingLauncherThemeId?.let { applyLauncherComponent(it) }
    }

    private fun normalizeThemeId(rawId: String?): String {
        return if (rawId == THEME_KUCING_MANIS) THEME_KUCING_MANIS else THEME_PASAR_MALAM
    }

    private fun syncInitialThemeFromPrefs() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val savedId = normalizeThemeId(prefs.getString(PREF_THEME_KEY, THEME_PASAR_MALAM))
            pendingLauncherThemeId = savedId
            applyTaskDescription(savedId)
        } catch (_: Exception) {}
    }

    private fun applyTaskDescription(themeId: String) {
        try {
            val isKucing = themeId == THEME_KUCING_MANIS
            val iconRes = if (isKucing) R.mipmap.ic_launcher_kucing else R.mipmap.ic_launcher
            val surfaceColor = if (isKucing) 0xFFFFF0F5.toInt() else 0xFFFFF8E1.toInt()
            val label = "Putar Jajan"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                @Suppress("DEPRECATION")
                setTaskDescription(ActivityManager.TaskDescription(label, iconRes, surfaceColor))
            } else {
                val bitmap = BitmapFactory.decodeResource(resources, iconRes)
                @Suppress("DEPRECATION")
                setTaskDescription(ActivityManager.TaskDescription(label, bitmap, surfaceColor))
            }
        } catch (_: Exception) {}
    }

    private fun currentActiveLauncherTheme(): String {
        return try {
            val kucingComponent = ComponentName(packageName, KUCING_LAUNCHER_CLASS)
            val state = packageManager.getComponentEnabledSetting(kucingComponent)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                THEME_KUCING_MANIS
            } else {
                THEME_PASAR_MALAM
            }
        } catch (_: Exception) {
            THEME_PASAR_MALAM
        }
    }

    private fun isComponentEnabled(component: ComponentName, manifestDefaultEnabled: Boolean): Boolean {
        return when (packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> manifestDefaultEnabled
        }
    }

    private fun applyLauncherComponent(themeId: String) {
        try {
            val pm = packageManager
            val mainComponent = ComponentName(packageName, MAIN_LAUNCHER_CLASS)
            val kucingComponent = ComponentName(packageName, KUCING_LAUNCHER_CLASS)
            val wantKucing = themeId == THEME_KUCING_MANIS

            val mainCurrentlyEnabled = isComponentEnabled(mainComponent, manifestDefaultEnabled = true)
            val kucingCurrentlyEnabled = isComponentEnabled(kucingComponent, manifestDefaultEnabled = false)

            if (wantKucing) {
                if (!kucingCurrentlyEnabled) {
                    pm.setComponentEnabledSetting(
                        kucingComponent,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
                if (mainCurrentlyEnabled) {
                    pm.setComponentEnabledSetting(
                        mainComponent,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
            } else {
                if (!mainCurrentlyEnabled) {
                    pm.setComponentEnabledSetting(
                        mainComponent,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
                if (kucingCurrentlyEnabled) {
                    pm.setComponentEnabledSetting(
                        kucingComponent,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
            }
        } catch (_: Exception) {}
    }

    private fun sanitizeFlutterSharedPreferences() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val allEntries = prefs.all
            val keysToRemove = mutableListOf<String>()

            for ((key, value) in allEntries) {
                if (value is String && value.startsWith("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu")) {
                    try {
                        val base64Str = value.substring("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu".length)
                        val bytes = Base64.decode(base64Str, Base64.DEFAULT)
                        val ois = ObjectInputStream(ByteArrayInputStream(bytes))
                        ois.readObject()
                        ois.close()
                    } catch (e: Exception) {
                        // Key ini mengandung payload corrupt / header baru yang memicu StreamCorruptedException
                        keysToRemove.add(key)
                    }
                }
            }

            if (keysToRemove.isNotEmpty()) {
                val editor = prefs.edit()
                for (key in keysToRemove) {
                    editor.remove(key)
                }
                editor.commit()
            }
        } catch (e: Exception) {
            // Jika file XML rusak sepenuhnya, hapus file agar Android membuat instance baru yang bersih
            try {
                val prefsFile = File(applicationInfo.dataDir, "shared_prefs/FlutterSharedPreferences.xml")
                if (prefsFile.exists()) {
                    prefsFile.delete()
                }
            } catch (_: Exception) {}
        }
    }
}

