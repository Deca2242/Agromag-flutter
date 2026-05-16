import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'data/services/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Carga las variables de entorno desde assets/.env
  await dotenv.load();

  // 2. Inicializa Supabase (restaura la sesión guardada automáticamente)
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  // 3. Abre la base de datos SQLite local
  await LocalDb.instance.open();

  await initializeDateFormatting('es');

  runApp(const ProviderScope(child: AgromagApp()));
}
