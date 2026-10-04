package com.ecoxchange.ecoxchange_mobile

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells the Route page whether a Google Maps key was built into the
        // manifest (MAPS_API_KEY in android/local.properties), so it never
        // creates a map view the Maps SDK would reject. Only a yes/no leaves
        // native code — never the key itself.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ecoxchange/config").setMethodCallHandler { call, result ->
            if (call.method == "hasMapsApiKey") {
                val key = try {
                    packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                        .metaData?.getString("com.google.android.geo.API_KEY")
                } catch (e: Exception) {
                    null
                }
                result.success(!key.isNullOrBlank())
            } else {
                result.notImplemented()
            }
        }
    }
}
