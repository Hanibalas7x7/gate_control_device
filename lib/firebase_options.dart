// File generated from google-services.json
// Project: gate-control-device

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDVKTaiJLDNZcD4Pq1bhbvVZtPUbQZnHUE',
    appId: '1:420596464288:android:6fd659860fffc776f567c5',
    messagingSenderId: '420596464288',
    projectId: 'gate-control-device',
    storageBucket: 'gate-control-device.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDVKTaiJLDNZcD4Pq1bhbvVZtPUbQZnHUE',
    appId: '1:420596464288:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '420596464288',
    projectId: 'gate-control-device',
    storageBucket: 'gate-control-device.firebasestorage.app',
    iosBundleId: 'com.example.gateControlDevice',
  );
}

