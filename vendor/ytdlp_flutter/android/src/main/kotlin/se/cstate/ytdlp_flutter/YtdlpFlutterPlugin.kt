package se.cstate.ytdlp_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_common.SharedPrefsHelper
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.concurrent.ExecutorService
import android.system.Os
import org.apache.commons.compress.archivers.zip.ZipFile
import java.util.concurrent.Executors

/**
 * Android backend: wraps youtubedl-android (bundled Python + runtime-updatable
 * yt-dlp + FFmpeg). All engine calls run on a thread pool; results and
 * progress events are posted back on the main thread.
 */
class YtdlpFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var progressChannel: EventChannel
    private lateinit var context: Context

    private val executor: ExecutorService = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressSink: EventChannel.EventSink? = null

    @Volatile
    private var initialized = false

    @Volatile
    private var lastUpdateStatus: String = "not-attempted"

    /// FFmpeg is not bundled in this build (36 MB of the APK for a step the app
    /// never runs). Its absence is a capability, not a failure to initialise.
    @Volatile
    private var ffmpegReady = false

    @Volatile
    private var ffmpegError: String? = null

    /// The engine itself (the CPython runtime yt-dlp runs on) is missing in a lite
    /// build. That is also a capability: the download UI is compiled out, and if
    /// anything still reaches the channel it gets a named exception instead of the
    /// whole app falling over at init.
    @Volatile
    private var engineReady = false

    @Volatile
    private var engineError: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ytdlp_flutter")
        channel.setMethodCallHandler(this)
        progressChannel = EventChannel(binding.binaryMessenger, "ytdlp_flutter/progress")
        progressChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink = events
            }

            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        progressChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> runAsync(result) {
                ensureInit()
                null
            }
            "getVideoInfo" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("BAD_ARGS", "url is required", null)
                runAsync(result) {
                    ensureInit()
                    requireEngine()
                    val request = YoutubeDLRequest(url).apply {
                        addOption("--dump-single-json")
                        addOption("--no-playlist")
                    }
                    YoutubeDL.getInstance().execute(request).out.trim()
                }
            }
            "downloadAudio" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("BAD_ARGS", "url is required", null)
                val outputDir = call.argument<String>("outputDir")
                    ?: return result.error("BAD_ARGS", "outputDir is required", null)
                val taskId = call.argument<String>("taskId")
                    ?: return result.error("BAD_ARGS", "taskId is required", null)
                val format = call.argument<String>("format") ?: "bestaudio/best"
                val audioFormat = call.argument<String>("audioFormat")
                runAsync(result) {
                    ensureInit()
                    requireEngine()
                    downloadAudio(url, outputDir, taskId, format, audioFormat)
                }
            }
            "cancel" -> {
                val taskId = call.argument<String>("taskId")
                    ?: return result.error("BAD_ARGS", "taskId is required", null)
                result.success(YoutubeDL.getInstance().destroyProcessById(taskId))
            }
            // Install an engine the APK does not carry (a lite build fetching it
            // once). Answers with the same map as capabilities so the caller learns
            // immediately whether the engine came up.
            "installEngine" -> {
                val zipPath = call.argument<String>("zipPath")
                    ?: return result.error("BAD_ARGS", "zipPath is required", null)
                runAsync(result) {
                    installEngine(File(zipPath))
                    capabilitiesMap()
                }
            }
            "capabilities" -> runAsync(result) {
                ensureInit()
                capabilitiesMap()
            }
            "update" -> runAsync(result) {
                ensureInit()
                requireEngine()
                val status = YoutubeDL.getInstance()
                    .updateYoutubeDL(context, YoutubeDL.UpdateChannel.STABLE)
                status?.name ?: "unknown"
            }
            else -> result.notImplemented()
        }
    }

    private fun capabilitiesMap(): Map<String, Any?> = mapOf(
        // The engine archive is architecture-specific, so the caller has to know
        // which one this device needs before it downloads 14 MB of the wrong one.
        "abi" to android.os.Build.SUPPORTED_ABIS.firstOrNull(),
        "engine" to engineReady,
        "engineError" to engineError,
        "ffmpeg" to ffmpegReady,
        "ffmpegError" to ffmpegError,
        "updated" to lastUpdateStatus,
        "version" to if (!engineReady) {
            "unknown"
        } else {
            try {
                YoutubeDL.getInstance().version(context) ?: "unknown"
            } catch (e: Exception) {
                "unknown"
            }
        },
    )

    /// Unpack an engine archive fetched at runtime into exactly where the library
    /// looks for it, then record the marker it checks.
    ///
    /// The library treats a payload as stale when its byte length differs from the
    /// value stored under "pythonLibVersion" - it is not a version string at all,
    /// it is File.length(). Recording the real length of the archive we installed is
    /// therefore the whole contract, and it cannot drift when the archive changes.
    @Synchronized
    private fun installEngine(zip: File) {
        require(zip.isFile) { "engine archive missing: ${zip.absolutePath}" }
        val pythonDir = File(File(context.noBackupFilesDir, "youtubedl-android"), "packages/python")
        if (pythonDir.exists() && !pythonDir.deleteRecursively()) {
            throw IllegalStateException("could not clear the old engine at $pythonDir")
        }
        pythonDir.mkdirs()

        ZipFile.builder().setFile(zip).get().use { zf ->
            for (entry in zf.entries) {
                val out = File(pythonDir, entry.name)
                // Zip-slip guard: an archive must never write outside its own tree.
                require(out.canonicalPath.startsWith(pythonDir.canonicalPath)) {
                    "engine archive escapes its directory: ${entry.name}"
                }
                if (entry.isDirectory) {
                    out.mkdirs()
                    continue
                }
                out.parentFile?.mkdirs()
                if (entry.isUnixSymlink) {
                    // The interpreter's lib dir is a web of links (libz.so.1 ->
                    // libz.so.1.3.1). Written as a plain file, the link's target
                    // path becomes 13 bytes of "ELF" and Python loses zlib.
                    val target = zf.getInputStream(entry).bufferedReader().readText().trim()
                    if (out.exists()) out.delete()
                    Os.symlink(target, out.absolutePath)
                } else {
                    zf.getInputStream(entry).use { input ->
                        out.outputStream().use { input.copyTo(it) }
                    }
                }
            }
        }

        SharedPrefsHelper.update(context, "pythonLibVersion", zip.length().toString())
        Log.i("ytdlp_flutter", "engine installed from ${zip.name} (${zip.length()} bytes)")

        // Forget the old verdict and try again with the payload in place.
        initialized = false
        engineReady = false
        engineError = null
        ensureInit()
    }

    /// Every call that needs yt-dlp goes through this, so a lite build fails with
    /// one sentence instead of a stack trace from inside the library.
    private fun requireEngine() {
        if (!engineReady) {
            throw IllegalStateException(
                "engine-unavailable: ${engineError ?: "no Python runtime is bundled in this build"}"
            )
        }
    }

    @Synchronized
    private fun ensureInit() {
        if (initialized) return
        // Whole engine optional: a lite build ships no Python runtime.
        engineReady = try {
            YoutubeDL.getInstance().init(context)
            true
        } catch (e: Throwable) {
            engineError = e.message ?: e.javaClass.simpleName
            Log.i("ytdlp_flutter", "engine not bundled ($engineError); downloads are unavailable")
            false
        }
        if (!engineReady) {
            initialized = true
            return
        }
        // Optional on purpose: the download path asks yt-dlp for one audio stream
        // and never transcodes, so ffmpeg is only needed for merging and HLS.
        // When it is missing, those requests fail with a message instead of
        // taking init - and every download - down with them.
        ffmpegReady = try {
            FFmpeg.getInstance().init(context)
            true
        } catch (e: Throwable) {
            ffmpegError = e.message ?: e.javaClass.simpleName
            Log.i("ytdlp_flutter", "ffmpeg not bundled ($ffmpegError); audio-only downloads continue")
            false
        }
        // The library's bundled yt-dlp is frozen at its build date, and a
        // stale extractor is the #1 failure mode (YouTube 403s it within
        // months). Update in place — a no-op when already current, and
        // never fatal: offline devices proceed with the installed version.
        try {
            val status = YoutubeDL.getInstance()
                .updateYoutubeDL(context, YoutubeDL.UpdateChannel.STABLE)
            lastUpdateStatus = status?.name ?: "unknown"
            Log.i("ytdlp_flutter", "yt-dlp update: $lastUpdateStatus")
        } catch (e: Exception) {
            lastUpdateStatus = "failed: ${e.message}"
            Log.w("ytdlp_flutter", "yt-dlp update failed (continuing): ${e.message}")
        }
        initialized = true
    }

    /// Version + update status, appended to every error so failures on
    /// user devices are self-describing.
    private fun engineInfo(): String {
        val version = try {
            YoutubeDL.getInstance().version(context) ?: "unknown"
        } catch (e: Exception) {
            "unknown"
        }
        return "yt-dlp=$version, update=$lastUpdateStatus"
    }

    private fun downloadAudio(
        url: String,
        outputDir: String,
        taskId: String,
        format: String,
        audioFormat: String?,
    ): String {
        File(outputDir).mkdirs()
        val request = YoutubeDLRequest(url).apply {
            addOption("--no-playlist")
            addOption("-f", format)
            if (audioFormat != null) {
                addOption("-x")
                addOption("--audio-format", audioFormat)
            }
            addOption("-o", "$outputDir/%(id)s.%(ext)s")
            addOption("--no-simulate")
            addOption("--print", "after_move:filepath")
        }
        val response = YoutubeDL.getInstance().execute(request, taskId) { progress, eta, _ ->
            mainHandler.post {
                progressSink?.success(
                    mapOf(
                        "taskId" to taskId,
                        "progress" to progress,
                        "etaSeconds" to eta,
                    )
                )
            }
        }
        // '--print after_move:filepath' emits the finished file on stdout;
        // scan from the end past any progress noise.
        val path = response.out.lines()
            .map { it.trim() }
            .lastOrNull { it.startsWith("/") && File(it).exists() }
            ?: throw RuntimeException("yt-dlp finished but printed no file path")
        return path
    }

    private fun runAsync(result: Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: YoutubeDL.CanceledException) {
                mainHandler.post { result.error("CANCELLED", "cancelled", null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error(
                        "YTDLP_ERROR",
                        e.message ?: e.javaClass.simpleName,
                        engineInfo(),
                    )
                }
            }
        }
    }
}
