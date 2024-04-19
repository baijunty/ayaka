import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/model/gallery_manager.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:provider/provider.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;
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
  CancelToken? token;
  final List<img.Image> _selected = [];
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
                  exists = await api.fetchGallery(value!.first, token: token);
                }
                return exists;
              }).catchError((e) => null, test: (error) => true))
        .then((value) => api.translate(gallery.labels()))
        .then((value) => setState(() {
              translates.addAll(value);
              netLoading = false;
            }))
        .catchError((e) {
      if (mounted) {
        setState(() {
          netLoading = false;
          showSnackBar(context, '$e');
        });
      }
    }, test: (error) => true);
  }

  @override
  void dispose() {
    super.dispose();
    token?.cancel('dispose');
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
      token = CancelToken();
      _fetchTransLate();
    }
    controller.manager.helper.readlData<int>(
        'UserLog', 'mark', {'id': gallery.id, 'type': readMask}).then((value) {
      if (value != null) {
        setState(() {
          readedIndex = value;
        });
      }
    });
  }

  void _handleClick(int index) async {
    if (_selected.isEmpty) {
      await Navigator.pushNamed(context, GalleryViewer.routeName, arguments: {
        'gallery': exists ?? gallery,
        'index': index,
        'local': exists != null,
      });
    } else {
      setState(() {
        var img = gallery.files[index];
        if (_selected.contains(img)) {
          _selected.remove(img);
        } else {
          _selected.add(img);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var api = controller.hitomi(localDb: local);
    var refererUrl = 'https://hitomi.la${gallery.urlEncode()}';
    return Scaffold(
        body: SafeArea(
            child: Center(
      child: MaxWidthBox(
          maxWidth: 1280,
          child: CustomScrollView(slivers: [
            GalleryDetailHead(
                api: controller.hitomi(localDb: local),
                gallery: gallery,
                local: local,
                extendedInfo: translates,
                netLoading: netLoading,
                exist: exists,
                selected: _selected),
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
                      onTap: () => _handleClick(index),
                      onLongPress: _selected.isEmpty
                          ? () => setState(() {
                                _selected.add(image);
                              })
                          : null,
                      child: Card.outlined(
                          child: Center(
                              child: ThumbImageView(
                        ProxyNetworkImage(
                            dataStream: (chunkEvents) => api.fetchImageData(
                                image,
                                id: gallery.id,
                                size: img.ThumbnaiSize.medium,
                                refererUrl: refererUrl,
                                onProcess: (now, total) => chunkEvents.add(
                                    ImageChunkEvent(
                                        cumulativeBytesLoaded: now,
                                        expectedTotalBytes: total))),
                            key: image.hash),
                        label: _selected.isEmpty
                            ? Text('${index + 1}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: Colors.deepOrange))
                            : Checkbox.adaptive(
                                value: _selected.contains(image),
                                onChanged: (b) => _handleClick(index)),
                        aspectRatio: image.width / image.height,
                      ))));
                })
          ])),
    )));
  }
}
