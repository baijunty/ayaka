import 'package:ayaka/src/gallery_view/gallery_item_list_view.dart';
import 'package:ayaka/src/gallery_view/gallery_similar_view.dart';
import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'gallery_view/gallery_details_view.dart';
import 'gallery_view/gallery_search_result.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = context.watch<SettingsController>();
    return FutureBuilder(
        future: settingsController.loadConfig().then((value) =>
            Future.delayed(const Duration(milliseconds: 2000), () => true)),
        builder: (context, snap) {
          debugPrint('load result ${snap.data}');
          if (snap.hasData) {
            return ListenableBuilder(
              listenable: settingsController,
              builder: (BuildContext context, Widget? child) {
                return MaterialApp(
                  restorationScopeId: 'app',
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  debugShowCheckedModeBanner: false,
                  supportedLocales: const [
                    Locale('zh', 'CN'),
                  ],
                  onGenerateTitle: (BuildContext context) =>
                      AppLocalizations.of(context)!.appTitle,
                  theme: ThemeData(
                      useMaterial3: true,
                      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                      elevatedButtonTheme: const ElevatedButtonThemeData()),
                  darkTheme: ThemeData.dark(useMaterial3: true),
                  themeMode: settingsController.themeMode,
                  onGenerateRoute: (RouteSettings routeSettings) {
                    return MaterialPageRoute<void>(
                      settings: routeSettings,
                      builder: (BuildContext context) {
                        return _buildRoute(
                            routeSettings.name ?? '/', settingsController);
                      },
                    );
                  },
                );
              },
            );
          } else {
            debugPrint('${snap.error}');
            return const Center(child: CircularProgressIndicator());
          }
        });
  }

  Widget _buildRoute(String route, SettingsController controller) {
    switch (route) {
      case GalleryViewer.routeName:
        return const GalleryViewer();
      case GallerySearchResultView.routeName:
        return const GallerySearchResultView();
      case SettingsView.routeName:
        return const SettingsView();
      case GalleryDetailsView.routeName:
        return const GalleryDetailsView();
      case GallerySimilaerView.routeName:
        return const GallerySimilaerView();
      case GalleryListView.routeName:
        return const GalleryListView();
      default:
        return const AyakaHome();
    }
  }
}
