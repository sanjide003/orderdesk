import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB1kRoi4e2zgFnJ8GSdoHYDCg6plsiSX1Q',
    appId: '1:740400697832:web:50cd3ddc04caf6e859945d',
    messagingSenderId: '740400697832',
    projectId: 'order-desk-wapp',
    authDomain: 'order-desk-wapp.firebaseapp.com',
    storageBucket: 'order-desk-wapp.firebasestorage.app',
    measurementId: 'G-DZ4K6VB1RN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCxHYaVAVQJWXkjQRoNRYVm_NpMNCyEuOc',
    appId: '1:740400697832:android:18e66f7b7f02038559945d',
    messagingSenderId: '740400697832',
    projectId: 'order-desk-wapp',
    storageBucket: 'order-desk-wapp.firebasestorage.app',
  );
}
