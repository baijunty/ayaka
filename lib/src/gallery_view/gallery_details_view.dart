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
  @override
  Widget build(BuildContext context) {
    var settings = context.read<SettingsController>();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    Gallery gallery = args['gallery'];
    bool local = args['local'];
    final url = settings.hitomi(localDb: local).buildImageUrl(gallery.files.first,
        id: gallery.id,
        size: ThumbnaiSize.smaill,
        proxy: true);
    var header = buildRequestHeader(
        url, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}');
    return Scaffold(
        body: CustomScrollView(slivers: [
      GalleryDetailHead(
          manager: settings.manager, gallery: gallery, local: local),
      SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450),
          itemCount: gallery.files.length,
          itemBuilder: (context, index) {
            return GestureDetector(
                onTap: () async => await Navigator.pushNamed(
                        context, GalleryViewer.routeName, arguments: {
                      'gallery': gallery,
                      'index': index,
                      'local': local,
                    }),
                child: Card.outlined(
                    child: ThumbImageView(
                      url,header: header,
                        indexStr: (index + 1).toString())));
          })
    ]));
  }
}
