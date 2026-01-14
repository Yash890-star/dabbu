package com.togics.dabbu

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.togics.dabbu/permissions"
    private var pendingResult: MethodChannel.Result? = null
    private val REQUEST_CODE_NOTIFICATION = 3001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestNotificationPermission") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        pendingResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_NOTIFICATION)
                    } else {
                        result.success(true)
                    }
                } else {
                    result.success(true) // Not needed for Android < 13
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode == REQUEST_CODE_NOTIFICATION) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (pendingResult != null) {
                pendingResult?.success(isGranted)
                pendingResult = null
            }
            // Do NOT call super.onRequestPermissionsResult to prevent plugins (like another_telephony)
            // from crashing or interfering with this custom request.
        } else {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
