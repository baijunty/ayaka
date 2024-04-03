import 'dart:async';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/model/task_controller.dart';
import 'package:ayaka/src/utils/debounce.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

class GalleryTaskView extends StatefulWidget {
  const GalleryTaskView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _GalleryTaskView();
  }
}

class _GalleryTaskView extends State<GalleryTaskView> {
  late TaskManager manager;
  List<Map<String, dynamic>> pendingTask = [];
  List<Map<String, dynamic>> runningTask = [];
  final Debounce _debounce = Debounce();
  final deration = const Duration(seconds: 2);
  late TaskController controller;
  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.watch<TaskController>();
    manager = controller.manager;
    _handleVisible();
  }

  Future<void> _fetchTasks() async {
    await manager
        .parseCommandAndRun('-l')
        .then((value) => value as Map<String, dynamic>)
        .then((result) => setState(() {
              pendingTask = result['pendingTask'];
              runningTask = result['runningTask'];
            }))
        .catchError((e) => showSnackBar(context, 'err $e'),
            test: (error) => true)
        .whenComplete(() => _handleVisible());
  }

  void _handleVisible() {
    if (!controller.emptyTask) {
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
                SizedBox(
                    height: 100,
                    width: 100,
                    child: ThumbImageView(url, header: header, aspectRatio: 1)),
                Expanded(
                    child: Column(children: [
                  Text(gallery.dirName),
                  LinearProgressIndicator(
                      value: item['current'] / gallery.files.length),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${(item['speed'] as double).toStringAsFixed(2)}KB'),
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
              mainAxisExtent: 100,
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
    ]);
  }
}
