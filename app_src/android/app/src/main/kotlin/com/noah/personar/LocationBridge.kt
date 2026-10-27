package com.noah.personar

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class LocationBridge(private val activity: Activity) {
    private var channel: MethodChannel? = null

    private var pending: MethodChannel.Result? = null

    private var askedBefore = false

    private var updates: LocationListener? = null

    private val handler = Handler(Looper.getMainLooper())

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "enabled" -> result.success(enabled())
                "checkPermission" -> result.success(permission())
                "requestPermission" -> requestPermission(result)
                "lastKnown" -> result.success(lastKnown())
                "current" -> current(
                    call.argument<Number>("timeoutMs")?.toLong() ?: kDefaultTimeoutMs,
                    result,
                )
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        stopUpdates()
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pending?.success(if (hasPermission()) "granted" else permission())
        pending = null
        return true
    }

    private fun manager(): LocationManager? =
        activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    private fun enabled(): Boolean {
        val m = manager() ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) return m.isLocationEnabled
        return m.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            m.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

    private fun permission(): String = when {
        hasPermission() -> "granted"
        askedBefore && !ActivityCompat.shouldShowRequestPermissionRationale(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) -> "deniedForever"
        else -> "denied"
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success("granted")
            return
        }

        if (pending != null) {
            result.success("denied")
            return
        }
        pending = result
        askedBefore = true
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
            REQUEST_CODE,
        )
    }

    private fun lastKnown(): Map<String, Any>? {
        val m = manager() ?: return null
        if (!hasPermission()) return null
        var best: Location? = null
        for (provider in m.getProviders(true)) {
            val fix = try {
                m.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } ?: continue
            if (best == null || fix.time > best!!.time) best = fix
        }
        return best?.let { fix ->
            mapOf(
                "latitude" to fix.latitude,
                "longitude" to fix.longitude,
                "accuracy" to fix.accuracy,
            )
        }
    }

    private fun current(timeoutMs: Long, result: MethodChannel.Result) {
        val m = manager()
        if (m == null || !hasPermission()) {
            result.success(null)
            return
        }
        val provider = when {
            m.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            m.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> {
                result.success(null)
                return
            }
        }

        stopUpdates()
        var answered = false
        fun answer(fix: Map<String, Any>?) {
            if (answered) return
            answered = true
            stopUpdates()
            result.success(fix)
        }

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) = answer(
                mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy,
                ),
            )

            override fun onProviderDisabled(provider: String) = answer(null)

            override fun onProviderEnabled(provider: String) = Unit

            @Deprecated("Deprecated in Java, still abstract below API 30")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        }

        updates = listener
        try {
            m.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
        } catch (_: SecurityException) {
            answer(null)
            return
        }

        handler.postDelayed({ answer(null) }, timeoutMs)
    }

    private fun stopUpdates() {
        val listener = updates ?: return
        updates = null
        try {
            manager()?.removeUpdates(listener)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val CHANNEL = "personar/location"

        private const val REQUEST_CODE = 4714

        private const val kDefaultTimeoutMs = 8000L
    }
}
