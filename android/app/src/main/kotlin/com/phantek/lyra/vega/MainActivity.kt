// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

package com.phantek.lyra.vega

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.system.Os
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "com.phantek.lyra.vega/media_scanner"
    private val TRANSFORMER_CHANNEL = "com.phantek.lyra.vega/transformer"

    private val REQUEST_CODE_PICK_VIDEO = 0x5647
    private val REQUEST_CODE_PERMISSION_PICK = 0x5648
    private val REQUEST_CODE_PERMISSION_SHARE = 0x5649

    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSharedVideoPath: String? = null
    private var pendingPickVideoResult: MethodChannel.Result? = null
    private var pendingShareIntentUri: Uri? = null

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
                "getVideoThumbnail" -> handleGetVideoThumbnail(call, result)
                "getHardwareEncoders" -> handleGetHardwareEncoders(result)
                "transcodeVideo" -> handleTranscodeVideo(call, result)
                "extractAudio" -> handleExtractAudio(call, result)
                "cancelTransformation" -> handleCancelTransformation(result)
                "getInitialSharedVideo" -> {
                    result.success(pendingSharedVideoPath)
                    pendingSharedVideoPath = null
                }
                "resolveMediaDetails" -> handleResolveMediaDetails(call, result)
                "pickVideo" -> handlePickVideo(result)
                else -> result.notImplemented()
            }
        }

        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun hasMediaReadPermission(): Boolean {
        val perm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_VIDEO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestMediaReadPermission(requestCode: Int) {
        val perm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_VIDEO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        ActivityCompat.requestPermissions(this, arrayOf(perm), requestCode)
    }

    private fun handlePickVideo(result: MethodChannel.Result) {
        if (pendingPickVideoResult != null) {
            result.error("ALREADY_ACTIVE", "Video picker is already active", null)
            return
        }
        pendingPickVideoResult = result
        if (!hasMediaReadPermission()) {
            requestMediaReadPermission(REQUEST_CODE_PERMISSION_PICK)
        } else {
            launchSystemVideoPicker()
        }
    }

    @Suppress("DEPRECATION")
    private fun launchSystemVideoPicker() {
        try {
            val openDocIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "video/*"
                putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            }
            startActivityForResult(openDocIntent, REQUEST_CODE_PICK_VIDEO)
        } catch (_: ActivityNotFoundException) {
            try {
                val getContentIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "video/*"
                }
                startActivityForResult(getContentIntent, REQUEST_CODE_PICK_VIDEO)
            } catch (e: Exception) {
                val callback = pendingPickVideoResult
                pendingPickVideoResult = null
                callback?.error("PICKER_ERROR", e.localizedMessage ?: "No file picker found", null)
            }
        } catch (e: Exception) {
            val callback = pendingPickVideoResult
            pendingPickVideoResult = null
            callback?.error("PICKER_ERROR", e.localizedMessage ?: "Failed to launch picker", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_CODE_PERMISSION_PICK -> {
                launchSystemVideoPicker()
            }
            REQUEST_CODE_PERMISSION_SHARE -> {
                val uri = pendingShareIntentUri
                pendingShareIntentUri = null
                if (uri != null) {
                    processSharedVideoUri(uri)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_VIDEO) {
            val callback = pendingPickVideoResult ?: return
            pendingPickVideoResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data!!
            Executors.newSingleThreadExecutor().execute {
                try {
                    val resolved = resolveUriToPathAndName(uri)
                    mainHandler.post {
                        if (resolved != null) {
                            callback.success(
                                mapOf(
                                    "path" to resolved.first,
                                    "fileName" to resolved.second,
                                    "uri" to uri.toString()
                                )
                            )
                        } else {
                            callback.success(null)
                        }
                    }
                } catch (_: Exception) {
                    mainHandler.post { callback.success(null) }
                }
            }
        }
    }

    private fun handleResolveMediaDetails(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri")
        val filePath = call.argument<String>("filePath")
        if (uriStr.isNullOrEmpty() && filePath.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "uri or filePath is required", null)
            return
        }
        Executors.newSingleThreadExecutor().execute {
            try {
                val uri = if (!uriStr.isNullOrEmpty()) {
                    Uri.parse(uriStr)
                } else {
                    Uri.fromFile(File(filePath!!))
                }
                val details = resolveMediaDetails(applicationContext, uri, filePath)
                mainHandler.post { result.success(details) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.success(
                        mapOf(
                            "fileName" to null,
                            "realPath" to null
                        )
                    )
                }
            }
        }
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        val isSend = Intent.ACTION_SEND == action
        val isView = Intent.ACTION_VIEW == action

        if (!isSend && !isView) return

        val uri: Uri? = if (isSend) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            } ?: intent.data
        } else {
            intent.data
        }

        if (uri == null) return

        val isVideoType = type?.startsWith("video/") == true ||
            type == "*/*" ||
            type == "application/octet-stream" ||
            try { contentResolver.getType(uri)?.startsWith("video/") == true } catch (_: Exception) { false }

        if (!isVideoType) return

        if (!hasMediaReadPermission()) {
            pendingShareIntentUri = uri
            requestMediaReadPermission(REQUEST_CODE_PERMISSION_SHARE)
            return
        }

        processSharedVideoUri(uri)
    }

    private fun processSharedVideoUri(uri: Uri) {
        Executors.newSingleThreadExecutor().execute {
            try {
                val resolved = resolveUriToPathAndName(uri)
                if (resolved != null) {
                    val (resolvedPath, resolvedName) = resolved
                    pendingSharedVideoPath = resolvedPath
                    mainHandler.post {
                        methodChannel?.invokeMethod(
                            "onSharedVideoReceived",
                            mapOf(
                                "path" to resolvedPath,
                                "fileName" to resolvedName
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun resolveUriToPathAndName(uri: Uri): Pair<String, String>? {
        return try {
            val details = resolveMediaDetails(applicationContext, uri)
            var displayName = details["fileName"] as? String
            val directPath = details["realPath"] as? String
            if (!directPath.isNullOrEmpty()) {
                val directFile = File(directPath)
                if (directFile.exists() && directFile.canRead() && !isSyntheticOrCachePath(applicationContext, directFile.absolutePath)) {
                    val finalName = if (!displayName.isNullOrBlank()) displayName!! else directFile.name
                    return Pair(directFile.absolutePath, finalName)
                }
            }

            if (uri.scheme == "file" || uri.scheme.isNullOrEmpty()) {
                val p = uri.path ?: return null
                val f = File(p)
                if (f.exists() && f.canRead()) {
                    val finalName = if (!displayName.isNullOrBlank()) displayName!! else f.name
                    return Pair(f.absolutePath, finalName)
                }
            }

            if (displayName.isNullOrBlank()) {
                displayName = "video.mp4"
            }

            if (!displayName!!.contains(".")) {
                val mimeType = try { contentResolver.getType(uri) } catch (_: Exception) { null }
                val ext = when (mimeType) {
                    "video/mp4" -> ".mp4"
                    "video/x-matroska" -> ".mkv"
                    "video/quicktime" -> ".mov"
                    "video/webm" -> ".webm"
                    "video/3gpp" -> ".3gp"
                    "video/avi", "video/x-msvideo" -> ".avi"
                    else -> ".mp4"
                }
                displayName += ext
            }

            val sanitized = displayName!!.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val targetDir = File(cacheDir, "shared_incoming")
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            var targetFile = File(targetDir, "shared_video_${System.currentTimeMillis()}_$sanitized")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            if (targetFile.exists() && targetFile.length() > 0) {
                if (displayName!!.endsWith(".ts", ignoreCase = true) && isMp4FileHeader(targetFile)) {
                    displayName = displayName!!.substringBeforeLast('.') + ".mp4"
                    val mp4Sanitized = displayName!!.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                    val renamedFile = File(targetDir, "shared_video_${System.currentTimeMillis()}_$mp4Sanitized")
                    if (targetFile.renameTo(renamedFile)) {
                        targetFile = renamedFile
                    }
                }
                Pair(targetFile.absolutePath, displayName!!)
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun isSyntheticOrCachePath(context: Context, path: String?): Boolean {
        if (path.isNullOrEmpty()) return true
        val normalized = path.replace('\\', '/')
        if (normalized.contains("/.transforms/")) return true
        if (normalized.contains("/file_picker/")) return true
        if (normalized.contains("/shared_incoming/")) return true
        val appCache = context.cacheDir.absolutePath.replace('\\', '/')
        if (normalized.startsWith(appCache)) return true
        return false
    }

    private fun isRedactedPickerName(name: String?, mediaId: Long?): Boolean {
        if (name.isNullOrBlank()) return true
        if (name.startsWith("shared_video_") || name.startsWith("cache_")) return true
        val stem = name.substringBeforeLast('.')
        if (mediaId != null && stem == mediaId.toString()) return true
        if (stem.matches(Regex("^\\d{5,}$")) && name.endsWith(".ts", ignoreCase = true)) return true
        return false
    }

    private fun normalizeKernelPath(rawPath: String): String {
        val normalized = rawPath.replace('\\', '/')
        val prefixes = listOf(
            "/data/media/0/",
            "/mnt/user/0/emulated/0/",
            "/mnt/pass_through/0/emulated/0/",
            "/mnt/runtime/default/emulated/0/",
            "/mnt/runtime/read/emulated/0/",
            "/mnt/runtime/write/emulated/0/"
        )
        for (prefix in prefixes) {
            if (normalized.startsWith(prefix)) {
                return "/storage/emulated/0/" + normalized.removePrefix(prefix)
            }
        }
        return normalized
    }

    private fun isMp4FileHeader(file: File): Boolean {
        return try {
            if (!file.exists() || file.length() < 12) return false
            RandomAccessFile(file, "r").use { raf ->
                val buf = ByteArray(8)
                raf.readFully(buf)
                buf[4] == 'f'.code.toByte() &&
                    buf[5] == 't'.code.toByte() &&
                    buf[6] == 'y'.code.toByte() &&
                    buf[7] == 'p'.code.toByte()
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun resolveMediaDetails(context: Context, uri: Uri, fallbackPath: String? = null): Map<String, Any?> {
        var resolvedName: String? = null
        var resolvedRealPath: String? = null
        var mediaId: Long? = null
        var probedSize: Long = 0L

        fun applyCandidateFromCursor(queryTarget: Uri) {
            try {
                val projection = arrayOf(
                    MediaStore.MediaColumns.DATA,
                    OpenableColumns.DISPLAY_NAME,
                    OpenableColumns.SIZE
                )
                context.contentResolver.query(queryTarget, projection, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeIdx != -1 && probedSize <= 0L) {
                            probedSize = cursor.getLong(sizeIdx)
                        }
                        val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                        if (dataIdx != -1) {
                            val dataPath = cursor.getString(dataIdx)
                            if (!dataPath.isNullOrEmpty() && !isSyntheticOrCachePath(context, dataPath)) {
                                val f = File(dataPath)
                                if (f.name.isNotEmpty() && !isRedactedPickerName(f.name, mediaId)) {
                                    resolvedName = f.name
                                }
                                if (f.exists() && f.canRead()) {
                                    resolvedRealPath = f.absolutePath
                                }
                            }
                        }
                        if (resolvedName.isNullOrEmpty()) {
                            val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (nameIdx != -1) {
                                val dn = cursor.getString(nameIdx)
                                if (!dn.isNullOrEmpty() && !isRedactedPickerName(dn, mediaId)) {
                                    resolvedName = dn
                                }
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        fun queryByMediaId(id: Long) {
            val candidateUris = listOf(
                ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id),
                MediaStore.Files.getContentUri("external", id),
                ContentUris.withAppendedId(Uri.parse("content://downloads/public_downloads"), id)
            )
            for (candidate in candidateUris) {
                if (!resolvedName.isNullOrEmpty() && resolvedRealPath != null) break
                applyCandidateFromCursor(candidate)
            }
        }

        // 1. Extract DocumentContract details and numeric MediaStore ID if present
        if (uri.scheme == "content" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && DocumentsContract.isDocumentUri(context, uri)) {
            try {
                val docId = DocumentsContract.getDocumentId(uri)
                if (!docId.isNullOrEmpty()) {
                    val authority = uri.authority
                    if (authority == "com.android.externalstorage.documents" || docId.startsWith("primary:", ignoreCase = true)) {
                        val relPath = docId.substringAfter(':', "")
                        if (relPath.isNotEmpty()) {
                            val nameFromRel = File(relPath).name
                            if (nameFromRel.isNotEmpty()) {
                                resolvedName = nameFromRel
                            }
                            @Suppress("DEPRECATION")
                            val storageDir = Environment.getExternalStorageDirectory()
                            val primaryFile = File(storageDir, relPath)
                            if (primaryFile.exists()) {
                                resolvedName = primaryFile.name
                                if (primaryFile.canRead()) {
                                    resolvedRealPath = primaryFile.absolutePath
                                }
                            }
                        }
                    } else if (docId.startsWith("raw:", ignoreCase = true)) {
                        val rawPath = docId.substringAfter("raw:")
                        if (rawPath.isNotEmpty()) {
                            val rawFile = File(rawPath)
                            if (rawFile.name.isNotEmpty()) {
                                resolvedName = rawFile.name
                            }
                            if (rawFile.exists() && rawFile.canRead()) {
                                resolvedRealPath = rawFile.absolutePath
                            }
                        }
                    } else {
                        val idPart = docId.substringAfterLast(':')
                        mediaId = idPart.toLongOrNull()
                    }
                }
            } catch (_: Exception) {}
        }

        if (mediaId == null && uri.scheme == "content") {
            val lastSeg = uri.lastPathSegment?.substringAfterLast(':')
            mediaId = lastSeg?.toLongOrNull()
        }

        if (mediaId == null) {
            val candidatePaths = listOfNotNull(uri.path, fallbackPath)
            for (p in candidatePaths) {
                if (isSyntheticOrCachePath(context, p)) {
                    val stem = File(p).nameWithoutExtension
                    if (stem.matches(Regex("^\\d+$"))) {
                        mediaId = stem.toLongOrNull()
                        if (mediaId != null) break
                    }
                }
            }
        }

        // 2. Android 11+ / 13+ MediaStore.getMediaUri unwrapping for Photo Picker & MediaDocumentsProvider
        var unwrappedMediaUri: Uri? = null
        if (uri.scheme == "content" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                unwrappedMediaUri = MediaStore.getMediaUri(context, uri)
                if (unwrappedMediaUri != null) {
                    if (mediaId == null) {
                        mediaId = unwrappedMediaUri.lastPathSegment?.toLongOrNull()
                    }
                    applyCandidateFromCursor(unwrappedMediaUri)
                }
            } catch (_: Exception) {}
        }

        // 3. Query MediaStore by numeric mediaId
        if (mediaId != null && (resolvedName.isNullOrEmpty() || resolvedRealPath == null)) {
            queryByMediaId(mediaId!!)
        }

        // 4. Kernel file descriptor symlink (/proc/self/fd/<fd>) inspection
        if (uri.scheme == "content" && (resolvedName.isNullOrEmpty() || resolvedRealPath == null)) {
            val fdUris = listOfNotNull(
                unwrappedMediaUri,
                mediaId?.let { ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, it) },
                uri
            ).distinct()
            for (targetUri in fdUris) {
                try {
                    context.contentResolver.openFileDescriptor(targetUri, "r")?.use { pfd ->
                        if (probedSize <= 0L && pfd.statSize > 0L) {
                            probedSize = pfd.statSize
                        }
                        val fdLink = try { Os.readlink("/proc/self/fd/${pfd.fd}") } catch (_: Exception) { null }
                        if (!fdLink.isNullOrEmpty()) {
                            val norm = normalizeKernelPath(fdLink)
                            if (!isSyntheticOrCachePath(context, norm)) {
                                val fdFile = File(norm)
                                if (fdFile.name.isNotEmpty() && !isRedactedPickerName(fdFile.name, mediaId)) {
                                    resolvedName = fdFile.name
                                }
                                if (fdFile.exists() && fdFile.canRead() && resolvedRealPath == null) {
                                    resolvedRealPath = fdFile.absolutePath
                                }
                            } else if (mediaId == null) {
                                val stem = File(norm).nameWithoutExtension
                                val extractedId = stem.toLongOrNull()
                                if (extractedId != null) {
                                    mediaId = extractedId
                                    queryByMediaId(extractedId)
                                }
                            }
                        }
                    }
                } catch (_: Exception) {}
                if (!resolvedName.isNullOrEmpty() && resolvedRealPath != null) break
            }
        }

        // 5. Direct query on original content URI with synthetic/redacted filtering
        if (uri.scheme == "content" && (resolvedName.isNullOrEmpty() || resolvedRealPath == null)) {
            applyCandidateFromCursor(uri)
        }

        // 6. Fallback query in MediaStore by exact byte size when filename is still unresolved
        if (resolvedName.isNullOrEmpty()) {
            if (probedSize <= 0L) {
                val p = fallbackPath ?: uri.path
                if (!p.isNullOrEmpty()) {
                    val f = File(p)
                    if (f.exists()) probedSize = f.length()
                }
            }
            if (probedSize > 0L) {
                try {
                    val projection = arrayOf(
                        MediaStore.MediaColumns.DATA,
                        OpenableColumns.DISPLAY_NAME
                    )
                    context.contentResolver.query(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                        projection,
                        "${MediaStore.MediaColumns.SIZE} = ?",
                        arrayOf(probedSize.toString()),
                        "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                            if (dataIdx != -1) {
                                val dataPath = cursor.getString(dataIdx)
                                if (!dataPath.isNullOrEmpty() && !isSyntheticOrCachePath(context, dataPath)) {
                                    val f = File(dataPath)
                                    if (f.name.isNotEmpty()) resolvedName = f.name
                                    if (f.exists() && f.canRead() && resolvedRealPath == null) {
                                        resolvedRealPath = f.absolutePath
                                    }
                                }
                            }
                            if (resolvedName.isNullOrEmpty()) {
                                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                if (nameIdx != -1) {
                                    val dn = cursor.getString(nameIdx)
                                    if (!dn.isNullOrEmpty() && !isRedactedPickerName(dn, mediaId)) {
                                        resolvedName = dn
                                    }
                                }
                            }
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        // 7. Handle non-synthetic file URI or fallbackPath
        val localCandidates = listOfNotNull(
            if (uri.scheme == "file" || uri.scheme.isNullOrEmpty()) uri.path else null,
            fallbackPath
        )
        for (p in localCandidates) {
            if (p.isNotEmpty()) {
                val f = File(p)
                if (f.exists()) {
                    if (!isSyntheticOrCachePath(context, f.absolutePath)) {
                        if (resolvedName.isNullOrEmpty()) resolvedName = f.name
                        if (f.canRead() && resolvedRealPath == null) resolvedRealPath = f.absolutePath
                    } else {
                        if (f.canRead() && resolvedRealPath == null) resolvedRealPath = f.absolutePath
                        if (resolvedName.isNullOrEmpty() && !isRedactedPickerName(f.name, mediaId)) {
                            resolvedName = f.name
                        }
                    }
                }
            }
        }

        if (resolvedName.isNullOrEmpty()) {
            val lastSeg = uri.lastPathSegment
            if (!lastSeg.isNullOrEmpty() && !isRedactedPickerName(lastSeg, mediaId)) {
                resolvedName = lastSeg
            }
        }

        if (resolvedName != null && !resolvedName!!.contains(".")) {
            val mimeType = try { context.contentResolver.getType(uri) } catch (_: Exception) { null }
            val ext = when (mimeType) {
                "video/mp4" -> ".mp4"
                "video/x-matroska" -> ".mkv"
                "video/quicktime" -> ".mov"
                "video/webm" -> ".webm"
                "video/3gpp" -> ".3gp"
                "video/avi", "video/x-msvideo" -> ".avi"
                else -> ".mp4"
            }
            resolvedName += ext
        }

        // 8. Correct bogus .ts extension when container is an actual MP4 (ftyp header)
        if (resolvedName != null && resolvedName!!.endsWith(".ts", ignoreCase = true)) {
            val checkFile = resolvedRealPath?.let { File(it) } ?: fallbackPath?.let { File(it) }
            if (checkFile != null && isMp4FileHeader(checkFile)) {
                resolvedName = resolvedName!!.substringBeforeLast('.') + ".mp4"
            }
        }

        return mapOf(
            "fileName" to resolvedName,
            "realPath" to resolvedRealPath
        )
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

    private fun handleGetVideoThumbnail(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "filePath is required", null)
            return
        }

        Executors.newSingleThreadExecutor().execute {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(filePath)
                val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    retriever.getScaledFrameAtTime(1000000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 256, 256)
                        ?: retriever.frameAtTime
                } else {
                    retriever.frameAtTime
                }

                if (bitmap != null) {
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                    val byteArray = stream.toByteArray()
                    bitmap.recycle()
                    mainHandler.post { result.success(byteArray) }
                } else {
                    mainHandler.post { result.success(null) }
                }
            } catch (e: Exception) {
                mainHandler.post { result.success(null) }
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {}
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
        val trimStartMs = (call.argument<Number>("trimStartMs"))?.toLong()
        val trimEndMs = (call.argument<Number>("trimEndMs"))?.toLong()

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
            val mediaItemBuilder = MediaItem.Builder().setUri(Uri.fromFile(inputFile))
            val startMs = trimStartMs ?: 0L
            val endMs = trimEndMs ?: 0L
            val isTrimmed = (startMs > 0L) || (endMs > 0L && endMs > startMs)
            if (isTrimmed) {
                val clippingBuilder = MediaItem.ClippingConfiguration.Builder()
                if (startMs > 0L) {
                    clippingBuilder.setStartPositionMs(startMs)
                }
                if (endMs > startMs) {
                    clippingBuilder.setEndPositionMs(endMs)
                }
                clippingBuilder.setStartsAtKeyFrame(false)
                mediaItemBuilder.setClippingConfiguration(clippingBuilder.build())
            }
            val mediaItem = mediaItemBuilder.build()

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

            // C.TIME_UNSET prevents sample timeouts and timestamp gaps on long/TS media
            val transformerBuilder = Transformer.Builder(applicationContext)
                .setVideoMimeType(targetVideoMime)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
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

        } catch (t: Throwable) {
            cleanupOutput(outputPath)
            activeTransformer = null
            stopProgressPolling()
            val res = activeTranscodeResult
            activeTranscodeResult = null
            res?.error("TRANSCODE_INIT_FAILED", t.localizedMessage ?: "Failed to start transcoding", null)
        }
    }

    private fun handleExtractAudio(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val format = call.argument<String>("format") ?: "m4a"
        val bitrateKbps = call.argument<Int>("bitrateKbps") ?: 192
        val trimStartMs = (call.argument<Number>("trimStartMs"))?.toLong()
        val trimEndMs = (call.argument<Number>("trimEndMs"))?.toLong()

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
                    extractAudioToWav(inputPath, outputPath, trimStartMs, trimEndMs)
                    mainHandler.post {
                        sendProgress(1.0, File(outputPath).length())
                        sendLog("WAV extraction completed successfully!")
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        res?.success(outputPath)
                    }
                } catch (t: Throwable) {
                    cleanupOutput(outputPath)
                    mainHandler.post {
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        res?.error("WAV_EXTRACTION_FAILED", t.localizedMessage ?: "WAV extraction failed", null)
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
                    val success = extractAudioDirectStream(inputPath, outputPath, "audio/mpeg", trimStartMs, trimEndMs)
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
                } catch (t: Throwable) {
                    cleanupOutput(outputPath)
                    mainHandler.post {
                        val res = activeAudioExtractResult
                        activeAudioExtractResult = null
                        res?.error("MP3_EXTRACTION_FAILED", t.localizedMessage ?: "MP3 extraction failed", null)
                    }
                }
            }
            return
        }

        // For M4A/AAC: Use AndroidX Media3 Transformer
        try {
            val inputFile = File(inputPath)
            val mediaItemBuilder = MediaItem.Builder().setUri(Uri.fromFile(inputFile))
            val startMs = trimStartMs ?: 0L
            val endMs = trimEndMs ?: 0L
            val isTrimmed = (startMs > 0L) || (endMs > 0L && endMs > startMs)
            if (isTrimmed) {
                val clippingBuilder = MediaItem.ClippingConfiguration.Builder()
                if (startMs > 0L) {
                    clippingBuilder.setStartPositionMs(startMs)
                }
                if (endMs > startMs) {
                    clippingBuilder.setEndPositionMs(endMs)
                }
                clippingBuilder.setStartsAtKeyFrame(false)
                mediaItemBuilder.setClippingConfiguration(clippingBuilder.build())
            }
            val mediaItem = mediaItemBuilder.build()
            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setRemoveVideo(true)
                .build()

            val transformer = Transformer.Builder(applicationContext)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
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

        } catch (t: Throwable) {
            cleanupOutput(outputPath)
            activeTransformer = null
            stopProgressPolling()
            val res = activeAudioExtractResult
            activeAudioExtractResult = null
            res?.error("AUDIO_EXTRACTION_INIT_FAILED", t.localizedMessage ?: "Failed to start audio extraction", null)
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
    private fun extractAudioDirectStream(
        inputPath: String,
        outputPath: String,
        targetMime: String,
        trimStartMs: Long? = null,
        trimEndMs: Long? = null
    ): Boolean {
        val startMs = trimStartMs ?: 0L
        val endMs = trimEndMs ?: 0L
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
            if (startMs > 0L) {
                extractor.seekTo(startMs * 1000L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            }
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
                    if (endMs > startMs && extractor.sampleTime > endMs * 1000L) {
                        break
                    }
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
    private fun extractAudioToWav(
        inputPath: String,
        outputPath: String,
        trimStartMs: Long? = null,
        trimEndMs: Long? = null
    ) {
        val startMs = trimStartMs ?: 0L
        val endMs = trimEndMs ?: 0L
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
            if (startMs > 0L) {
                extractor.seekTo(startMs * 1000L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            }
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
                            val pts = extractor.sampleTime
                            if (sampleSize < 0 || (endMs > startMs && pts > endMs * 1000L)) {
                                dec.queueInputBuffer(inputBufIndex, 0, 0, 0L, android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isExtractorDone = true
                            } else {
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
