import 'dart:async';
import 'dart:convert';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/model/gallery_manager.dart';
import 'package:ayaka/src/utils/debounce.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/proxy_network_image.dart';

class GalleryTaskView extends StatefulWidget {
  static const routeName = '/gallery_task';
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
  late GalleryManager controller;
  WebSocketChannel? _channel;
  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
    controller.controller.manager.removeTaskObserver(setTaskResult);
    _channel?.sink.close();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.watch<GalleryManager>();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    if (controller.controller.remoteLib) {
      var uri = Uri.parse(controller.controller.config.remoteHttp);
      var socketUri = 'ws://${uri.host}:${uri.port}';
      debugPrint('socketUri:$socketUri');
      _channel = WebSocketChannel.connect(Uri.parse(socketUri));
      _channel!.sink.add('list');
      _channel!.stream.listen((d) => setTaskResult(json.decoder.convert(d)));
    } else {
      controller.controller.manager.addTaskObserver(setTaskResult);
    }
  }

  void setTaskResult(Map<String, dynamic> result) {
    setState(() {
      pendingTask = (result['pendingTask'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map((e) {
        return e['gallery'] is Gallery
            ? e['gallery'] as Gallery
            : Gallery.fromJson(e['gallery'] as String);
      }).toList();
      runningTask = (result['runningTask'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map((e) {
        e['gallery'] = e['gallery'] is Gallery
            ? e['gallery'] as Gallery
            : Gallery.fromJson(e['gallery'] as String);
        return e;
      }).toList();
    });
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
                    CacheImage(
                        manager: context.getCacheManager(local: true),
                        image: gallery.files.first,
                        refererUrl: 'https://hitomi.la${gallery.urlEncode()}',
                        id: gallery.id.toString()),
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

  Widget _taskContent() {
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
              maxCrossAxisExtent: 500,
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
                click: (g) => Navigator.of(context).pushNamed(
                    GalleryDetailsView.routeName,
                    arguments: {'gallery': gallery, 'local': false}),
                manager: context.getCacheManager(),
                menus: PopupMenuButton<String>(itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                        child: Text(AppLocalizations.of(context)!.delete),
                        onTap: () => context.deleteTask(gallery.id)),
                    PopupMenuItem(
                        child: Text(AppLocalizations.of(context)!.download),
                        onTap: () => context.addTask(gallery.id)),
                  ];
                }));
          },
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 550,
              mainAxisExtent: 180,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8),
          itemCount: pendingTask.length),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _taskContent()));
  }
}
