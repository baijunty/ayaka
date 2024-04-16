import 'package:ayaka/src/gallery_view/gallery_item_list_view.dart';
import 'package:ayaka/src/gallery_view/gallery_task_view.dart';
import 'package:ayaka/src/settings/settings_view.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AyakaHome extends StatefulWidget {
  final content = const [
    GalleryItemListView(),
    GalleryItemListView(localDb: true),
    GalleryTaskView(),
    SettingsView()
  ];
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
    return PopScope(
        canPop: exitApp,
        onPopInvoked: (didPop) {
          if (!exitApp) {
            setState(() async {
              showSnackBar(context, AppLocalizations.of(context)!.exitConfirm);
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
                      child: kIsWeb
                          ? const GalleryItemListView(localDb: true)
                          : switch (currentOrientation(context)) {
                              Orientation.portrait => IndexedStack(
                                  index: index, children: widget.content),
                              _ => Row(children: [
                                  NavigationRail(
                                      destinations: [
                                        NavigationRailDestination(
                                            icon: const Icon(Icons.home),
                                            label: Text(
                                                AppLocalizations.of(context)!
                                                    .network)),
                                        NavigationRailDestination(
                                            icon:
                                                const Icon(Icons.local_library),
                                            label: Text(
                                                AppLocalizations.of(context)!
                                                    .local)),
                                        NavigationRailDestination(
                                            icon: const Icon(Icons.download),
                                            label: Text(
                                                AppLocalizations.of(context)!
                                                    .download)),
                                        NavigationRailDestination(
                                            icon: const Icon(Icons.settings),
                                            label: Text(
                                                AppLocalizations.of(context)!
                                                    .setting)),
                                      ],
                                      selectedIndex: index,
                                      onDestinationSelected: _handleIndexClick,
                                      labelType:
                                          NavigationRailLabelType.selected),
                                  Expanded(
                                      child: IndexedStack(
                                          index: index,
                                          children: widget.content))
                                ])
                            }))),
          bottomNavigationBar:
              currentOrientation(context) == Orientation.portrait && !kIsWeb
                  ? BottomNavigationBar(
                      items: [
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.home),
                              label: AppLocalizations.of(context)!.network),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.local_library),
                              label: AppLocalizations.of(context)!.local),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.download),
                              label: AppLocalizations.of(context)!.download),
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
