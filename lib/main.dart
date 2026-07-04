/// Junko Bodie Roulette Tournament — Entry Point
///
/// Initializes Supabase and launches the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:junko_bodie/config/constants.dart';
import 'package:junko_bodie/app.dart';
import 'package:junko_bodie/audio/audio_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation (common for mobile games)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling for the dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B2B1D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase — same project as the web app
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  // Initialize AudioEngine
  await soundEngine.init();

  runApp(const JunkoBodieApp());
}
