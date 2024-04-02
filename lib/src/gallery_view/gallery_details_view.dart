import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

class GalleryDetailsView extends StatefulWidget {
  const GalleryDetailsView({super.key});

  static const routeName = '/gallery_detail';

  @override
  State<StatefulWidget> createState() {
    return _GalleryDetailView();
  }
}

class _GalleryDetailView extends State<GalleryDetailsView> {
  late SettingsController controller = context.read<SettingsController>();
  late Gallery gallery;
  bool local = false;
  bool exists = false;
  bool netLoading = true;
  int? readedIndex;
  List<Map<String, dynamic>> translates = [];
  Future<void> _fetchTransLate() async {
    var api = controller.hitomi(localDb: true);
    await (local
            ? Future.value(true)
            : api.findSimilarGalleryBySearch(gallery).then((value) {
                exists = value.data.isNotEmpty;
                return exists;
              }))
        .then((value) => api.translate(gallery.labels()))
        .then((value) => setState(() {
              translates.addAll(value);
              netLoading = false;
            }))
        .catchError((e) {
      netLoading = false;
    }, test: (error) => true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.read<SettingsController>();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    gallery = args['gallery'];
    local = args['local'] ?? local;
    if (translates.isEmpty) {
      _fetchTransLate();
    }
    controller.manager.helper
        .readlData<int>('UserLog', 'mark', {'id': gallery.id}).then(
            (value) => setState(() {
                  readedIndex = value;
                }));
    debugPrint('didChangeDependencies');
  }

  @override
  void didUpdateWidget(covariant GalleryDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('didUpdateWidget $oldWidget');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: CustomScrollView(slivers: [
      GalleryDetailHead(
        controller: controller,
        gallery: gallery,
        local: local,
        extendedInfo: translates,
        netLoading: netLoading,
        exist: exists,
        readIndex: readedIndex,
      ),
      GalleryDetailHeadInfo(
        gallery: gallery,
        extendedInfo: translates,
        controller: controller,
        local: local,
        netLoading: netLoading,
      ),
      SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300),
          itemCount: gallery.files.length,
          itemBuilder: (context, index) {
            final url = controller.hitomi(localDb: local).buildImageUrl(
                gallery.files[index],
                id: gallery.id,
                size: ThumbnaiSize.medium,
                proxy: true);
            var header = buildRequestHeader(
                url, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}');
            return GestureDetector(
                onTap: () async => await Navigator.pushNamed(
                        context, GalleryViewer.routeName, arguments: {
                      'gallery': gallery,
                      'index': index,
                      'local': local,
                    }),
                child: Card.outlined(
                    child: Center(child: ThumbImageView(url, header: header))));
          })
    ]));
  }
}
