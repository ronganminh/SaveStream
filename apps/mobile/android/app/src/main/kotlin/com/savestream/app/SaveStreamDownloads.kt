package com.savestream.app

import android.annotation.TargetApi
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.IOException

/**
 * Saves recordings into the public Downloads/SaveStream folder.
 *
 * Android 10+ (API 29) writes through MediaStore.Downloads with no storage
 * permission. Android 7-9 has no permission-free way to write to the public
 * Downloads folder, so it falls back to the app-specific
 * getExternalFilesDir(DIRECTORY_DOWNLOADS)/SaveStream (also no permission).
 *
 * Results are maps with "uri" (content URI, API 29+) or "path" (file path,
 * API < 29), plus "display_name" and "size_bytes".
 */
object SaveStreamDownloads {
    private const val FOLDER = "SaveStream"
    private const val BUFFER_SIZE = 1 shl 16

    fun save(context: Context, source: File, displayName: String, mimeType: String): Map<String, Any?> {
        if (!source.isFile) throw IOException("Source file is missing.")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveToMediaStore(context, source, displayName, mimeType)
        } else {
            saveToAppDownloads(context, source, displayName)
        }
    }

    fun find(context: Context, displayName: String): Map<String, Any?>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            findInMediaStore(context, displayName)
        } else {
            val file = File(appDownloadsDir(context), displayName)
            if (file.isFile) describe(file) else null
        }
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun collection(): Uri = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

    @TargetApi(Build.VERSION_CODES.Q)
    private fun relativePath(): String = Environment.DIRECTORY_DOWNLOADS + "/" + FOLDER + "/"

    @TargetApi(Build.VERSION_CODES.Q)
    private fun saveToMediaStore(
        context: Context,
        source: File,
        displayName: String,
        mimeType: String,
    ): Map<String, Any?> {
        val resolver = context.contentResolver
        // An earlier save that never finished (process killed) leaves a
        // pending row of ours behind; drop it so the name stays free.
        resolver.delete(
            collection(),
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND " +
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND " +
                "${MediaStore.MediaColumns.IS_PENDING}=1",
            arrayOf(relativePath(), displayName),
        )

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath())
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection(), values)
            ?: throw IOException("MediaStore insert failed.")
        try {
            val output = resolver.openOutputStream(uri, "w")
                ?: throw IOException("Could not open the Downloads entry.")
            output.use { out ->
                source.inputStream().use { input -> input.copyTo(out, BUFFER_SIZE) }
            }
            val done = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, done, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        return describe(context, uri) ?: mapOf(
            "uri" to uri.toString(),
            "display_name" to displayName,
            "size_bytes" to source.length(),
        )
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun findInMediaStore(context: Context, displayName: String): Map<String, Any?>? {
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        context.contentResolver.query(
            collection(),
            projection,
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND " +
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND " +
                "${MediaStore.MediaColumns.IS_PENDING}=0",
            arrayOf(relativePath(), displayName),
            "${MediaStore.MediaColumns.DATE_ADDED} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                return describe(context, ContentUris.withAppendedId(collection(), id))
            }
        }
        return null
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun describe(context: Context, uri: Uri): Map<String, Any?>? {
        val projection = arrayOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
        )
        context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                return mapOf(
                    "uri" to uri.toString(),
                    "display_name" to cursor.getString(0),
                    "size_bytes" to if (cursor.isNull(1)) null else cursor.getLong(1),
                )
            }
        }
        return null
    }

    private fun appDownloadsDir(context: Context): File {
        val base = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IOException("External storage is unavailable.")
        return File(base, FOLDER)
    }

    private fun saveToAppDownloads(context: Context, source: File, displayName: String): Map<String, Any?> {
        val dir = appDownloadsDir(context)
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException("Could not create $dir.")
        val target = File(dir, displayName)
        val partial = File(dir, "$displayName.part")
        try {
            source.inputStream().use { input ->
                partial.outputStream().use { out -> input.copyTo(out, BUFFER_SIZE) }
            }
            if (target.exists() && !target.delete()) throw IOException("Could not replace $target.")
            if (!partial.renameTo(target)) throw IOException("Could not finish $target.")
        } catch (error: Exception) {
            partial.delete()
            throw error
        }
        return describe(target)
    }

    private fun describe(file: File): Map<String, Any?> = mapOf(
        "path" to file.absolutePath,
        "display_name" to file.name,
        "size_bytes" to file.length(),
    )
}
