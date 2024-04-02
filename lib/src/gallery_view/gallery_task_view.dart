import 'dart:async';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/utils/debounce.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
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
  var _visible = true;
  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager = context.read<SettingsController>().manager;
  }

  Future<void> _fetchTasks() async {
    await manager
        .parseCommandAndRun('-l')
        .then((value) => value as Map<String, dynamic>)
        .then((result) => setState(() {
              queryTask = result['queryTask'];
              pendingTask = result['pendingTask'];
              runningTask = result['runningTask'];
            }))
        .catchError((e) => showSnackBar(context, 'err $e'),
            test: (error) => true)
        .whenComplete(() => _handleVisible(_visible));
  }

  void _handleVisible(bool visible) {
    _visible = visible;
    if (visible) {
      _debounce.runDebounce(_fetchTasks, duration: deration);
    } else {
      _debounce.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    var controller = context.read<SettingsController>();
    var api = controller.hitomi();
    return CustomScrollView(slivers: [
      SliverList.list(children: [
        Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(children: [
              const Expanded(child: Divider()),
              Text(AppLocalizations.of(context)!.runningTask),
              const Expanded(child: Divider()),
            ]))
      ]),
      SliverGrid.builder(
          itemBuilder: (context, index) {
            var item = runningTask[index];
            Gallery gallery = item['gallery'];
            final url = api.buildImageUrl(gallery.files.first,
                id: gallery.id, size: ThumbnaiSize.smaill, proxy: true);
            var header = buildRequestHeader(
                url, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}');
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThumbImageView(url, header: header),
                Expanded(
                    child: Column(children: [
                  Text(gallery.dirName),
                  LinearProgressIndicator(
                      value: item['current'] / gallery.files.length),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text((item['speed'] as double).toStringAsFixed(2)),
                    const SizedBox(width: 8),
                    Text('${item['current']}/${gallery.files.length}'),
                    PopupMenuButton<String>(itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                            child: Text(AppLocalizations.of(context)!.cancel),
                            onTap: () {
                              manager.downLoader
                                  .removeTask(gallery.id)
                                  .catchError((e) {
                                showSnackBar(context, 'err $e');
                                return false;
                              }, test: (error) => true);
                            }),
                      ];
                    })
                  ])
                ]))
              ],
            );
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 200,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8),
          itemCount: runningTask.length),
      SliverList.list(children: [
        Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(children: [
              const Expanded(child: Divider()),
              Text(AppLocalizations.of(context)!.pendingTask),
              const Expanded(child: Divider()),
            ]))
      ]),
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
              maxCrossAxisExtent: 400,
              mainAxisExtent: 200,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          itemCount: pendingTask.length),
      SliverList.list(children: [
        Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(children: [
              const Expanded(child: Divider()),
              Text(AppLocalizations.of(context)!.queryTask),
              const Expanded(child: Divider()),
            ]))
      ]),
      SliverAnimatedGrid(
          itemBuilder: (context, index, animation) {
            var item = pendingTask[index];
            var label = fromString(item['type'], item['name']);
            return TextButton(
                child: Text(label.name),
                onPressed: () => Navigator.of(context).pushNamed(
                    GalleryListView.routeName,
                    arguments: {'tag': label.toMap()}));
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisExtent: 40,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          initialItemCount: queryTask.length),
    ]);
  }
}
