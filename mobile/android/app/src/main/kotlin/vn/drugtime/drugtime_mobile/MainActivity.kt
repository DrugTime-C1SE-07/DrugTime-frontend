package vn.drugtime.drugtime_mobile

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val KEYGUARD_CHANNEL = "vn.drugtime.drugtime_mobile/keyguard"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    private var reminderSound: ReminderSoundChannel? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (reminderSound?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        reminderSound?.stop()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val soundChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ReminderSoundChannel.NAME)
        reminderSound = ReminderSoundChannel(this, soundChannel).also(soundChannel::setMethodCallHandler)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEYGUARD_CHANNEL).setMethodCallHandler { call, result ->
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            when (call.method) {
                "isKeyguardLocked" -> {
                    result.success(keyguardManager.isKeyguardLocked)
                }
                "requestDismissKeyguard" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        keyguardManager.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                            override fun onDismissSucceeded() {
                                result.success(true)
                            }
                            override fun onDismissCancelled() {
                                result.success(false)
                            }
                            override fun onDismissError() {
                                result.success(false)
                            }
                        })
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
