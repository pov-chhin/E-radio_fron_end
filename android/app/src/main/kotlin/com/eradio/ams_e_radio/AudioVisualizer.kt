package com.eradio.ams_e_radio

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.hypot
import kotlin.math.pow

/**
 * Tells the playing bars how loud each part of the sound is.
 *
 * It listens to the player's audio session with Android's [Visualizer] and sends
 * Dart [BANDS] numbers, one for each stretch of the spectrum from bass to
 * treble, as often as the phone allows (about 20 times a second). Android only
 * lets an app do this with the
 * RECORD_AUDIO permission, which is why Dart asks for it first.
 */
class AudioVisualizer(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private var visualizer: Visualizer? = null
    private var edges = IntArray(0)
    private var pendingPermission: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "e_radio/visualizer").setMethodCallHandler(this)
        EventChannel(messenger, "e_radio/visualizer/levels").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "start" -> result.success(start(call.argument<Int>("sessionId") ?: 0))
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        // Only one question at a time; the earlier one is told no.
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_CODE)
    }

    /** Called by the activity when the system's permission question is answered. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        pendingPermission?.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
        pendingPermission = null
    }

    /** Starts listening to the audio session [sessionId]; false if it can't. */
    private fun start(sessionId: Int): Boolean {
        stop()
        if (!hasPermission()) return false
        var created: Visualizer? = null
        return try {
            val visualizer = Visualizer(sessionId)
            created = visualizer
            visualizer.setEnabled(false)
            // The finest the phone offers: the bass bands need the detail.
            visualizer.setCaptureSize(Visualizer.getCaptureSizeRange()[1])
            edges = bandEdges(visualizer.captureSize / 2)
            visualizer.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(v: Visualizer?, waveform: ByteArray?, samplingRate: Int) {}

                    override fun onFftDataCapture(v: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                        if (fft != null) sink?.success(bandLevels(fft))
                    }
                },
                Visualizer.getMaxCaptureRate(),
                false,
                true,
            )
            visualizer.setEnabled(true)
            this.visualizer = visualizer
            true
        } catch (e: Exception) {
            created?.release()
            false
        }
    }

    private fun stop() {
        visualizer?.let {
            try {
                it.setEnabled(false)
                it.release()
            } catch (e: Exception) {
                // Already gone with its audio session.
            }
        }
        visualizer = null
    }

    fun release() {
        stop()
        pendingPermission?.success(false)
        pendingPermission = null
        sink = null
    }

    /**
     * Where each band starts, as an index into the FFT's bins, spaced like the
     * ear hears: narrow for the bass, wide for the treble, and none of the top
     * fifth, where there is nothing to see.
     */
    private fun bandEdges(bins: Int): IntArray {
        val top = bins * 0.8
        val edges = IntArray(BANDS + 1)
        edges[0] = 1
        for (band in 1..BANDS) {
            edges[band] = maxOf(top.pow(band.toDouble() / BANDS).toInt(), edges[band - 1] + 1)
        }
        return edges
    }

    /**
     * The average loudness in each band. The FFT arrives as bytes: the first two
     * are the DC and Nyquist values, then a real and an imaginary byte for each
     * bin from the first up.
     */
    private fun bandLevels(fft: ByteArray): DoubleArray {
        val bins = fft.size / 2
        val levels = DoubleArray(BANDS)
        for (band in 0 until BANDS) {
            val from = edges[band]
            val to = minOf(edges[band + 1], bins)
            var sum = 0.0
            for (bin in from until to) {
                sum += hypot(fft[2 * bin].toDouble(), fft[2 * bin + 1].toDouble())
            }
            levels[band] = if (to > from) sum / (to - from) else 0.0
        }
        return levels
    }

    private companion object {
        const val BANDS = 10
        const val REQUEST_CODE = 4721
    }
}
