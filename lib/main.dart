import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF060608),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // The app must start no matter what — notification setup happens lazily in
  // the first screen's bootstrap and is fully guarded, so a missing icon or a
  // denied permission can never blank-screen startup (it did on Android 11 /
  // Mali: an unhandled invalid_icon before runApp killed the whole app).
  runApp(const ProviderScope(child: TakNoghteApp()));
}
