package com.noah.personar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var pendingResult: MethodChannel.Result? = null

    private var location: LocationBridge? = null

    private var audioRoute: AudioRouteBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val prev = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            Log.e("Sonarar", "[uncaught] on ${t.name}", e)
            prev?.uncaughtException(t, e)
        }

        location = LocationBridge(this).also { it.attach(flutterEngine) }

        SpectrumBridge().attach(flutterEngine)

        audioRoute = AudioRouteBridge(this).also { it.attach(flutterEngine) }

        // A link in ABOUT opens in the browser, or in the app that claims it.
        // A phone with no browser gets a message, not a crash.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LINKS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.success(false)
                        } else {
                            result.success(openExternal(url))
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROBE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasRecordAudio" -> result.success(hasRecordAudio())
                    "requestRecordAudio" -> requestRecordAudio(result)
                    "attachVisualizer" -> result.success(attachVisualizer())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(storageStatus())
                    "request" -> requestStorage(result)

                    "notificationStatus" -> result.success(notificationStatus())
                    "requestNotification" -> requestNotification(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openExternal(url: String): Boolean = try {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (e: Exception) {
        Log.w("Sonarar", "no handler for $url", e)
        false
    }

    private fun storageStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return "granted"
        return if (canReadLibrary()) "granted" else "denied"
    }

    /// What actually allows reading the library, per Android version. Asking
    /// for READ_MEDIA_AUDIO and then checking only for all-files access meant a
    /// phone with the permission granted still reported "denied" for ever.
    private fun canReadLibrary(): Boolean = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
            granted(Manifest.permission.READ_MEDIA_AUDIO) || hasAllFilesAccess()
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
            granted(Manifest.permission.READ_EXTERNAL_STORAGE) || hasAllFilesAccess()
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
            granted(Manifest.permission.READ_EXTERNAL_STORAGE)
        else -> true
    }

    private fun granted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            Environment.isExternalStorageManager()

    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return "granted"
        }
        return if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) "granted" else "denied"
    }

    private fun requestNotification(result: MethodChannel.Result) {
        if (notificationStatus() == "granted") {
            result.success("granted")
            return
        }
        if (pendingResult != null) {
            result.success("denied")
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_NOTIF,
        )
    }

    private fun neededPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_AUDIO,
                Manifest.permission.READ_MEDIA_IMAGES,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    private fun neededPermission(): String = neededPermissions().first()

    private fun requestStorage(result: MethodChannel.Result) {
        if (canReadLibrary()) {
            result.success("granted")
            return
        }

        if (pendingResult != null) {
            result.success("denied")
            return
        }
        pendingResult = result

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (openAllFilesSettings()) return
        }
        ActivityCompat.requestPermissions(this, neededPermissions(), REQUEST_CODE)
    }

    private fun openAllFilesSettings(): Boolean {
        val target = Uri.parse("package:$packageName")
        val variants = listOf(
            Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, target),
            Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
        )
        for (variant in variants) {
            try {
                startActivity(variant)
                return true
            } catch (e: Exception) {
            }
        }
        return false
    }

    override fun onResume() {
        super.onResume()
        if (pendingResult != null) {
            pendingResult?.success(if (canReadLibrary()) "granted" else "denied")
            pendingResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (location?.onPermissionResult(requestCode) == true) return
        if (requestCode == REQUEST_CODE_RECORD) {
            pendingResult?.success(hasRecordAudio())
            pendingResult = null
            return
        }
        if (requestCode != REQUEST_CODE && requestCode != REQUEST_CODE_NOTIF) return

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingResult?.success(if (granted) "granted" else "denied")
        pendingResult = null
    }

    private fun hasRecordAudio(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED

    private fun requestRecordAudio(result: MethodChannel.Result) {
        if (hasRecordAudio()) {
            result.success(true)
            return
        }
        if (pendingResult != null) {
            result.success(false)
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_CODE_RECORD,
        )
    }

    private fun attachVisualizer(): Int {
        if (!hasRecordAudio()) return -1000

        return try {
            val v = android.media.audiofx.Visualizer(0)
            val enabled = v.enabled
            v.release()

            if (enabled) 0 else -3000
        } catch (e: Exception) {
            Log.e("Sonarar", "[probe] Visualizer threw", e)
            Regex("-?\\d+").find(e.message ?: "")?.value?.toIntOrNull() ?: -2000
        }
    }

    override fun onDestroy() {
        location?.detach()
        location = null

        audioRoute?.detach()
        audioRoute = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "personar/storage"
        private const val REQUEST_CODE = 4711
        private const val REQUEST_CODE_NOTIF = 4712
        private const val REQUEST_CODE_RECORD = 4713
        private const val LINKS_CHANNEL = "personar/links"

        private const val PROBE_CHANNEL = "com.noah.personar/spectrum_probe"
    }
}
