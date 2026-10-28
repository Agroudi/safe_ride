package com.example.basecode

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Two things Flutter does not do on its own.
 *
 * - **The launch hand-off.** On Android 12+ the system splash is removed the
 *   moment it may go — Flutter's first frame repeats it pixel for pixel — and
 *   Dart's `LaunchHandoff.wait` is answered, so the splash intro starts on
 *   screen instead of behind a fading system splash.
 * - **The display's fastest mode.** Some phones keep an app at 60 Hz unless
 *   it asks; this asks for the highest refresh rate at the current
 *   resolution, so motion runs at 90 or 120 Hz where the screen can.
 */
class MainActivity : FlutterActivity() {
    private var handedOff = Build.VERSION.SDK_INT < Build.VERSION_CODES.S
    private val waiting = mutableListOf<MethodChannel.Result>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestRefreshRate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view ->
                view.remove()
                handOff()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when {
                    call.method != "handedOff" -> result.notImplemented()
                    handedOff -> result.success(null)
                    else -> waiting += result
                }
            }
    }

    private fun handOff() {
        handedOff = true
        waiting.forEach { it.success(null) }
        waiting.clear()
    }

    private fun preferFastestRefreshRate() {
        val screen: Display = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
        ) ?: return
        val current = screen.mode
        val fastest = screen.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        window.attributes = window.attributes.also {
            it.preferredDisplayModeId = fastest.modeId
        }
    }

    private companion object {
        const val CHANNEL = "safe_ride/launch"
    }
}
