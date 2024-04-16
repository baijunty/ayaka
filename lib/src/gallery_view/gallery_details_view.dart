import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/model/task_controller.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:provider/provider.dart';

import '../utils/proxy_netwrok_image.dart';

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
  Gallery? exists;
  bool netLoading = true;
  int? readedIndex;
  List<Map<String, dynamic>> translates = [];
  Future<void> _fetchTransLate() async {
    var api = controller.hitomi(localDb: true);
    await (local
            ? Future.value(gallery).then((value) => exists = value)
            : context
                .read<GalleryManager>()
                .checkExist(gallery.id)
                .then((value) => value['value'] as List<dynamic>?)
                .then((value) async {
                if (value?.firstOrNull != null) {
                  exists = await api.fetchGallery(value!.first);
                }
                return exists;
              }).catchError((e) => null, test: (error) => true))
        .then((value) => api.translate((exists ?? gallery).labels()))
        .then((value) => setState(() {
              translates.addAll(value);
              netLoading = false;
            }))
        .catchError(
            (e) => setState(() {
                  netLoading = false;
                  showSnackBar(context, '$e');
                }),
            test: (error) => true);
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
        .readlData<int>('UserLog', 'mark', {'id': gallery.id}).then((value) {
      if (value?.isFlagSet(readMask) == true) {
        setState(() {
          readedIndex = value!.unSetMask(readMask);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Center(
      child: MaxWidthBox(
          maxWidth: 1200,
          child: CustomScrollView(slivers: [
            GalleryDetailHead(
                api: controller.hitomi(localDb: local),
                gallery: exists ?? gallery,
                local: local,
                extendedInfo: translates,
                netLoading: netLoading,
                exist: exists != null),
            GalleryTagDetailInfo(
              gallery: gallery,
              extendedInfo: translates,
              controller: controller,
              local: local,
              netLoading: netLoading,
              readIndex: readedIndex,
            ),
            SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300),
                itemCount: gallery.files.length,
                itemBuilder: (context, index) {
                  var image = gallery.files[index];
                  return GestureDetector(
                      onTap: () async => await Navigator.pushNamed(
                              context, GalleryViewer.routeName,
                              arguments: {
                                'gallery': exists ?? gallery,
                                'index': index,
                                'local': exists != null,
                              }),
                      child: Card.outlined(
                          child: Center(
                              child: ThumbImageView(
                        ProxyNetworkImage(gallery.id, image,
                            controller.hitomi(localDb: local)),
                        label: '${index + 1}',
                        aspectRatio: image.width / image.height,
                      ))));
                })
          ])),
    )));
  }
}
