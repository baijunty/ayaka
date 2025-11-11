import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart'
    show MultiImageProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' show ThumbnaiSize;
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../utils/proxy_network_image.dart';
import '../ui/pager_view.dart';

class GalleryViewer extends StatefulWidget {
  const GalleryViewer({super.key});

  static const routeName = '/gallery_viewer';
  @override
  State<StatefulWidget> createState() {
    return _GalleryViewer();
  }
}

class LoadingMultiImageProvider extends MultiImageProvider {
  LoadingMultiImageProvider(super.imageProviders, {super.initialIndex});

  Widget loadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    return loadingProgress == null
        ? child
        : Center(
            child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null));
  }

  Widget errorBuilder(
      BuildContext context, Object? error, StackTrace? stackTrace) {
    return const Icon(Icons.error);
  }

  Widget frameBuilder(BuildContext context, Widget child, int? frame,
      bool wasSynchronouslyLoaded) {
    if (wasSynchronouslyLoaded) {
      return child;
    }
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(seconds: 1),
      curve: Curves.easeOut,
      child: child,
    );
  }

  @override
  Widget imageWidgetBuilder(BuildContext context, int index) {
    return Image(
      image: imageBuilder(context, index),
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      frameBuilder: frameBuilder,
    );
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
      extension = settings.exntension &&
          !settings.config.languages.contains(_gallery.language);
      api = settings.hitomi(
          type: args['local'] == false
              ? HitomiType.Remote
              : settings.remoteLib
                  ? HitomiType.PROXY
                  : HitomiType.Local);
      if (args['index'] == null) {
        context
            .readUserDb(_gallery.id, readHistoryMask)
            .then((value) => (value ?? 0))
            .then((value) => mounted
                ? context.read<SettingsController>().manager.helper.delete(
                    'UserLog', {
                    'id': _gallery.id,
                    'type': readHistoryMask
                  }).then((r) => value)
                : Future.value(value))
            .then((value) => controller.jumpToPage(value));
      }
      lang = ['english', 'korean'].contains(_gallery.language)
          ? _gallery.language!.substring(0, 2)
          : lang;
      buildProvider();
    }
  }

  void buildProvider() {
    controller = PageController(initialPage: index);
    controller.addListener(handlePageChange);
    provider = LoadingMultiImageProvider(
        _gallery.files.map((e) {
          return ProxyNetworkImage(
              dataStream: (chunkEvents) {
                chunkEvents.add(const ImageChunkEvent(
                    cumulativeBytesLoaded: 0, expectedTotalBytes: null));
                return api
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
                    .fold(<int>[], (acc, l) => acc..addAll(l));
              },
              key: '${e.hash}:${translate}_origin');
        }).toList(),
        initialIndex: index);
  }

  void handlePageChange() async {
    if (controller.page! - controller.page!.toInt() == 0) {
      index = controller.page!.toInt();
      await context.insertToUserDb(_gallery.id, readHistoryMask,
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
    focusNode.requestFocus();
    return Focus(
        focusNode: focusNode,
        onKeyEvent: (f, value) {
          if (value.physicalKey == PhysicalKeyboardKey.arrowLeft &&
              value is KeyUpEvent &&
              index > 0) {
            setState(() {
              controller.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut);
            });
            return KeyEventResult.handled;
          } else if (value.physicalKey == PhysicalKeyboardKey.arrowRight &&
              value is KeyUpEvent &&
              index < _gallery.files.length - 1) {
            setState(() {
              controller.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut);
            }); 
            return KeyEventResult.handled;
          } else if (value.physicalKey == PhysicalKeyboardKey.escape &&
              value is KeyUpEvent) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
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
