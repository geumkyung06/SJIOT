package com.example.device_app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 조립대 단말용 화면 고정(lock task).
 *
 * 기기 소유자(device owner)로 등록돼 있지 않으면 처음 startLockTask() 때
 * 시스템이 확인 창을 한 번 띄운다. 고정 중에는 홈·최근앱이 동작하지 않고,
 * 앱에서 관리자 비밀번호를 통과했을 때만 stopLockTask()로 풀린다.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "device_app/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockTask" -> {
                        try {
                            if (!isInLockTaskMode()) {
                                startLockTask()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOCK_TASK_FAILED", e.message, null)
                        }
                    }

                    "stopLockTask" -> {
                        try {
                            if (isInLockTaskMode()) {
                                stopLockTask()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNLOCK_TASK_FAILED", e.message, null)
                        }
                    }

                    "isLocked" -> result.success(isInLockTaskMode())

                    else -> result.notImplemented()
                }
            }
    }

    private fun isInLockTaskMode(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            am.isInLockTaskMode
        }
    }
}
