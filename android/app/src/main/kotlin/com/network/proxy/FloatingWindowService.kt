package com.network.proxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.RelativeLayout
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

/**
 * 常驻悬浮窗服务：通过前台服务提升进程优先级，降低后台被系统回收的概率，
 * 从而保持 Dart 层 MCP Server 等服务的连接。
 */
class FloatingWindowService : Service() {

    companion object {
        const val EXTRA_RUNNING = "isRunning"
        private const val NOTIFICATION_ID = 9528
        private const val CHANNEL_ID = "floating-notifications"

        @Volatile
        var isShowing = false
            private set

        @Volatile
        private var instance: FloatingWindowService? = null

        /**
         * 由 Flutter 调用，同步当前抓包状态以更新悬浮窗图标。
         */
        fun updateState(isRunning: Boolean) {
            instance?.updateIcon(isRunning)
        }
    }

    private var windowManager: WindowManager? = null
    private var floatView: View? = null
    private var iconView: ImageView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var lastIsRunning = false

    // 拖动相关
    private var initialX = 0
    private var initialY = 0
    private var touchX = 0f
    private var touchY = 0f

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (floatView != null) {
            // 已显示，仅同步状态
            updateIcon(intent?.getBooleanExtra(EXTRA_RUNNING, lastIsRunning) ?: lastIsRunning)
            return START_STICKY
        }

        lastIsRunning = intent?.getBooleanExtra(EXTRA_RUNNING, false) ?: false
        startForeground(NOTIFICATION_ID, buildNotification())
        addFloatingView(lastIsRunning)
        isShowing = true
        return START_STICKY
    }

    override fun onDestroy() {
        removeFloatingView()
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (instance == this) instance = null
        super.onDestroy()
    }

    private fun addFloatingView(isRunning: Boolean) {
        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.floating_window, null)
        floatView = view
        iconView = view.findViewById(R.id.floating_icon)

        val params = WindowManager.LayoutParams(
            dp2px(56),
            dp2px(56),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp2px(24)
            y = dp2px(120)
        }
        layoutParams = params

        updateIcon(isRunning)
        setupDrag(view, params)
        setupClick(view)

        try {
            windowManager?.addView(view, params)
        } catch (e: Exception) {
            Log.w("FloatingWindow", "addView failed", e)
        }
    }

    private fun removeFloatingView() {
        isShowing = false
        floatView?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) {
                Log.w("FloatingWindow", "removeView failed", e)
            }
        }
        floatView = null
        iconView = null
    }

    private fun updateIcon(isRunning: Boolean) {
        lastIsRunning = isRunning
        iconView?.let {
            if (isRunning) {
                it.setImageResource(R.drawable.ic_floating_bubble)
                it.alpha = 1.0f
            } else {
                it.setImageResource(R.drawable.ic_floating_mono)
                it.alpha = 0.85f
            }
        }
    }

    private fun setupDrag(view: View, params: WindowManager.LayoutParams) {
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - touchX).toInt()
                    params.y = initialY + (event.rawY - touchY).toInt()
                    windowManager?.updateViewLayout(view, params)
                    true
                }
                else -> false
            }
        }
    }

    private fun setupClick(view: View) {
        view.setOnClickListener {
            // 点击回到主界面，主界面里的 Flutter 逻辑负责实际的抓包启停
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_floating_mono)
            .setContentTitle(getString(R.string.floating_notification_title))
            .setContentText(getString(R.string.floating_notification_content))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "悬浮窗服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持悬浮窗运行，防止 MCP 等后台服务被系统回收"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun dp2px(dp: Int): Int {
        return (dp * resources.displayMetrics.density + 0.5f).toInt()
    }
}
