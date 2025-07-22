package com.example.runaway

import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Configuration de la barre de statut et navigation
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Configuration Trailix spécifique si nécessaire
        // Exemple: méthodes natives futures
    }

    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(newBase)
        
        // Configuration MultiDex si nécessaire
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            androidx.multidex.MultiDex.install(this)
        }
    }
}