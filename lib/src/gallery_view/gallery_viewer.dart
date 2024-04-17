import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' show ThumbnaiSize;
import 'package:provider/provider.dart';

import '../utils/proxy_netwrok_image.dart';

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
  late SettingsController _settingsController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settingsController = context.read<SettingsController>();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _gallery = args['gallery'];
    index = args['index'] ?? 0;
    controller = PageController(initialPage: index);
    var settings = context.read<SettingsController>();
    final api = settings.hitomi(localDb: args['local']);
    provider = MultiImageProvider(
        _gallery.files.map((e) {
          return ProxyNetworkImage(_gallery.id, e, api,
              size: ThumbnaiSize.origin);
        }).toList(),
        initialIndex: index);
    controller.addListener(handlePageChange);
    if (args['index'] == null) {
      _settingsController.manager.helper
          .readlData<int>('UserLog', 'mark', {'id': _gallery.id})
          .then((value) => (value?.unSetMask(readMask) ?? 0))
          .then((value) => controller.jumpToPage(value));
    }
  }

  void handlePageChange() async {
    if (controller.page! - controller.page!.toInt() == 0) {
      index = controller.page!.toInt();
      await _settingsController.manager.helper.insertUserLog(
          _gallery.id, index.setMask(readMask),
          content: _gallery.name);
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      AnimatedOpacity(
          key: GlobalObjectKey(_gallery),
          duration: const Duration(milliseconds: 250),
          opacity: showAppBar ? 1.0 : 0.0,
          curve: Curves.easeInOut,
          child: SizedBox(
              height: 56,
              child: AppBar(
                  title: Column(children: [
                    Text(
                        '${_gallery.name}-${index + 1}/${_gallery.files.length}'),
                    LinearProgressIndicator(
                        value: (index + 1) / _gallery.files.length)
                  ]),
                  backgroundColor: Theme.of(context).primaryColor,
                  leading: BackButton(
                      onPressed: () => Navigator.of(context).pop())))),
    ])));
  }
}
