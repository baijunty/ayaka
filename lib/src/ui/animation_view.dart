import 'dart:async';
import 'dart:typed_data';

import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;
import 'package:provider/provider.dart';

import '../model/gallery_manager.dart';
import '../utils/proxy_netwrok_image.dart';
import 'common_view.dart';

class AnimatedSaverDialog extends StatefulWidget {
  final List<img.Image> selected;
  final Hitomi api;
  final Gallery gallery;
  const AnimatedSaverDialog(
      {super.key,
      required this.selected,
      required this.api,
      required this.gallery});

  @override
  State<StatefulWidget> createState() {
    return _AnimatedSaverDialogView();
  }
}

class _AnimatedSaverDialogView extends State<AnimatedSaverDialog> {
  Uint8List? cacheDate;
  img.ThumbnaiSize size = img.ThumbnaiSize.medium;
  Future<Uint8List> buildAnimatedImage(BuildContext context,
      StreamController<ImageChunkEvent> chunkEvents) async {
    var data = await context.read<GalleryManager>().makeAnimatedImage(
        widget.selected, widget.api,
        id: widget.gallery.id,
        size: size,
        onProgress: (index, total) => chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: index, expectedTotalBytes: total)));
    cacheDate = data;
    return data;
  }

  Widget imageView() {
    return EasyImageView(
        imageProvider: ProxyNetworkImage(
            dataStream: (chunkEvents) {
              return buildAnimatedImage(context, chunkEvents);
            },
            key: widget.selected.fold(
                StringBuffer(size.name),
                (previousValue, element) =>
                    previousValue..write(element.name))),
        doubleTapZoomable: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(actions: [
          IconButton(
              onPressed: () async {
                await FileSaver.instance
                    .saveFile(
                        name:
                            '${widget.gallery.createDir('', createDir: false).path}_${widget.selected.length}.png',
                        bytes: cacheDate)
                    .catchError((e) {
                  return '$e';
                }, test: (error) => true).then(
                        (value) => context.showSnackBar(value));
              },
              icon: const Icon(Icons.save))
        ]),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: size == img.ThumbnaiSize.medium
                  ? Center(child: imageView())
                  : imageView()),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Row(children: [
              Text(AppLocalizations.of(context)!.thumb),
              Radio.adaptive(
                  value: img.ThumbnaiSize.medium,
                  groupValue: size,
                  onChanged: (m) => setState(() {
                        size = m ?? size;
                      }))
            ]),
            Row(children: [
              Text(AppLocalizations.of(context)!.origin),
              Radio.adaptive(
                  value: img.ThumbnaiSize.origin,
                  groupValue: size,
                  onChanged: (m) => setState(() {
                        size = m ?? size;
                      })),
            ])
          ]),
        ])));
  }
}
