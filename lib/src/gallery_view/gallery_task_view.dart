import 'dart:async';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/model/task_controller.dart';
import 'package:ayaka/src/utils/debounce.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:provider/provider.dart';

import '../utils/proxy_netwrok_image.dart';

class GalleryTaskView extends StatefulWidget {
  const GalleryTaskView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _GalleryTaskView();
  }
}

class _GalleryTaskView extends State<GalleryTaskView> {
  List<Gallery> pendingTask = [];
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
    _handleVisible();
  }

  Future<void> _fetchTasks() async {
    await controller
        .listTask()
        .then((result) => setState(() {
              pendingTask =
                  (result['pendingTask'] as List<Map<String, dynamic>>)
                      .map((e) {
                return e['gallery'] is Gallery
                    ? e['gallery'] as Gallery
                    : Gallery.fromJson(e['gallery'] as String);
              }).toList();
              runningTask =
                  (result['runningTask'] as List<Map<String, dynamic>>)
                      .map((e) {
                e['gallery'] = e['gallery'] is Gallery
                    ? e['gallery'] as Gallery
                    : Gallery.fromJson(e['gallery'] as String);
                return e;
              }).toList();
            }))
        .catchError((e) {
      debugPrint(e);
      showSnackBar(context, 'err $e');
    }, test: (error) => true).whenComplete(() => _handleVisible());
  }

  void _handleVisible() {
    _debounce.runDebounce(_fetchTasks, duration: deration);
  }

  Widget _buildRunnintTaskItem(Map<String, dynamic> item) {
    Gallery gallery = item['gallery'];
    return InkWell(
        child: Row(
          key: ValueKey(gallery.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: ThumbImageView(
                    ProxyNetworkImage(gallery.id, gallery.files.first,
                        controller.controller.hitomi(localDb: false)),
                    aspectRatio: 1)),
            Expanded(
                child: Column(children: [
              Text(gallery.dirName,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
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
                          controller.cancelTask(gallery.id);
                        }),
                    PopupMenuItem(
                        child: Text(AppLocalizations.of(context)!.delete),
                        onTap: () {
                          controller.deleteTask(gallery.id);
                        }),
                  ];
                })
              ])
            ]))
          ],
        ),
        onTap: () => Navigator.of(context).pushNamed(
            GalleryDetailsView.routeName,
            arguments: {'gallery': gallery, 'local': false}));
  }

  @override
  Widget build(BuildContext context) {
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
            return _buildRunnintTaskItem(item);
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
              Text(
                  '${AppLocalizations.of(context)!.pendingTask}-${pendingTask.length}-'),
              const Expanded(child: Divider()),
            ]))
      ]),
      SliverGrid.builder(
          itemBuilder: (context, index) {
            var gallery = pendingTask[index];
            return GalleryInfo(
                gallery: gallery,
                image: gallery.files.first,
                click: (g) => Navigator.of(context).pushNamed(
                    GalleryDetailsView.routeName,
                    arguments: {'gallery': gallery, 'local': false}),
                api: controller.controller.hitomi(localDb: false),
                menus: PopupMenuButton<String>(itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                        child: Text(AppLocalizations.of(context)!.delete),
                        onTap: () => controller
                                .deleteTask(gallery.id)
                                .then((value) => setState(() {
                                      pendingTask.remove(gallery);
                                    }))
                                .catchError((e) {
                              debugPrint(e);
                            }, test: (error) => true)),
                    PopupMenuItem(
                        child: Text(AppLocalizations.of(context)!.download),
                        onTap: () =>
                            controller.addTask(gallery.id).catchError((e) {
                              debugPrint(e);
                            }, test: (error) => true)),
                  ];
                }));
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 180,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          itemCount: pendingTask.length),
    ]);
  }
}
