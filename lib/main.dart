import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/app_logger.dart';
import 'services/hotspot_service.dart';
import 'services/store_service.dart';
import 'services/subscription_service.dart';
import 'services/vpn_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF101627),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final store = await StoreService.init();

  runApp(
    AuraApp(
      appState: AppState(
        store: store,
        vpn: VpnService(),
        subscriptions: SubscriptionService(),
        hotspot: HotspotService(),
        logger: AppLogger(),
      ),
    ),
  );
}
