package dev.gilang.hermes_companion

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.util.Base64
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
  private val methodName = "hermes/notifications"
  private val eventName = "hermes/notifications_events"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventName).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(args: Any?, events: EventChannel.EventSink) {
          NotifService.eventSink = events
          NotifService.drain()
        }

        override fun onCancel(args: Any?) {
          NotifService.eventSink = null
        }
      },
    )

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodName).setMethodCallHandler { call, result ->
      when (call.method) {
        "hasPermission" -> result.success(hasPermission())
        "openSettings" -> {
          try {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            result.success(true)
          } catch (e: Exception) {
            result.error("no-settings", e.message, null)
          }
        }
        "getActive" -> {
          if (!hasPermission()) {
            result.success(emptyList<Map<String, Any?>>())
            return@setMethodCallHandler
          }
          val svc = NotifService.instance
          if (svc == null) {
            result.success(emptyList<Map<String, Any?>>())
            return@setMethodCallHandler
          }
          try {
            val pm = packageManager
            result.success(svc.activeNotifications.map { NotifService.toMap(it, pm) })
          } catch (e: Exception) {
            result.error("active-failed", e.message, null)
          }
        }
        "openApp" -> {
          val pkg = call.argument<String>("packageName")
          if (pkg == null) {
            result.error("bad-arg", "missing packageName", null)
            return@setMethodCallHandler
          }
          try {
            val intent = packageManager.getLaunchIntentForPackage(pkg)
            if (intent == null) {
              result.error("no-launch", "no launch intent for $pkg", null)
              return@setMethodCallHandler
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
          } catch (e: Exception) {
            result.error("open-failed", e.message, null)
          }
        }
        "cancel" -> {
          val key = call.argument<String>("key")
          try {
            if (key != null) NotifService.instance?.cancelNotification(key)
            result.success(true)
          } catch (e: Exception) {
            result.error("cancel-failed", e.message, null)
          }
        }
        "cancelAll" -> {
          try {
            NotifService.instance?.cancelAllNotifications()
            result.success(true)
          } catch (e: Exception) {
            result.error("cancel-all-failed", e.message, null)
          }
        }
        "getIcon" -> {
          val pkg = call.argument<String>("packageName")
          if (pkg == null) {
            result.success(null)
            return@setMethodCallHandler
          }
          try {
            result.success(appIconBase64(pkg))
          } catch (e: Exception) {
            result.error("icon-failed", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun hasPermission(): Boolean {
    val enabled = NotificationManagerCompat.getEnabledListenerPackages(this)
    return enabled.contains(packageName)
  }

  private fun appIconBase64(pkg: String): String? {
    val drawable = try {
      packageManager.getApplicationIcon(pkg)
    } catch (_: Exception) {
      return null
    }
    val bitmap = drawableToBitmap(drawable, 96) ?: return null
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
  }

  // Always render the full drawable (adaptive icons keep their background
  // layer) into a fixed-size bitmap so the channel payload stays small.
  private fun drawableToBitmap(drawable: Drawable, sizePx: Int): Bitmap? {
    return try {
      val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bmp)
      drawable.setBounds(0, 0, sizePx, sizePx)
      drawable.draw(canvas)
      bmp
    } catch (_: Exception) {
      null
    }
  }
}
