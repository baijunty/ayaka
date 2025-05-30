import 'package:ayaka/src/gallery_view/gallery_tabview.dart';
import 'package:ayaka/src/gallery_view/gallery_task_view.dart';
import 'package:ayaka/src/settings/settings_view.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/ui/profile.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayaka/src/localization/app_localizations.dart';

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

  Widget navigationBar(bool portrait) {
    if (portrait) {
      if (kIsWeb) {
        return BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                  icon: const Icon(Icons.book),
                  label: AppLocalizations.of(context)!.gallery),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.person),
                  label: AppLocalizations.of(context)!.profile),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.setting),
            ],
            onTap: _handleIndexClick,
            currentIndex: index,
            type: BottomNavigationBarType.fixed);
      }
      return BottomNavigationBar(
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
          type: BottomNavigationBarType.fixed);
    } else {
      if (kIsWeb) {
        return NavigationRail(
            destinations: [
              NavigationRailDestination(
                  icon: const Icon(Icons.book),
                  label: Text(AppLocalizations.of(context)!.gallery)),
              NavigationRailDestination(
                  icon: const Icon(Icons.person),
                  label: Text(AppLocalizations.of(context)!.profile)),
              NavigationRailDestination(
                  icon: const Icon(Icons.settings),
                  label: Text(AppLocalizations.of(context)!.setting))
            ],
            selectedIndex: index,
            onDestinationSelected: _handleIndexClick,
            labelType: NavigationRailLabelType.selected);
      }
      return NavigationRail(
          destinations: [
            NavigationRailDestination(
                icon: const Icon(Icons.book),
                label: Text(AppLocalizations.of(context)!.gallery)),
            NavigationRailDestination(
                icon: const Icon(Icons.download),
                label: Text(AppLocalizations.of(context)!.download)),
            NavigationRailDestination(
                icon: const Icon(Icons.person),
                label: Text(AppLocalizations.of(context)!.profile)),
            NavigationRailDestination(
                icon: const Icon(Icons.settings),
                label: Text(AppLocalizations.of(context)!.setting)),
          ],
          selectedIndex: index,
          onDestinationSelected: _handleIndexClick,
          labelType: NavigationRailLabelType.selected);
    }
  }

  Widget currentView() {
    if (kIsWeb) {
      return IndexedStack(
          index: index,
          children: [GalleryTabView(), UserProfileView(), SettingsView()]);
    }
    Widget child;
    switch (index) {
      case 1:
        child = const IndexedStack(
            index: 1, children: [GalleryTabView(), GalleryTaskView()]);
      case 2:
        child = const IndexedStack(
            index: 1, children: [GalleryTabView(), UserProfileView()]);
      case 3:
        child = const IndexedStack(
            index: 1, children: [GalleryTabView(), SettingsView()]);
      default:
        child = const IndexedStack(
            index: 0, children: [GalleryTabView(), SettingsView()]);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    var child = currentView();
    return PopScope(
        canPop: exitApp,
        onPopInvokedWithResult: (didPop, _) {
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
                      child: switch (context.currentOrientation()) {
                        Orientation.portrait => child,
                        _ => Row(children: [
                            navigationBar(false),
                            Expanded(child: child)
                          ])
                      }))),
          bottomNavigationBar:
              context.currentOrientation() == Orientation.portrait
                  ? navigationBar(true)
                  : null,
        ));
  }
}
