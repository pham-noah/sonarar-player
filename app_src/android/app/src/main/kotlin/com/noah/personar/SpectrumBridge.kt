package com.noah.personar

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteOrder
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

class SpectrumBridge {
    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "build" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            val bytes = try {
                                build(path)
                            } catch (t: Throwable) {
                                android.util.Log.w(TAG, "[spectrum] build failed for $path", t)
                                null
                            }
                            Handler(Looper.getMainLooper()).post { result.success(bytes) }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun build(path: String): ByteArray? {
        val samples = decodeMono8k(path) ?: return null
        return spectrum(samples)
    }

    private class Samples(initial: Int) {
        var data = FloatArray(initial.coerceAtLeast(64))
            private set
        var size = 0
            private set

        fun add(v: Float) {
            if (size == data.size) data = data.copyOf(data.size * 2)
            data[size++] = v
        }

        val isEmpty: Boolean get() = size == 0
    }

    private fun decodeMono8k(path: String): FloatArray? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
        } catch (e: Exception) {
            extractor.release()
            return null
        }

        var trackIndex = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            val mime = f.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                trackIndex = i
                format = f
                break
            }
        }
        if (trackIndex < 0 || format == null) {
            extractor.release()
            return null
        }
        extractor.selectTrack(trackIndex)

        val srcRate = try {
            format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } catch (e: Exception) {
            extractor.release()
            return null
        }
        val channels = try {
            format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        } catch (e: Exception) {
            0
        }.coerceAtLeast(1)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: run {
            extractor.release()
            return null
        }

        val codec = try {
            MediaCodec.createDecoderByType(mime).also {
                it.configure(format, null, null, 0)
                it.start()
            }
        } catch (e: Exception) {
            android.util.Log.w(TAG, "[spectrum] no decoder for $mime ($path)", e)
            extractor.release()
            return null
        }

        val pcm = Samples(srcRate * 30)
        val info = MediaCodec.BufferInfo()
        var sawInputEos = false
        var sawOutputEos = false

        try {
            while (!sawOutputEos) {
                if (!sawInputEos) {
                    val inIndex = codec.dequeueInputBuffer(10_000)
                    if (inIndex >= 0) {
                        val buf = codec.getInputBuffer(inIndex)
                        val size = if (buf == null) -1 else extractor.readSampleData(buf, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            sawInputEos = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(info, 10_000)
                if (outIndex >= 0) {
                    val out = codec.getOutputBuffer(outIndex)
                    if (out != null && info.size > 0) {
                        out.position(info.offset)
                        out.limit(info.offset + info.size)
                        out.order(ByteOrder.nativeOrder())
                        val shorts = out.asShortBuffer()
                        val count = shorts.remaining()
                        var acc = 0f
                        var ch = 0
                        for (i in 0 until count) {
                            acc += shorts.get(i) / 32768f
                            ch++
                            if (ch == channels) {
                                pcm.add(acc / channels)
                                acc = 0f
                                ch = 0
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        sawOutputEos = true
                    }
                }
            }
        } finally {
            try {
                codec.stop()
            } catch (_: Exception) {
            }
            codec.release()
            extractor.release()
        }

        if (pcm.isEmpty) return null
        return resampleTo8k(pcm.data, pcm.size, srcRate)
    }

    private fun resampleTo8k(src: FloatArray, srcLen: Int, srcRate: Int): FloatArray {
        if (srcLen <= 0) return FloatArray(0)
        if (srcRate == TARGET_RATE) return src.copyOf(srcLen)

        val window = (srcRate / TARGET_RATE).coerceAtLeast(1)
        val ratio = srcRate.toDouble() / TARGET_RATE
        val outLen = (srcLen / ratio).toInt()
        if (outLen <= 0) return FloatArray(0)

        val out = FloatArray(outLen)
        var cursor = -1
        var running = 0f
        var prev = 0f
        var last = 0f

        fun filteredAt(k: Int): Float {
            while (cursor < k) {
                cursor++
                running += src[cursor]
                if (cursor >= window) running -= src[cursor - window]
                prev = last
                last = running / minOf(cursor + 1, window).toFloat()
            }
            return if (k == cursor) last else prev
        }

        for (i in 0 until outLen) {
            val pos = i * ratio
            val i0 = pos.toInt()
            val i1 = (i0 + 1).coerceAtMost(srcLen - 1)
            val frac = (pos - i0).toFloat()
            val a = filteredAt(i0)
            val b = filteredAt(i1)
            out[i] = a * (1 - frac) + b * frac
        }
        return out
    }

    private fun spectrum(samples: FloatArray): ByteArray {
        if (samples.size < FFT_SIZE) return ByteArray(0)

        val hop = TARGET_RATE / FRAMES_PER_SECOND
        val window = FloatArray(FFT_SIZE) { (0.5 - 0.5 * cos(2.0 * Math.PI * it / (FFT_SIZE - 1))).toFloat() }

        val bands = ArrayList<IntArray>(BAND_EDGES.size - 1)
        for (b in 0 until BAND_EDGES.size - 1) {
            val lo = BAND_EDGES[b]
            val hi = BAND_EDGES[b + 1]
            val kLo = ceilDiv(lo * FFT_SIZE, TARGET_RATE)

            val kHi = ceilDiv(hi * FFT_SIZE, TARGET_RATE)
            bands.add(intArrayOf(kLo.coerceIn(0, FFT_SIZE / 2), kHi.coerceIn(0, FFT_SIZE / 2 + 1)))
        }

        val frameCount = ((samples.size - FFT_SIZE) / hop) + 1
        if (frameCount <= 0) return ByteArray(0)
        val bandCount = bands.size

        val frames = Array(frameCount) { FloatArray(bandCount) }
        val re = DoubleArray(FFT_SIZE)
        val im = DoubleArray(FFT_SIZE)

        for (row in 0 until frameCount) {
            val start = row * hop
            for (i in 0 until FFT_SIZE) {
                re[i] = (samples[start + i] * window[i]).toDouble()
                im[i] = 0.0
            }
            fft(re, im)
            for (col in 0 until bandCount) {
                val range = bands[col]
                var sum = 0.0
                var n = 0
                for (k in range[0] until range[1]) {
                    if (k > FFT_SIZE / 2) break
                    sum += sqrt(re[k] * re[k] + im[k] * im[k])
                    n++
                }
                frames[row][col] = if (n == 0) 0f else (sum / n).toFloat()
            }
        }

        val peak = FloatArray(bandCount)
        for (col in 0 until bandCount) {
            var m = 0f
            for (row in 0 until frameCount) if (frames[row][col] > m) m = frames[row][col]
            peak[col] = if (m <= 0f) 1f else m
        }

        val out = ByteArray(frameCount * bandCount)
        var p = 0
        for (row in 0 until frameCount) {
            for (col in 0 until bandCount) {
                val v = (frames[row][col] / peak[col]).toDouble().pow(0.6)

                out[p++] = (v * 255).toInt().coerceIn(0, 255).toByte()
            }
        }
        return out
    }

    private fun ceilDiv(a: Int, b: Int): Int = if (a <= 0) 0 else (a + b - 1) / b

    private fun fft(re: DoubleArray, im: DoubleArray) {
        val n = re.size

        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j or bit
            if (i < j) {
                val tr = re[i]; re[i] = re[j]; re[j] = tr
                val ti = im[i]; im[i] = im[j]; im[j] = ti
            }
        }

        var len = 2
        while (len <= n) {
            val angle = -2.0 * Math.PI / len
            val wRe = cos(angle)
            val wIm = sin(angle)
            var i = 0
            while (i < n) {
                var curRe = 1.0
                var curIm = 0.0
                for (k in 0 until len / 2) {
                    val uRe = re[i + k]
                    val uIm = im[i + k]
                    val vRe = re[i + k + len / 2] * curRe - im[i + k + len / 2] * curIm
                    val vIm = re[i + k + len / 2] * curIm + im[i + k + len / 2] * curRe
                    re[i + k] = uRe + vRe
                    im[i + k] = uIm + vIm
                    re[i + k + len / 2] = uRe - vRe
                    im[i + k + len / 2] = uIm - vIm
                    val nextRe = curRe * wRe - curIm * wIm
                    curIm = curRe * wIm + curIm * wRe
                    curRe = nextRe
                }
                i += len
            }
            len = len shl 1
        }
    }

    companion object {
        private const val TAG = "Sonarar"
        private const val CHANNEL = "com.noah.personar/spectrum"
        private const val TARGET_RATE = 8000
        private const val FFT_SIZE = 1024
        private const val FRAMES_PER_SECOND = 20
        private val BAND_EDGES = intArrayOf(20, 60, 120, 250, 500, 1000, 2000, 4000)
    }
}
