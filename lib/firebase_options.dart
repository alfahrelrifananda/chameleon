// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCPjm_3n-9nLxwMXoOcbZxkNsI9c6XGd1Q',
    appId: '1:33959252425:web:f343ea92758730e8f65818',
    messagingSenderId: '33959252425',
    projectId: 'gallery25-a1678',
    authDomain: 'gallery25-a1678.firebaseapp.com',
    databaseURL: 'https://gallery25-a1678-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'gallery25-a1678.appspot.com',
    measurementId: 'G-Y4LNQ9ZRF7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCNt7v8p7SPObNDeRSHejBRpr1KxlSqtKw',
    appId: '1:33959252425:android:26722da978b41852f65818',
    messagingSenderId: '33959252425',
    projectId: 'gallery25-a1678',
    databaseURL: 'https://gallery25-a1678-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'gallery25-a1678.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA9RzSD8PF6c3lbu1eRwrEBvn3h1xQ0GjE',
    appId: '1:33959252425:ios:e7f819a8190bfe6bf65818',
    messagingSenderId: '33959252425',
    projectId: 'gallery25-a1678',
    databaseURL: 'https://gallery25-a1678-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'gallery25-a1678.appspot.com',
    androidClientId: '33959252425-001brf601tt4e9hdqcdmt7m2el86cco9.apps.googleusercontent.com',
    iosClientId: '33959252425-rb4fbj89mp26lihiglnosmb1v0akt0go.apps.googleusercontent.com',
    iosBundleId: 'com.example.gnoo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA9RzSD8PF6c3lbu1eRwrEBvn3h1xQ0GjE',
    appId: '1:33959252425:ios:e7f819a8190bfe6bf65818',
    messagingSenderId: '33959252425',
    projectId: 'gallery25-a1678',
    databaseURL: 'https://gallery25-a1678-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'gallery25-a1678.appspot.com',
    androidClientId: '33959252425-001brf601tt4e9hdqcdmt7m2el86cco9.apps.googleusercontent.com',
    iosClientId: '33959252425-rb4fbj89mp26lihiglnosmb1v0akt0go.apps.googleusercontent.com',
    iosBundleId: 'com.example.gnoo',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCPjm_3n-9nLxwMXoOcbZxkNsI9c6XGd1Q',
    appId: '1:33959252425:web:75908040a37f1394f65818',
    messagingSenderId: '33959252425',
    projectId: 'gallery25-a1678',
    authDomain: 'gallery25-a1678.firebaseapp.com',
    databaseURL: 'https://gallery25-a1678-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'gallery25-a1678.appspot.com',
    measurementId: 'G-29MWPRMD6V',
  );
}
