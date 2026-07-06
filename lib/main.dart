import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF060608),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: TakNoghteApp()));
}
