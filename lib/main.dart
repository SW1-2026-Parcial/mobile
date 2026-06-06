import 'package:flutter/material.dart';
import 'core/database/local_database.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive (base de datos local para offline-first)
  await LocalDatabase.initialize();

  runApp(const BpmClientApp());
}
