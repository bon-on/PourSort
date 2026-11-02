package com.example.pour_sort

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val players = mutableSetOf<MediaPlayer>()
    private var musicPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pour_sort/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.7f
                    if (asset != null) {
                        playSound(asset, volume)
                    }
                    result.success(null)
                }
                "startLoop" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.4f
                    if (asset != null) {
                        startLoop(asset, volume)
                    }
                    result.success(null)
                }
                "stopLoop" -> {
                    stopLoop()
                    result.success(null)
                }
                "disposeAudio" -> {
                    disposeAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        disposeAudio()
        super.onDestroy()
    }

    private fun openPlayer(asset: String, contentType: Int): MediaPlayer {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val descriptor = assets.openFd(key)
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(contentType)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build(),
            )
            player.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length,
            )
            player.prepare()
        } catch (error: Exception) {
            player.release()
            throw error
        } finally {
            descriptor.close()
        }
        return player
    }

    private fun startLoop(asset: String, volume: Float) {
        stopLoop()
        runCatching {
            val player = openPlayer(asset, AudioAttributes.CONTENT_TYPE_MUSIC)
            player.isLooping = true
            player.setVolume(volume, volume)
            musicPlayer = player
            player.start()
        }.onFailure {
            musicPlayer?.release()
            musicPlayer = null
        }
    }

    private fun stopLoop() {
        runCatching { musicPlayer?.stop() }
        musicPlayer?.release()
        musicPlayer = null
    }

    private fun playSound(asset: String, volume: Float) {
        runCatching {
            val player = openPlayer(asset, AudioAttributes.CONTENT_TYPE_SONIFICATION)
            player.setVolume(volume, volume)
            player.setOnCompletionListener {
                players.remove(it)
                it.release()
            }
            players.add(player)
            player.start()
        }
    }

    private fun disposeAudio() {
        stopLoop()
        players.forEach { it.release() }
        players.clear()
    }
}
