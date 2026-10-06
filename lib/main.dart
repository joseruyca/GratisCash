import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/backend_setup_screen.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/services.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.backendConfigured) {
    runApp(const BackendSetupScreen());
    return;
  }

  if (kReleaseMode && !AppConfig.legalConfigured) {
    runApp(
      const BackendSetupScreen(
        title: 'Falta completar la información legal',
        message:
            'La build de producción está bloqueada hasta configurar titular, correo y domicilio legal reales.',
      ),
    );
    return;
  }

  await Services.init();
  runApp(const OportuApp());
}

class OportuApp extends StatelessWidget {
  const OportuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Oportu',
      debugShowCheckedModeBanner: false,
      theme: OportuTheme.light,
      routerConfig: router,
    );
  }
}
