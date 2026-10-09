import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_screen.dart';
import 'state/app_state.dart';

class AuraApp extends StatelessWidget {
  const AuraApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Aura VPN',
          debugShowCheckedModeBanner: false,
          theme: AuraTheme.dark,
          locale: appState.locale,
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppStateScope(
            state: appState,
            child: appState.onboardingDone
                ? const RootScreen()
                : OnboardingScreen(onDone: appState.completeOnboarding),
          ),
        );
      },
    );
  }
}

/// Наследник для доступа к AppState из дерева.
class AppStateScope extends InheritedWidget {
  const AppStateScope({
    super.key,
    required this.state,
    required super.child,
  });

  final AppState state;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(AppStateScope oldWidget) => oldWidget.state != state;
}
