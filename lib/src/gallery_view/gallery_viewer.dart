import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' show ThumbnaiSize;
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

class GalleryViewer extends StatefulWidget {
  const GalleryViewer({super.key});

  static const routeName = '/gallery_viewer';
  @override
  State<StatefulWidget> createState() {
    return _GalleryViewer();
  }
}

class _MultiImageProvider extends MultiImageProvider {
  final void Function(int) pageChage;
  _MultiImageProvider(this.pageChage, super.imageProviders,
      {super.initialIndex});

  @override
  ImageProvider<Object> imageBuilder(BuildContext context, int index) {
    pageChage(index);
    return super.imageBuilder(context, index);
  }
}

class _GalleryViewer extends State<GalleryViewer>
    with SingleTickerProviderStateMixin {
  late Gallery _gallery;
  var index = 0;
  var showAppBar = false;
  late PageController controller;
  late _MultiImageProvider provider;
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
    provider = _MultiImageProvider((page) {
      index = page;
    },
        _gallery.files.map((e) {
          final url = settings.hitomi(localDb: args['local']).buildImageUrl(e,
              id: _gallery.id, size: ThumbnaiSize.origin, proxy: true);
          var header = buildRequestHeader(
              url, 'https://hitomi.la${Uri.encodeFull(_gallery.galleryurl!)}');
          return NetworkImage(url, headers: header);
        }).toList(),
        initialIndex: index);
    controller.addListener(handlePageChange);
    if (index == 0) {
      _settingsController.manager.helper
          .readlData<int>('UserLog', 'mark', {'id': _gallery.id})
          .then((value) => (value ?? 0) >> readMask)
          .then((value) => controller.jumpToPage(value));
    }
  }

  void handlePageChange() async {
    await _settingsController.manager.helper.insertUserLog(
        _gallery.id, controller.page!.toInt() << readMask,
        content: _gallery.name);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Stack(children: [
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
                      title: Text(_gallery.name),
                      backgroundColor: Theme.of(context).primaryColor,
                      leading: BackButton(
                          onPressed: () => Navigator.of(context).pop())))),
        ]),
        theme: ThemeData.dark());
  }
}
