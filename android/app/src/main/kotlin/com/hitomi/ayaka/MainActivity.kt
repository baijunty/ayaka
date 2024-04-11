package com.hitomi.ayaka

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity(){
    override fun onDestroy() {
        super.onDestroy()
        System.exit(0)
    }

}
