import 'package:ayaka/src/gallery_view/gallery_tabview.dart';
import 'package:ayaka/src/gallery_view/gallery_task_view.dart';
import 'package:ayaka/src/settings/settings_view.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/ui/profile.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AyakaHome extends StatefulWidget {
  const AyakaHome({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AyakaHome();
  }
}

class _AyakaHome extends State<AyakaHome> {
  var index = 0;
  var exitApp = false;
  void _handleIndexClick(int index) {
    setState(() {
      this.index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (index) {
      case 1:
        child = const GalleryTaskView();
      case 2:
        child = const UserProfileView();
      case 3:
        child = const SettingsView();
      default:
        child = const GalleryTabView();
    }
    return PopScope(
        canPop: exitApp,
        onPopInvoked: (didPop) {
          if (!exitApp) {
            setState(() async {
              context.showSnackBar(AppLocalizations.of(context)!.exitConfirm);
              exitApp = true;
              await Future.delayed(
                  const Duration(seconds: 2),
                  () => setState(() {
                        exitApp = false;
                      }));
            });
          } else {
            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        },
        child: Scaffold(
          body: SafeArea(
              child: Center(
                  child: MaxWidthBox(
                      maxWidth: 1280,
                      child: switch (currentOrientation(context)) {
                        Orientation.portrait => child,
                        _ => Row(children: [
                            NavigationRail(
                                destinations: [
                                  NavigationRailDestination(
                                      icon: const Icon(Icons.book),
                                      label: Text(AppLocalizations.of(context)!
                                          .gallery)),
                                  NavigationRailDestination(
                                      icon: const Icon(Icons.download),
                                      label: Text(AppLocalizations.of(context)!
                                          .download)),
                                  NavigationRailDestination(
                                      icon: const Icon(Icons.person),
                                      label: Text(AppLocalizations.of(context)!
                                          .profile)),
                                  NavigationRailDestination(
                                      icon: const Icon(Icons.settings),
                                      label: Text(AppLocalizations.of(context)!
                                          .setting)),
                                ],
                                selectedIndex: index,
                                onDestinationSelected: _handleIndexClick,
                                labelType: NavigationRailLabelType.selected),
                            Expanded(child: child)
                          ])
                      }))),
          bottomNavigationBar:
              currentOrientation(context) == Orientation.portrait && !kIsWeb
                  ? BottomNavigationBar(
                      items: [
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.book),
                              label: AppLocalizations.of(context)!.gallery),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.download),
                              label: AppLocalizations.of(context)!.download),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.person),
                              label: AppLocalizations.of(context)!.profile),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.settings),
                              label: AppLocalizations.of(context)!.setting),
                        ],
                      onTap: _handleIndexClick,
                      currentIndex: index,
                      type: BottomNavigationBarType.fixed)
                  : null,
        ));
  }
}
