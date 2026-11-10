package com.putarjajan.putar_jajan

import android.content.Context
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import java.io.ByteArrayInputStream
import java.io.File
import java.io.ObjectInputStream

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sanitizeFlutterSharedPreferences()
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

