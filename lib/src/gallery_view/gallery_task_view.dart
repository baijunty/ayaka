import 'dart:async';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/utils/debounce.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import 'gallery_item_list_view.dart';

class GalleryTaskView extends StatefulWidget {
  const GalleryTaskView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _GalleryTaskView();
  }
}

class _GalleryTaskView extends State<GalleryTaskView> {
  late TaskManager manager;
  List<Map<String, dynamic>> queryTask = [];
  List<Map<String, dynamic>> pendingTask = [];
  List<Map<String, dynamic>> runningTask = [];
  final Debounce _debounce = Debounce();
  final deration = const Duration(seconds: 2);

  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager = context.read<SettingsController>().manager;
    _debounce.runDebounce(_fetchTaasks, duration: deration);
  }

  Future<void> _fetchTaasks() async {
    await manager
        .parseCommandAndRun('-l')
        .then((value) => value as Map<String, dynamic>)
        .then((result) => setState(() {
              debugPrint('$result');
              queryTask = result['queryTask'];
              pendingTask = result['pendingTask'];
              runningTask = result['runningTask'];
            }))
        .catchError((e) => debugPrint(' $e'), test: (error) => true)
        .whenComplete(
            () => _debounce.runDebounce(_fetchTaasks, duration: deration));
  }

  @override
  Widget build(BuildContext context) {
    var api = context.read<SettingsController>().hitomi();
    return CustomScrollView(slivers: [
      SliverGrid.builder(
          itemBuilder: (context, index) {
            var item = runningTask[index];
            Gallery gallery = item['gallery'];
            return Row(
              children: [
                ThumbImageView(api, gallery, gallery.files.first,
                    indexStr: '${item['speed']}Kb'),
                Expanded(
                    child: Column(children: [
                  Text(gallery.dirName),
                  LinearProgressIndicator(
                      value: item['current'] / gallery.files.length),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${item['current']}/${gallery.files.length}'),
                    PopupMenuButton<String>(itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                            child: Text(AppLocalizations.of(context)!.cancel),
                            onTap: () =>
                                manager.downLoader.removeTask(gallery.id)),
                      ];
                    })
                  ])
                ]))
              ],
            );
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 800,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          itemCount: runningTask.length),
      SliverGrid.builder(
          itemBuilder: (context, index) {
            var item = pendingTask[index];
            Gallery gallery = item['gallery'];
            return GalleryInfo(
                gallery: gallery,
                image: gallery.files.first,
                click: (g) => Navigator.of(context).pushNamed(
                    GalleryDetailsView.routeName,
                    arguments: {'gallery': gallery, 'local': false}),
                api: api,
                menus: PopupMenuButton<String>(itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                        child: Text(AppLocalizations.of(context)!.cancel),
                        onTap: () => manager.downLoader.removeTask(gallery.id)),
                  ];
                }));
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          itemCount: pendingTask.length),
      SliverAnimatedGrid(
          itemBuilder: (context, index, animation) {
            var item = pendingTask[index];
            var label = fromString(item['type'], item['name']);
            return TextButton(
                child: Text(label.name),
                onPressed: () => Navigator.of(context).pushNamed(
                    GalleryListView.routeName,
                    arguments: {'tag': label}));
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          initialItemCount: queryTask.length),
    ]);
  }
}
