package com.ichuk.cybertetris.app

import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.nio.ByteBuffer

/**
 * Hardware-accelerated H.264 video encoder using MediaCodec + MediaMuxer.
 * Receives raw RGBA frames from Dart, converts to YUV420, encodes, and muxes to MP4.
 */
class VideoEncoder(
    private val width: Int,
    private val height: Int,
    private val fps: Int,
    private val bitRate: Int,
    private val outputPath: String
) {
    private lateinit var codec: MediaCodec
    private lateinit var muxer: MediaMuxer
    private var trackIndex = -1
    private var muxerStarted = false
    private var frameIndex = 0
    private val bufferInfo = MediaCodec.BufferInfo()

    fun start() {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        format.setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        )
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)

        codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()

        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    fun addFrame(rgbaData: ByteArray) {
        // Convert RGBA to NV21 (YUV420SemiPlanar)
        val nv21 = rgbaToNv21(rgbaData, width, height)

        // Get input buffer
        val inputIndex = codec.dequeueInputBuffer(10_000)
        if (inputIndex >= 0) {
            val inputBuffer = codec.getInputBuffer(inputIndex) ?: return
            inputBuffer.clear()
            inputBuffer.put(nv21)

            val pts = frameIndex * 1_000_000L / fps
            codec.queueInputBuffer(inputIndex, 0, nv21.size, pts, 0)
            frameIndex++
        }

        // Drain output
        drainEncoder(false)
    }

    fun finish(): String {
        // Signal end of stream
        val inputIndex = codec.dequeueInputBuffer(10_000)
        if (inputIndex >= 0) {
            codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        }

        drainEncoder(true)

        codec.stop()
        codec.release()
        muxer.stop()
        muxer.release()

        return outputPath
    }

    private fun drainEncoder(endOfStream: Boolean) {
        val timeoutUs = if (endOfStream) 10_000L else 0L

        while (true) {
            val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
            when {
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    trackIndex = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                outputIndex >= 0 -> {
                    val outputBuffer = codec.getOutputBuffer(outputIndex) ?: continue

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }

                    if (bufferInfo.size > 0 && muxerStarted) {
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }

                    codec.releaseOutputBuffer(outputIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return
                    }
                }
                else -> {
                    if (!endOfStream) return
                }
            }
        }
    }

    companion object {
        /**
         * Convert RGBA pixel data to NV21 (YUV420SemiPlanar).
         * Performance: ~2ms for 360x640 on modern devices.
         */
        fun rgbaToNv21(rgba: ByteArray, width: Int, height: Int): ByteArray {
            val ySize = width * height
            val nv21 = ByteArray(ySize * 3 / 2)

            for (i in 0 until height) {
                for (j in 0 until width) {
                    val rgbaIdx = (i * width + j) * 4
                    val r = rgba[rgbaIdx].toInt() and 0xFF
                    val g = rgba[rgbaIdx + 1].toInt() and 0xFF
                    val b = rgba[rgbaIdx + 2].toInt() and 0xFF

                    // Y plane
                    val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                    nv21[i * width + j] = y.coerceIn(0, 255).toByte()

                    // UV plane (subsampled 2x2)
                    if (i % 2 == 0 && j % 2 == 0) {
                        val uvIdx = ySize + (i / 2) * width + j
                        val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                        val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                        nv21[uvIdx] = v.coerceIn(0, 255).toByte()
                        nv21[uvIdx + 1] = u.coerceIn(0, 255).toByte()
                    }
                }
            }
            return nv21
        }

        /**
         * Save a video file to the device gallery via MediaStore.
         */
        fun saveToGallery(context: Context, videoPath: String, fileName: String): Boolean {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/CyberBlockx")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
            }

            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                ?: return false

            return try {
                resolver.openOutputStream(uri)?.use { output ->
                    File(videoPath).inputStream().use { input ->
                        input.copyTo(output)
                    }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                }
                // Clean up temp file
                File(videoPath).delete()
                true
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                false
            }
        }
    }
}
