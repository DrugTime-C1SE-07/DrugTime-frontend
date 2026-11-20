package vn.drugtime.drugtime_mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/** Reminder sound picking, validation probe, MediaStore copy and preview playback. */
class ReminderSoundChannel(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "vn.drugtime.drugtime_mobile/reminder_sound"
        private const val PICK_REQUEST = 4107
        private const val MAX_BYTES = 10L * 1024 * 1024
        private const val HEAD_BYTES = 16
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPick: MethodChannel.Result? = null
    private var player: MediaPlayer? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "pick" -> pick(result)
            "probe" -> background(result) { probe(call.argument<String>("path")!!) }
            "commit" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("unsupported", "MediaStore insert needs API 29", null)
                } else {
                    background(result) {
                        commit(
                            call.argument<String>("path")!!,
                            call.argument<String>("id")!!,
                            call.argument<String>("ext")!!,
                            call.argument<Int>("number")!!,
                        )
                    }
                }
            }
            "discard" -> background(result) { File(call.argument<String>("path")!!).delete(); null }
            "delete" -> background(result) {
                delete(call.argument<String>("path")!!, call.argument<String>("uri")!!); null
            }
            "exists" -> background(result) {
                exists(call.argument<String>("path")!!, call.argument<String>("uri")!!)
            }
            "play" -> try {
                play(call.argument<String>("raw"), call.argument<String>("uri"))
                result.success(null)
            } catch (e: Exception) {
                stop()
                result.error("play_failed", e.message, null)
            }
            "stop" -> { stop(); result.success(null) }
            "openSoundSettings" -> {
                activity.startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun <T> background(result: MethodChannel.Result, block: () -> T) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("reminder_sound", e.message, null) }
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A pick is already in progress", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("audio/*")
        try {
            pendingPick = result
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            result.error("no_picker", e.message, null)
        }
    }

    /** Forwarded from [MainActivity.onActivityResult]; returns true when handled. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
        } else {
            background(result) { copyToTemp(uri) }
        }
        return true
    }

    // Stops reading past the size limit so a huge file is rejected without a full copy.
    private fun copyToTemp(uri: Uri): Map<String, Any> {
        val target = File(activity.cacheDir, "reminder_pick.tmp")
        val head = ByteArray(HEAD_BYTES)
        var headLength = 0
        var size = 0L
        val input = activity.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Cannot open picked file")
        input.use { stream ->
            FileOutputStream(target).use { out ->
                val buffer = ByteArray(8192)
                while (true) {
                    val read = stream.read(buffer)
                    if (read < 0) break
                    if (headLength < HEAD_BYTES) {
                        val count = minOf(HEAD_BYTES - headLength, read)
                        System.arraycopy(buffer, 0, head, headLength, count)
                        headLength += count
                    }
                    size += read
                    if (size > MAX_BYTES) break
                    out.write(buffer, 0, read)
                }
            }
        }
        return mapOf("path" to target.absolutePath, "size" to size, "head" to head.copyOf(headLength))
    }

    private fun probe(path: String): Int? {
        val retriever = MediaMetadataRetriever()
        val duration = try {
            retriever.setDataSource(path)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toIntOrNull()
        } catch (e: Exception) {
            null
        } finally {
            runCatching { retriever.release() }
        }
        if (duration == null) return null
        val decoder = MediaPlayer()
        return try {
            decoder.setDataSource(path)
            decoder.prepare()
            duration
        } catch (e: Exception) {
            null
        } finally {
            decoder.release()
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun commit(tempPath: String, id: String, ext: String, number: Int): Map<String, String> {
        val dir = File(activity.filesDir, "reminder_sounds").apply { mkdirs() }
        val file = File(dir, "$id.$ext")
        val temp = File(tempPath)
        temp.copyTo(file, overwrite = true)
        temp.delete()
        val resolver = activity.contentResolver
        try {
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, "DrugTime nhắc nhở $number.$ext")
                put(MediaStore.Audio.Media.TITLE, "DrugTime nhắc nhở $number")
                put(MediaStore.Audio.Media.MIME_TYPE, mimeOf(ext))
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_NOTIFICATIONS}/DrugTime")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            try {
                val out = resolver.openOutputStream(uri)
                    ?: throw IllegalStateException("Cannot write MediaStore entry")
                out.use { stream -> file.inputStream().use { it.copyTo(stream) } }
                resolver.update(uri, ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return mapOf("path" to file.absolutePath, "uri" to uri.toString())
        } catch (e: Exception) {
            file.delete()
            throw e
        }
    }

    private fun mimeOf(ext: String) = when (ext) {
        "mp3" -> "audio/mpeg"
        "m4a" -> "audio/mp4"
        "aac" -> "audio/aac"
        "ogg" -> "audio/ogg"
        "wav" -> "audio/wav"
        else -> "audio/*"
    }

    private fun delete(path: String, uri: String) {
        File(path).delete()
        runCatching { activity.contentResolver.delete(Uri.parse(uri), null, null) }
    }

    private fun exists(path: String, uri: String): Boolean {
        if (!File(path).exists()) return false
        return try {
            activity.contentResolver.openFileDescriptor(Uri.parse(uri), "r")?.use { true } ?: false
        } catch (e: Exception) {
            false
        }
    }

    private fun play(raw: String?, uri: String?) {
        stop()
        val source = when {
            raw != null -> Uri.parse("android.resource://${activity.packageName}/raw/$raw")
            uri != null -> Uri.parse(uri)
            else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        }
        val mediaPlayer = MediaPlayer()
        player = mediaPlayer
        mediaPlayer.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        mediaPlayer.setDataSource(activity, source)
        mediaPlayer.setOnCompletionListener {
            if (player === it) {
                player = null
                channel.invokeMethod("previewDone", null)
            }
            it.release()
        }
        mediaPlayer.prepare()
        mediaPlayer.start()
    }

    fun stop() {
        player?.let {
            player = null
            runCatching { it.stop() }
            it.release()
        }
    }
}
