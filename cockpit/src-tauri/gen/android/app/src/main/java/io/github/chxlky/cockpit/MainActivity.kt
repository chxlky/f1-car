package io.github.chxlky.cockpit

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import androidx.activity.enableEdgeToEdge

class MainActivity : TauriActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
  }

  @Suppress("unused")
  fun setScreenOrientation(orientation: String) {
    runOnUiThread {
      requestedOrientation = when (orientation) {
        "landscape" -> {
          enableImmersiveMode()
          ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
        "portrait" -> {
          disableImmersiveMode()
          ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
        else -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
      }
    }
  }

  @Suppress("unused")
  fun getCurrentOrientation(): String {
    return when (resources.configuration.orientation) {
      Configuration.ORIENTATION_LANDSCAPE -> "landscape"
      Configuration.ORIENTATION_PORTRAIT -> "portrait"
      else -> "portrait" // Default to portrait for undefined states
    }
  }

  private fun enableImmersiveMode() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      window.insetsController?.let {
        it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
        it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
      }
    } else {
      @Suppress("DEPRECATION")
      window.decorView.systemUiVisibility = (
        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
          or View.SYSTEM_UI_FLAG_FULLSCREEN
          or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        )
    }
  }

  private fun disableImmersiveMode() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      window.insetsController?.show(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
    } else {
      @Suppress("DEPRECATION")
      window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
    }
  }
}
