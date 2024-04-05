import 'dart:async';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/model/task_controller.dart';
import 'package:ayaka/src/utils/debounce.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  List<Gallery> pendingTask = [];
  List<Map<String, dynamic>> runningTask = [];
  final Debounce _debounce = Debounce();
  final deration = const Duration(seconds: 2);
  late TaskController controller;
  late Hitomi api;
  bool _taskRunning = false;
  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
    api.removeCallBack(_handleDownloadMsg);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.watch<TaskController>();
    manager = controller.manager;
    api = manager.getApiDirect();
    api.registerCallBack(_handleDownloadMsg);
    manager
        .remainTask()
        .fold(<Gallery>[], (previous, element) => previous..add(element)).then(
            (value) => setState(() {
                  pendingTask = value;
                }));
  }

  Future<bool> _handleDownloadMsg(Message msg) async {
    if (!_taskRunning) {
      _taskRunning = true;
      _handleVisible();
    }
    return true;
  }

  Future<void> _fetchTasks() async {
    await manager
        .parseCommandAndRun('-l')
        .then((value) => value as Map<String, dynamic>)
        .then((result) => setState(() {
              pendingTask =
                  (result['pendingTask'] as List<Map<String, dynamic>>)
                      .map((e) => e['gallery'] as Gallery)
                      .toList();
              runningTask = result['runningTask'];
              _taskRunning = runningTask.isNotEmpty;
            }))
        .catchError((e) => showSnackBar(context, 'err $e'),
            test: (error) => true)
        .whenComplete(() => _handleVisible());
  }

  void _handleVisible() {
    if (_taskRunning) {
      _debounce.runDebounce(_fetchTasks, duration: deration);
    } else {
      _debounce.dispose();
    }
  }

  Widget _buildRunnintTaskItem(Map<String, dynamic> item) {
    Gallery gallery = item['gallery'];
    final url = api.buildImageUrl(gallery.files.first,
        id: gallery.id, size: ThumbnaiSize.smaill, proxy: true);
    var header = buildRequestHeader(url,
        'https://hitomi.la${gallery.galleryurl != null ? Uri.encodeFull(gallery.galleryurl!) : '${gallery.id}.html'}');
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
    );
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
              Text(AppLocalizations.of(context)!.pendingTask),
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
                api: api,
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
                            controller.addTask(gallery).catchError((e) {
                              debugPrint(e);
                            }, test: (error) => true)),
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
