import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' show ThumbnaiSize;
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../utils/proxy_network_image.dart';

class GalleryViewer extends StatefulWidget {
  const GalleryViewer({super.key});

  static const routeName = '/gallery_viewer';
  @override
  State<StatefulWidget> createState() {
    return _GalleryViewer();
  }
}

class _GalleryViewer extends State<GalleryViewer>
    with SingleTickerProviderStateMixin {
  late Gallery _gallery;
  var index = 0;
  var showAppBar = false;
  var extension = false;
  var translate = false;
  var lang = 'ja';
  late PageController controller;
  late MultiImageProvider provider;
  late Hitomi api;
  final FocusNode focusNode = FocusNode();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    if (index == 0) {
      index = args['index'] ?? 0;
      _gallery = args['gallery'];
      var settings = context.read<SettingsController>();
      extension = settings.exntension;
      api = settings.hitomi(localDb: args['local']);
      if (args['index'] == null) {
        context
            .readUserDb(_gallery.id, readMask)
            .then((value) => (value ?? 0))
            .then((value) => mounted
                ? context.read<SettingsController>().manager.helper.delete(
                    'UserLog',
                    {'id': _gallery.id, 'type': readMask}).then((r) => value)
                : Future.value(value))
            .then((value) => controller.jumpToPage(value));
      }
      lang = _gallery.language == 'english' ? 'en' : lang;
      buildProvider();
    }
  }

  void buildProvider() {
    controller = PageController(initialPage: index);
    controller.addListener(handlePageChange);
    provider = MultiImageProvider(
        _gallery.files.map((e) {
          return ProxyNetworkImage(
              dataStream: (chunkEvents) => api
                      .fetchImageData(
                    e,
                    id: _gallery.id,
                    size: ThumbnaiSize.origin,
                    refererUrl: 'https://hitomi.la${_gallery.urlEncode()}',
                    lang: lang,
                    translate: translate,
                    onProcess: (now, total) => chunkEvents.add(ImageChunkEvent(
                        cumulativeBytesLoaded: now, expectedTotalBytes: total)),
                  )
                      .fold(<int>[], (acc, l) => acc..addAll(l)),
              key: '${e.hash}:${translate}_origin');
        }).toList(),
        initialIndex: index);
  }

  void handlePageChange() async {
    if (controller.page! - controller.page!.toInt() == 0) {
      index = controller.page!.toInt();
      await context.insertToUserDb(_gallery.id, readMask,
          data: index, content: _gallery.name);
      if (index == _gallery.files.length - 1 && mounted) {
        await context
            .getSqliteHelper()
            .delete('UserLog', {'id': _gallery.id, 'type': lateReadMark});
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (value) {
          if (value.physicalKey == PhysicalKeyboardKey.arrowLeft && index > 0) {
            setState(() {
              controller.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut);
            });
          } else if (value.physicalKey == PhysicalKeyboardKey.arrowRight &&
              index < _gallery.files.length - 1) {
            setState(() {
              controller.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut);
            });
          }
        },
        child: Scaffold(
            body: SafeArea(
                child: Stack(children: [
          SizedBox.expand(
              child: Center(
                  child: GestureDetector(
                      child: EasyImageViewPager(
                          easyImageProvider: provider,
                          doubleTapZoomable: true,
                          pageController: controller),
                      onTap: () => setState(() {
                            showAppBar = !showAppBar;
                          })))),
          AnimatedPadding(
              key: GlobalObjectKey(_gallery.id),
              duration: const Duration(milliseconds: 250),
              padding: showAppBar
                  ? const EdgeInsets.only(left: 0)
                  : EdgeInsets.only(left: MediaQuery.of(context).size.width),
              curve: Curves.easeInOut,
              child: SizedBox(
                  height: 56,
                  child: AppBar(
                      title: Column(children: [
                        Text(
                            '${_gallery.name}-${index + 1}/${_gallery.files.length}'),
                        Slider(
                          value: index.toDouble(),
                          max: (_gallery.files.length - 1).toDouble(),
                          divisions: _gallery.files.length - 1,
                          label: index.toString(),
                          onChanged: (double value) {
                            setState(() {
                              index = value.floor();
                              controller.animateToPage(index,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut);
                            });
                          },
                        )
                      ]),
                      backgroundColor: Theme.of(context).primaryColor,
                      leading: BackButton(
                          onPressed: () => Navigator.of(context).pop()),
                      actions: (extension
                          ? [
                              IconButton(
                                  onPressed: () => setState(() {
                                        translate = !translate;
                                        controller
                                            .removeListener(handlePageChange);
                                        buildProvider();
                                      }),
                                  icon: Icon(translate
                                      ? Icons.translate_sharp
                                      : Icons.g_translate))
                            ]
                          : null)))),
        ]))));
  }
}
