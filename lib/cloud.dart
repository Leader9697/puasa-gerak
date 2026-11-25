// Google login (Firebase Auth) and cloud backup of all app data (Firestore).
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'data.dart';
import 'firebase_options.dart';

class Cloud {
  static bool ready = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static User? get user => ready ? FirebaseAuth.instance.currentUser : null;

  static Future<User?> signIn() async {
    final p = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    final c = await FirebaseAuth.instance.signInWithProvider(p);
    return c.user;
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore.instance.collection('users').doc(uid);

  /// Returns the stored data and its timestamp, or null when nothing is stored yet.
  static Future<(AppData, int)?> pull(String uid) async {
    final snap = await _doc(uid).get(const GetOptions(source: Source.server));
    final m = snap.data();
    if (m == null || m['json'] is! String) return null;
    final d = AppData.from(jsonDecode(m['json'] as String));
    return (d, (m['updatedAt'] as num?)?.toInt() ?? d.updatedAt);
  }

  static Future<void> push(String uid, AppData d) async {
    await _doc(uid).set({
      'json': jsonEncode(d.toJson()),
      'updatedAt': d.updatedAt,
      'savedAt': FieldValue.serverTimestamp(),
      'app': 'android',
    });
  }
}
