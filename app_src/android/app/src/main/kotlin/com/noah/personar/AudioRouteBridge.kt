package com.noah.personar

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaRouter2
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AudioRouteBridge(private val context: Context) {
    private var channel: MethodChannel? = null
    private var callback: AudioDeviceCallback? = null

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "outputs" -> result.success(outputs())

                "canSwitch" -> result.success(canShowSwitcher())

                "mediaVolume" -> result.success(mediaVolume())

                "openSwitcher" -> result.success(showSystemSwitcher())
                else -> result.notImplemented()
            }
        }
        registerCallback()
    }

    fun canShowSwitcher(): Boolean =
        Build.VERSION.SDK_INT >= 30 &&
            context.packageManager.hasSystemFeature("android.software.media_routing")

    private fun showSystemSwitcher(): Boolean {
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                val router = MediaRouter2.getInstance(context)
                if (router != null && router.showSystemOutputSwitcher()) return true
            } catch (e: Exception) {
                android.util.Log.w("Sonarar", "[audio] output switcher refused", e)
            }
        }
        return openSoundSettings()
    }

    private fun openSoundSettings(): Boolean {
        val candidates = listOf(
            Intent(Settings.ACTION_BLUETOOTH_SETTINGS),
            Intent(Settings.ACTION_SOUND_SETTINGS),
        )
        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }

    fun detach() {
        callback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        callback = null
        channel = null
    }

    private fun registerCallback() {
        if (callback != null) return
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) =
                push()

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) =
                push()
        }
        audioManager.registerAudioDeviceCallback(cb, Handler(Looper.getMainLooper()))
        callback = cb
    }

    private fun push() {
        channel?.invokeMethod("changed", outputs())
    }

    private fun mediaVolume(): Double {
        val am = audioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 1.0
        return am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    private fun outputs(): List<Map<String, Any?>> {
        val am = audioManager
        val active = activeDeviceId(am)
        val out = ArrayList<Map<String, Any?>>()

        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        for (d in devices) {
            val kind = kindOf(d.type) ?: continue

            if (d.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) continue
            out.add(
                mapOf(
                    "id" to d.id,
                    "name" to nameOf(d),
                    "kind" to kind,
                    "active" to (d.id == active),
                ),
            )
        }

        if (out.none { it["active"] == true } && out.isNotEmpty()) {
            val idx = out.indexOfFirst { it["kind"] == "speaker" }
            val i = if (idx >= 0) idx else 0
            out[i] = out[i].toMutableMap().apply { this["active"] = true }
        }
        return out
    }

    private fun activeDeviceId(am: AudioManager): Int {
        if (Build.VERSION.SDK_INT >= 34) {
            try {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                val list = am.getAudioDevicesForAttributes(attrs)
                if (list.isNotEmpty()) return list[0].id
            } catch (_: Exception) {
            }
        }

        try {
            if (am.isBluetoothA2dpOn) {
                return am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    .firstOrNull { kindOf(it.type) == "bluetooth" }?.id ?: -1
            }
            if (am.isWiredHeadsetOn) {
                return am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    .firstOrNull { kindOf(it.type) == "headphones" }?.id ?: -1
            }
        } catch (_: Exception) {
        }
        return -1
    }

    private fun nameOf(d: AudioDeviceInfo): String {
        val product = d.productName?.toString()?.trim().orEmpty()
        if (product.isNotEmpty()) return product
        return when (kindOf(d.type)) {
            "speaker" -> "THIS PHONE"
            "bluetooth" -> "BLUETOOTH"
            "headphones" -> "HEADPHONES"
            "usb" -> "USB / DAC"
            "hdmi" -> "HDMI"
            else -> "OUTPUT"
        }
    }

    private fun kindOf(type: Int): String? = when (type) {
        1 -> "speaker"
        2 -> "speaker"
        35 -> "speaker"
        3, 4 -> "headphones"
        7, 8 -> "bluetooth"
        26, 27 -> "bluetooth"
        11, 12, 22 -> "usb"
        9, 10, 29 -> "hdmi"
        else -> null
    }

    companion object {
        private const val CHANNEL = "com.noah.personar/audio_route"
    }
}
