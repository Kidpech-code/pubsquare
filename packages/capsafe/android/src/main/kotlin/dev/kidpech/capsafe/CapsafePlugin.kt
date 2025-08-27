package dev.kidpech.capsafe

import android.app.Activity
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CapsafePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var activity: Activity? = null

  private var eventSink: EventChannel.EventSink? = null
  private var secureRefCount = 0

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(binding.binaryMessenger, "capsafe/methods")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(binding.binaryMessenger, "capsafe/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "android.setSecure" -> {
        val enable = call.arguments as? Boolean ?: false
        setSecure(enable)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun setSecure(enable: Boolean) {
    val win = activity?.window ?: return
    if (enable) {
      secureRefCount++
      if (secureRefCount == 1) {
        win.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
      }
    } else {
      secureRefCount = (secureRefCount - 1).coerceAtLeast(0)
      if (secureRefCount == 0) {
        win.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
      }
    }
  }

  // ActivityAware
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }
  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }
  override fun onDetachedFromActivity() {
    activity = null
  }

  // Events (Android no-op)
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
  override fun onCancel(arguments: Any?) { eventSink = null }
}
