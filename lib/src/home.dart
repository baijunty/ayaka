import 'package:ayaka/src/gallery_view/gallery_item_list_view.dart';
import 'package:ayaka/src/gallery_view/gallery_task_view.dart';
import 'package:ayaka/src/settings/settings_view.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'gallery_view/gallery_search.dart';

class AyakaHome extends StatefulWidget {
  const AyakaHome({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AyakaHome();
  }
}

class _AyakaHome extends State<AyakaHome> {
  var index = 0;

  void _handleIndexClick(int index) {
    setState(() {
      this.index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    var content = switch (index) {
      0 => Column(children: [
          const GallerySearch(localDb: false),
          Expanded(child: GalleryListView(key: ValueKey(index)))
        ]),
      1 => Column(children: [
          const GallerySearch(localDb: true),
          Expanded(child: GalleryListView(key: ValueKey(index), localDb: true))
        ]),
      2 => const GalleryTaskView(),
      3 => const SettingsView(),
      _ => throw UnsupportedError('')
    };
    return Scaffold(
      body: SafeArea(
          child: switch (currentOrientation(context)) {
        Orientation.portrait => content,
        _ => Row(children: [
            NavigationRail(
                destinations: [
                  NavigationRailDestination(
                      icon: const Icon(Icons.home),
                      label: Text(AppLocalizations.of(context)!.network)),
                  NavigationRailDestination(
                      icon: const Icon(Icons.local_library),
                      label: Text(AppLocalizations.of(context)!.local)),
                  NavigationRailDestination(
                      icon: const Icon(Icons.download),
                      label: Text(AppLocalizations.of(context)!.download)),
                  NavigationRailDestination(
                      icon: const Icon(Icons.settings),
                      label: Text(AppLocalizations.of(context)!.setting)),
                ],
                selectedIndex: index,
                onDestinationSelected: _handleIndexClick,
                labelType: NavigationRailLabelType.selected),
            Expanded(child: content)
          ])
      }),
      bottomNavigationBar: currentOrientation(context) == Orientation.portrait
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
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              type: BottomNavigationBarType.fixed)
          : null,
    );
  }
}
