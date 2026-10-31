// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

package com.phantek.lyra.vega

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.DefaultDecoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMuxer
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "com.phantek.cygnus.albireo/media_scanner"
    private val TRANSFORMER_CHANNEL = "com.phantek.cygnus.albireo/transformer"

    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Active transformer session
    private var activeTransformer: Transformer? = null
    private var progressRunnable: Runnable? = null
    private var activeOutputPath: String? = null
    private var isCancelled = false

    // Pending channel results to prevent hanging Futures on cancel
    private var activeTranscodeResult: MethodChannel.Result? = null
    private var activeAudioExtractResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Media Scanner Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_SCANNER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (!path.isNullOrEmpty()) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null
                        ) { _, _ -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null or empty", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // 2. AndroidX Media3 Transformer Channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSFORMER_CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getVideoInfo" -> handleGetVideoInfo(call, result)
                "getHardwareEncoders" -> handleGetHardwareEncoders(result)
                "transcodeVideo" -> handleTranscodeVideo(call, result)
                "extractAudio" -> handleExtractAudio(call, result)
                "cancelTransformation" -> handleCancelTransformation(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleGetVideoInfo(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrEmpty()) {
            result.error("INVALID_PATH", "filePath is required", null)
            return
        }

        Executors.newSingleThreadExecutor().execute {
            try {
                val info = probeVideoInfo(filePath)
                mainHandler.post { result.success(info) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("PROBE_FAILED", e.localizedMessage ?: "Failed to probe media", null)
                }
            }
        }
    }

    private fun probeVideoInfo(filePath: String): Map<String, Any?> {
        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("File does not exist: $filePath")
        }
        val fileSize = file.length()
        val fileName = file.name

        val retriever = MediaMetadataRetriever()
        var width = 0
        var height = 0
        var rotation = 0
        var durationMs = 0L
        var bitrate = 0
        var mime = "unknown"
        var hasAudio = false
        var audioCodec: String? = null
        var audioChannels: Int? = null
        var audioBitrateKbps: Int? = null
        var fps = 30.0

        try {
            retriever.setDataSource(filePath)

            val wStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val hStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            val dStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val bStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val mStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
            val hasAudioStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)

            if (wStr != null) width = wStr.toIntOrNull() ?: 0
            if (hStr != null) height = hStr.toIntOrNull() ?: 0
            if (rStr != null) rotation = rStr.toIntOrNull() ?: 0
            if (dStr != null) durationMs = dStr.toLongOrNull() ?: 0L
            if (bStr != null) bitrate = bStr.toIntOrNull() ?: 0
            if (mStr != null) mime = mStr
            hasAudio = (hasAudioStr != null && hasAudioStr.equals("yes", ignoreCase = true))
        } catch (_: Exception) {
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }

        // Inspect tracks with MediaExtractor
        var videoTrackMime: String? = null
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(filePath)
            val numTracks = extractor.trackCount
            for (i in 0 until numTracks) {
                val format = extractor.getTrackFormat(i)
                val trackMime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (trackMime.startsWith("video/")) {
                    videoTrackMime = trackMime
                    if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                        fps = try {
                            format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                        } catch (_: Exception) {
                            try {
                                format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
                            } catch (_: Exception) { fps }
                        }
                    }
                    if (width == 0 && format.containsKey(MediaFormat.KEY_WIDTH)) {
                        width = format.getInteger(MediaFormat.KEY_WIDTH)
                    }
                    if (height == 0 && format.containsKey(MediaFormat.KEY_HEIGHT)) {
                        height = format.getInteger(MediaFormat.KEY_HEIGHT)
                    }
                } else if (trackMime.startsWith("audio/")) {
                    hasAudio = true
                    audioCodec = trackMime.removePrefix("audio/")
                    if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        audioChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    if (format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                        val br = format.getInteger(MediaFormat.KEY_BIT_RATE)
                        if (br > 0) audioBitrateKbps = br / 1000
                    }
                }
            }
        } catch (_: Exception) {
        } finally {
            try { extractor.release() } catch (_: Exception) {}
        }

        // Swap dimensions for 90/270 rotation
        if (rotation == 90 || rotation == 270) {
            val temp = width
            width = height
            height = temp
        }

        val effectiveMime = videoTrackMime ?: mime
        val cleanCodec = when {
            effectiveMime.contains("avc", ignoreCase = true) || effectiveMime.contains("h264", ignoreCase = true) -> "h264"
            effectiveMime.contains("hevc", ignoreCase = true) || effectiveMime.contains("h265", ignoreCase = true) -> "hevc"
            effectiveMime.contains("vp9", ignoreCase = true) -> "vp9"
            effectiveMime.contains("av01", ignoreCase = true) || effectiveMime.contains("av1", ignoreCase = true) -> "av1"
            effectiveMime.contains("mp4v", ignoreCase = true) -> "mp4v"
            effectiveMime.contains("3gpp", ignoreCase = true) -> "h263"
            else -> effectiveMime.removePrefix("video/").lowercase()
        }

        return mapOf(
            "filePath" to filePath,
            "fileName" to fileName,
            "width" to width,
            "height" to height,
            "durationSeconds" to (durationMs / 1000.0),
            "bitrate" to bitrate,
            "fps" to fps,
            "codec" to cleanCodec,
            "fileSizeBytes" to fileSize,
            "hasAudio" to hasAudio,
            "audioCodec" to (audioCodec ?: if (hasAudio) "aac" else null),
            "audioChannels" to audioChannels,
            "audioBitrateKbps" to audioBitrateKbps,
            "rotation" to rotation
        )
    }

    private fun handleGetHardwareEncoders(result: MethodChannel.Result) {
        val encoders = mutableListOf<Map<String, Any>>()
        try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            for (codecInfo in codecList.codecInfos) {
                if (!codecInfo.isEncoder) continue
                val isHw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    codecInfo.isHardwareAccelerated
                } else {
                    !codecInfo.name.startsWith("OMX.google.", ignoreCase = true) &&
                    !codecInfo.name.startsWith("c2.android.", ignoreCase = true)
                }
                val supportedTypes = codecInfo.supportedTypes.filter {
                    it.startsWith("video/") || it.startsWith("audio/")
                }
                if (supportedTypes.isNotEmpty()) {
                    encoders.add(
                        mapOf(
                            "name" to codecInfo.name,
                            "isHardwareAccelerated" to isHw,
                            "supportedTypes" to supportedTypes
                        )
                    )
                }
            }
            result.success(encoders)
        } catch (_: Exception) {
            result.success(encoders)
        }
    }

    private fun handleTranscodeVideo(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val sourceWidth = call.argument<Int>("sourceWidth") ?: 0
        val sourceHeight = call.argument<Int>("sourceHeight") ?: 0
        val targetWidth = call.argument<Int>("targetWidth") ?: 0
        val targetHeight = call.argument<Int>("targetHeight") ?: 0
        val bitrateBps = call.argument<Int>("bitrateBps") ?: 0
        val videoCodec = call.argument<String>("videoCodec") ?: "h264"
        val rateControlMode = call.argument<String>("rateControlMode") ?: "crf"
        val removeAudio = call.argument<Boolean>("removeAudio") ?: false

        if (inputPath.isNullOrEmpty() || outputPath.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
            return
        }

        activeOutputPath = outputPath
        isCancelled = false
        activeTranscodeResult = result

        // Select MIME type
        val targetVideoMime = if (videoCodec.equals("hevc", ignoreCase = true) || videoCodec.equals("h265", ignoreCase = true)) {
            MimeTypes.VIDEO_H265
        } else {
            MimeTypes.VIDEO_H264
        }

        try {
            val inputFile = File(inputPath)
            val mediaItem = MediaItem.fromUri(Uri.fromFile(inputFile))

            // Bypass Presentation effect if dimensions match to skip GPU shader overhead
            val isScalingNeeded = (targetWidth > 0 && targetHeight > 0) &&
                (sourceWidth <= 0 || sourceHeight <= 0 || targetWidth != sourceWidth || targetHeight != sourceHeight)

            val videoEffects = mutableListOf<Effect>()
            if (isScalingNeeded) {
                videoEffects.add(
                    Presentation.createForWidthAndHeight(
                        targetWidth,
                        targetHeight,
                        Presentation.LAYOUT_SCALE_TO_FIT
                    )
                )
            }

            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setEffects(Effects(listOf(), videoEffects))
                .setRemoveAudio(removeAudio)
                .build()

            // Encoder factory with 2.0s GOP interval and OEM fallback
            val encoderFactoryBuilder = DefaultEncoderFactory.Builder(applicationContext)
                .setEnableFallback(true)

            val videoSettingsBuilder = VideoEncoderSettings.Builder()
                .setiFrameIntervalSeconds(2.0f)

            if (bitrateBps > 0) {
                videoSettingsBuilder.setBitrate(bitrateBps)
                if (rateControlMode.equals("bitrate", ignoreCase = true)) {
                    videoSettingsBuilder.setBitrateMode(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
                } else {
                    videoSettingsBuilder.setBitrateMode(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
                }
            }
            encoderFactoryBuilder.setRequestedVideoEncoderSettings(videoSettingsBuilder.build())
            val encoderFactory = encoderFactoryBuilder.build()

            // InAppMuxer prevents sample timeouts and timestamp gaps on long/TS media
            val muxerFactory = InAppMuxer.Factory.Builder().build()
            val transformerBuilder = Transformer.Builder(applicationContext)
                .setVideoMimeType(targetVideoMime)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .setMuxerFactory(muxerFactory)
                .setMaxDelayBetweenMuxerSamplesMs(C.TIME_UNSET)

            transformerBuilder.addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopProgressPolling()
                    activeTransformer = null
                    val res = activeTranscodeResult
                    activeTranscodeResult = null
                    mainHandler.post {
                        sendProgress(1.0, File(outputPath).length())
                        sendLog("Hardware transcoding completed successfully!")
                        res?.success(outputPath)
                    }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException
                ) {
                    stopProgressPolling()
                    activeTransformer = null
                    val res = activeTranscodeResult
                    activeTranscodeResult = null
                    val err = exportException.localizedMessage ?: "Transcoding failed"
                    val causeMsg = exportException.cause?.localizedMessage ?: exportException.cause?.message
                    val fullErr = if (!causeMsg.isNullOrBlank() && causeMsg != err) "$err ($causeMsg)" else err
                    sendLog("Hardware transcoding error [${exportException.errorCodeName}]: $fullErr")
                    cleanupOutput(outputPath)
                    mainHandler.post {
                        res?.error("TRANSCODE_FAILED", fullErr, null)
                    }
                }
            })

            val transformer = transformerBuilder.build()
            activeTransformer = transformer

            sendLog("Starting AndroidX Media3 Transformer HW engine...")
            sendLog("Input: $inputPath")
            sendLog("Target: ${targetWidth}x$targetHeight @ ${if (bitrateBps > 0) "${bitrateBps / 1000} kbps" else "Auto Bitrate"} ($videoCodec - $rateControlMode)")
            sendLog("Output: $outputPath")

            transformer.start(editedMediaItem, outputPath)

            // Start progress polling safely on Main Looper (applicationLooper)
            startProgressPolling(transformer, outputPath)

        } catch (e: Exception) {
            cleanupOutput(outputPath)
            activeTransformer = null
            stopProgressPolling()
            val res = activeTranscodeResult
            activeTranscodeResult = null
            res?.error("TRANSCODE_INIT_FAILED", e.localizedMessage ?: "Failed to start transcoding", null)
        }
    }

    private fun handleExtractAudio(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val format = call.argument<String>("format") ?: "m4a"
        val bitrateKbps = call.argument<Int>("bitrateKbps") ?: 192

        if (inputPath.isNullOrEmpty() || outputPath.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
            return
        }

        activeOutputPath = outputPath
        isCancelled = false
        activeAudioExtractResult = result

        if (format.equals("wav", ignoreCase = true)) {
            // Extract raw PCM audio and package into WAV container with progress
            Executors.newSingleThreadExecutor().execute {
                try {
                    sendLog("Extracting uncompressed audio to WAV...")
                    extractAudioToWav(inputPath, outputPath)
                    mainHandler.post {
                        sendProgress(1.0, File(outputPath).length())
                        sendLog("WAV extraction completed successfully!")
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        res?.success(outputPath)
                    }
                } catch (e: Exception) {
                    cleanupOutput(outputPath)
                    mainHandler.post {
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        res?.error("WAV_EXTRACTION_FAILED", e.localizedMessage ?: "WAV extraction failed", null)
                    }
                }
            }
            return
        }

        if (format.equals("mp3", ignoreCase = true)) {
            // Check if source audio has an MP3 stream to extract directly
            Executors.newSingleThreadExecutor().execute {
                try {
                    sendLog("Checking source audio track for MP3 stream...")
                    val success = extractAudioDirectStream(inputPath, outputPath, "audio/mpeg")
                    if (success) {
                        mainHandler.post {
                            sendProgress(1.0, File(outputPath).length())
                            sendLog("MP3 stream extracted directly!")
                            val res = activeAudioExtractResult
                            activeAudioExtractResult = null
                            res?.success(outputPath)
                        }
                    } else {
                        cleanupOutput(outputPath)
                        mainHandler.post {
                            val res = activeAudioExtractResult
                            activeAudioExtractResult = null
                            val errMsg = "Source audio is not MP3. Android Hardware MediaCodec encoder natively produces M4A (AAC) or WAV (Lossless PCM). Please select M4A or WAV."
                            sendLog(errMsg)
                            res?.error("UNSUPPORTED_MP3_ENCODE", errMsg, null)
                        }
                    }
                } catch (e: Exception) {
                    cleanupOutput(outputPath)
                    mainHandler.post {
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        res?.error("MP3_EXTRACTION_FAILED", e.localizedMessage ?: "MP3 extraction failed", null)
                    }
                }
            }
            return
        }

        // For M4A/AAC: Use AndroidX Media3 Transformer
        try {
            val mediaItem = MediaItem.fromUri(Uri.fromFile(File(inputPath)))
            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setRemoveVideo(true)
                .build()

            val muxerFactory = InAppMuxer.Factory.Builder().build()
            val transformer = Transformer.Builder(applicationContext)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setMuxerFactory(muxerFactory)
                .setMaxDelayBetweenMuxerSamplesMs(C.TIME_UNSET)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        stopProgressPolling()
                        activeTransformer = null
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        mainHandler.post {
                            sendProgress(1.0, File(outputPath).length())
                            sendLog("Audio extraction completed successfully!")
                            res?.success(outputPath)
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        stopProgressPolling()
                        activeTransformer = null
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        val err = exportException.localizedMessage ?: "Audio extraction failed"
                        val causeMsg = exportException.cause?.localizedMessage ?: exportException.cause?.message
                        val fullErr = if (!causeMsg.isNullOrBlank() && causeMsg != err) "$err ($causeMsg)" else err
                        sendLog("Audio extraction error [${exportException.errorCodeName}]: $fullErr")
                        cleanupOutput(outputPath)
                        mainHandler.post {
                            res?.error("EXTRACTION_FAILED", fullErr, null)
                        }
                    }
                })
                .build()

            activeTransformer = transformer
            sendLog("Starting Media3 audio extraction ($format @ $bitrateKbps kbps)...")
            transformer.start(editedMediaItem, outputPath)
            startProgressPolling(transformer, outputPath)

        } catch (e: Exception) {
            cleanupOutput(outputPath)
            activeTransformer = null
            stopProgressPolling()
            val res = activeAudioExtractResult
            activeAudioExtractResult = null
            res?.error("AUDIO_EXTRACTION_INIT_FAILED", e.localizedMessage ?: "Failed to start audio extraction", null)
        }
    }

    private fun handleCancelTransformation(result: MethodChannel.Result) {
        isCancelled = true
        stopProgressPolling()
        try {
            activeTransformer?.cancel()
            activeTransformer = null

            // Unblock any pending async transcode or extract requests
            activeTranscodeResult?.let {
                it.error("CANCELLED", "Transformation cancelled by user", null)
                activeTranscodeResult = null
            }
            activeAudioExtractResult?.let {
                it.error("CANCELLED", "Audio extraction cancelled by user", null)
                activeAudioExtractResult = null
            }

            val path = activeOutputPath
            if (!path.isNullOrEmpty()) {
                cleanupOutput(path)
            }
            sendLog("Transformation cancelled by user.")
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    /**
     * Polls progress on the application Looper (main Looper).
     * Transformer strictly requires getProgress to be called on its application thread.
     */
    private fun startProgressPolling(transformer: Transformer, outputPath: String) {
        stopProgressPolling()
        val progressHolder = ProgressHolder()

        val runnable = object : Runnable {
            override fun run() {
                if (isCancelled || activeTransformer != transformer) return
                try {
                    val state = transformer.getProgress(progressHolder)
                    if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                        val progressRatio = (progressHolder.progress / 100.0).coerceIn(0.0, 1.0)
                        val currentBytes = try { File(outputPath).length() } catch (_: Exception) { 0L }
                        sendProgress(progressRatio, currentBytes)
                    }
                } catch (_: Exception) {}

                if (!isCancelled && activeTransformer == transformer) {
                    mainHandler.postDelayed(this, 500)
                }
            }
        }
        progressRunnable = runnable
        mainHandler.postDelayed(runnable, 500)
    }

    private fun stopProgressPolling() {
        progressRunnable?.let { mainHandler.removeCallbacks(it) }
        progressRunnable = null
    }

    private fun sendProgress(progress: Double, sizeBytes: Long) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onProgress",
                mapOf("progress" to progress, "sizeBytes" to sizeBytes)
            )
        }
    }

    private fun sendLog(message: String) {
        mainHandler.post {
            methodChannel?.invokeMethod("onLog", mapOf("message" to message))
        }
    }

    private fun cleanupOutput(path: String) {
        try {
            val f = File(path)
            if (f.exists()) f.delete()
        } catch (_: Exception) {}
    }

    /**
     * Direct bitstream extraction using MediaExtractor without re-encoding.
     */
    private fun extractAudioDirectStream(inputPath: String, outputPath: String, targetMime: String): Boolean {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(inputPath)
            var audioTrackIndex = -1
            var trackFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.equals(targetMime, ignoreCase = true)) {
                    audioTrackIndex = i
                    trackFormat = format
                    break
                }
            }

            if (audioTrackIndex == -1 || trackFormat == null) {
                return false
            }

            extractor.selectTrack(audioTrackIndex)
            val durationUs = if (trackFormat.containsKey(MediaFormat.KEY_DURATION)) {
                trackFormat.getLong(MediaFormat.KEY_DURATION)
            } else 0L

            val outputFile = File(outputPath)
            if (outputFile.exists()) outputFile.delete()
            val fos = FileOutputStream(outputFile)

            val buffer = ByteBuffer.allocateDirect(1024 * 64)
            var totalBytes = 0L

            try {
                while (!isCancelled) {
                    buffer.clear()
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) break

                    val chunk = ByteArray(sampleSize)
                    buffer.get(chunk)
                    fos.write(chunk)
                    totalBytes += sampleSize

                    if (durationUs > 0) {
                        val pts = extractor.sampleTime
                        val progress = (pts.toDouble() / durationUs).coerceIn(0.0, 0.99)
                        sendProgress(progress, totalBytes)
                    }
                    extractor.advance()
                }
            } finally {
                fos.flush()
                fos.close()
            }

            if (isCancelled) {
                cleanupOutput(outputPath)
                return false
            }

            return true
        } finally {
            extractor.release()
        }
    }

    /**
     * Extracts audio track to standard uncompressed 16-bit PCM WAV.
     */
    private fun extractAudioToWav(inputPath: String, outputPath: String) {
        val extractor = MediaExtractor()
        var decoder: android.media.MediaCodec? = null
        var raf: RandomAccessFile? = null

        try {
            extractor.setDataSource(inputPath)

            var audioTrackIndex = -1
            var format: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val trackFormat = extractor.getTrackFormat(i)
                val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = trackFormat
                    break
                }
            }

            if (audioTrackIndex == -1 || format == null) {
                throw IllegalArgumentException("No audio track found in file")
            }

            extractor.selectTrack(audioTrackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            var sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else 44100
            var channelCount = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else 2
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION)
            } else 0L

            val dec = android.media.MediaCodec.createDecoderByType(mime)
            decoder = dec
            dec.configure(format, null, null, 0)
            dec.start()

            val outputFile = File(outputPath)
            if (outputFile.exists()) outputFile.delete()
            val fileRaf = RandomAccessFile(outputFile, "rw")
            raf = fileRaf

            // Write preliminary 44-byte WAV header
            writeWavHeader(fileRaf, channelCount, sampleRate, 16, 0)

            val bufferInfo = android.media.MediaCodec.BufferInfo()
            var totalAudioBytes = 0L
            var isExtractorDone = false
            var isDecoderDone = false
            var lastProgressTime = 0L

            while (!isDecoderDone && !isCancelled) {
                if (!isExtractorDone) {
                    val inputBufIndex = dec.dequeueInputBuffer(10000)
                    if (inputBufIndex >= 0) {
                        val inputBuf = dec.getInputBuffer(inputBufIndex)
                        if (inputBuf != null) {
                            val sampleSize = extractor.readSampleData(inputBuf, 0)
                            if (sampleSize < 0) {
                                dec.queueInputBuffer(inputBufIndex, 0, 0, 0L, android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isExtractorDone = true
                            } else {
                                val pts = extractor.sampleTime
                                dec.queueInputBuffer(inputBufIndex, 0, sampleSize, pts, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                val outputBufIndex = dec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufIndex >= 0) {
                    val outputBuf = dec.getOutputBuffer(outputBufIndex)
                    if (outputBuf != null && bufferInfo.size > 0) {
                        outputBuf.position(bufferInfo.offset)
                        outputBuf.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuf.get(chunk)
                        fileRaf.write(chunk)
                        totalAudioBytes += bufferInfo.size

                        val now = System.currentTimeMillis()
                        if (now - lastProgressTime > 200 && durationUs > 0) {
                            lastProgressTime = now
                            val progress = (bufferInfo.presentationTimeUs.toDouble() / durationUs).coerceIn(0.0, 0.99)
                            sendProgress(progress, totalAudioBytes)
                        }
                    }
                    dec.releaseOutputBuffer(outputBufIndex, false)
                    if ((bufferInfo.flags and android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isDecoderDone = true
                    }
                } else if (outputBufIndex == android.media.MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = dec.outputFormat
                    if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channelCount = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                }
            }

            // Finalize WAV header with actual data size
            fileRaf.seek(0)
            writeWavHeader(fileRaf, channelCount, sampleRate, 16, totalAudioBytes)
        } finally {
            try { raf?.close() } catch (_: Exception) {}
            try {
                decoder?.stop()
                decoder?.release()
            } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}

            if (isCancelled) {
                cleanupOutput(outputPath)
            }
        }
    }

    private fun writeWavHeader(
        raf: RandomAccessFile,
        channels: Int,
        sampleRate: Int,
        bitsPerSample: Int,
        audioDataSize: Long
    ) {
        val totalDataLen = audioDataSize + 36
        val byteRate = (sampleRate * channels * bitsPerSample / 8).toLong()
        val header = ByteArray(44)
        val bb = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)

        // RIFF chunk
        bb.put('R'.code.toByte())
        bb.put('I'.code.toByte())
        bb.put('F'.code.toByte())
        bb.put('F'.code.toByte())
        bb.putInt(totalDataLen.toInt())
        bb.put('W'.code.toByte())
        bb.put('A'.code.toByte())
        bb.put('V'.code.toByte())
        bb.put('E'.code.toByte())

        // fmt chunk
        bb.put('f'.code.toByte())
        bb.put('m'.code.toByte())
        bb.put('t'.code.toByte())
        bb.put(' '.code.toByte())
        bb.putInt(16) // Subchunk1Size for PCM
        bb.putShort(1.toShort()) // AudioFormat 1 = PCM
        bb.putShort(channels.toShort())
        bb.putInt(sampleRate)
        bb.putInt(byteRate.toInt())
        bb.putShort(((channels * bitsPerSample) / 8).toShort()) // BlockAlign
        bb.putShort(bitsPerSample.toShort())

        // data chunk
        bb.put('d'.code.toByte())
        bb.put('a'.code.toByte())
        bb.put('t'.code.toByte())
        bb.put('a'.code.toByte())
        bb.putInt(audioDataSize.toInt())

        raf.write(header)
    }
}
