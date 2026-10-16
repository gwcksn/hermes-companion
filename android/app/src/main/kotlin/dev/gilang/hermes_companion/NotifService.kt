package dev.gilang.hermes_companion

import android.app.Notification
import android.content.pm.PackageManager
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/// Forwards posted/removed phone notifications to Flutter for the
/// Notifications tab. Filtering of ongoing/system noise happens in Dart
/// so it stays unit-testable; this service only serializes raw fields.
class NotifService : NotificationListenerService() {
  companion object {
    var instance: NotifService? = null
      private set

    var eventSink: EventChannel.EventSink? = null
    private val pending = mutableListOf<Map<String, Any?>>()

    fun emit(event: Map<String, Any?>) {
      val sink = eventSink
      if (sink == null) {
        pending.add(event)
        if (pending.size > 100) pending.removeAt(0)
      } else {
        sink.success(event)
      }
    }

    fun drain() {
      val sink = eventSink ?: return
      for (e in pending) sink.success(e)
      pending.clear()
    }

    fun toMap(sbn: StatusBarNotification, pm: PackageManager): Map<String, Any?> {
      val extras: Bundle? = sbn.notification.extras
      val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        ?: extras?.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
        ?: ""
      val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        ?: extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        ?: extras?.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()
        ?: ""
      val flags = sbn.notification.flags
      val ongoing = (flags and Notification.FLAG_ONGOING_EVENT) != 0
      val appName = try {
        pm.getApplicationLabel(pm.getApplicationInfo(sbn.packageName, 0)).toString()
      } catch (_: Exception) {
        sbn.packageName
      }
      return mapOf(
        "key" to sbn.key,
        "packageName" to sbn.packageName,
        "appName" to appName,
        "title" to title,
        "text" to text,
        "whenMs" to sbn.postTime,
        "ongoing" to ongoing,
        "clearable" to sbn.isClearable,
        "groupSummary" to ((flags and Notification.FLAG_GROUP_SUMMARY) != 0),
      )
    }
  }

  override fun onListenerConnected() {
    instance = this
    drain()
    // Push a full sync so Flutter starts from the current shade state.
    try {
      val pm = packageManager
      emit(
        mapOf(
          "type" to "sync",
          "notifications" to activeNotifications.map { toMap(it, pm) },
        ),
      )
    } catch (_: Exception) {
    }
  }

  override fun onListenerDisconnected() {
    if (instance === this) instance = null
  }

  override fun onNotificationPosted(sbn: StatusBarNotification) {
    instance = this
    try {
      emit(mapOf("type" to "posted", "notification" to toMap(sbn, packageManager)))
    } catch (_: Exception) {
    }
  }

  override fun onNotificationRemoved(sbn: StatusBarNotification) {
    try {
      emit(mapOf("type" to "removed", "key" to sbn.key))
    } catch (_: Exception) {
    }
  }
}
