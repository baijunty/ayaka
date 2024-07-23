import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' show ThumbnaiSize;
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
  late PageController controller;
  late MultiImageProvider provider;
  final FocusNode focusNode = FocusNode();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _gallery = args['gallery'];
    index = args['index'] ?? 0;
    controller = PageController(initialPage: index);
    var settings = context.read<SettingsController>();
    final api = settings.hitomi(localDb: args['local']);
    provider = MultiImageProvider(
        _gallery.files.map((e) {
          return ProxyNetworkImage(
              dataStream: (chunkEvents) => api
                      .fetchImageData(
                    e,
                    id: _gallery.id,
                    size: ThumbnaiSize.origin,
                    refererUrl: 'https://hitomi.la${_gallery.urlEncode()}',
                    onProcess: (now, total) => chunkEvents.add(ImageChunkEvent(
                        cumulativeBytesLoaded: now, expectedTotalBytes: total)),
                  )
                      .fold(<int>[], (acc, l) => acc..addAll(l)),
              key: '${e.hash}_origin');
        }).toList(),
        initialIndex: index);
    controller.addListener(handlePageChange);
    if (args['index'] == null) {
      context
          .readUserDb(_gallery.id, readMask)
          .then((value) => (value ?? 0))
          .then((value) => context
              .read<SettingsController>()
              .manager
              .helper
              .delete('UserLog', {'id': _gallery.id, 'type': readMask}).then(
                  (r) => value))
          .then((value) => controller.jumpToPage(value));
    }
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
              key: GlobalObjectKey(_gallery),
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
                          onPressed: () => Navigator.of(context).pop())))),
        ]))));
  }
}
