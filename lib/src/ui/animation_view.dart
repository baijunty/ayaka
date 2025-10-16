import 'dart:async';
import 'dart:typed_data';

import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:ayaka/src/localization/app_localizations.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;
import 'package:provider/provider.dart';

import '../model/gallery_manager.dart';
import '../utils/proxy_network_image.dart';
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
    return EasyImageView.imageWidget(
        Center(
            child: ThumbImageView(
                ProxyNetworkImage(
                    dataStream: (chunkEvents) {
                      return buildAnimatedImage(context, chunkEvents);
                    },
                    key: widget.selected.fold(
                        StringBuffer(size.name),
                        (previousValue, element) =>
                            previousValue..write(element.name))),
                aspectRatio: widget.selected.first.width /
                    widget.selected.first.height)),
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
                }, test: (error) => true).then((value) =>
                        context.mounted ? context.showSnackBar(value) : false);
              },
              icon: const Icon(Icons.save))
        ]),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: size == img.ThumbnaiSize.medium
                  ? Center(child: imageView())
                  : imageView()),
          RadioGroup<String>(
              onChanged: (v) => setState(() {
                    size = img.ThumbnaiSize.fromStr(v ?? 'medium');
                  }),
              groupValue: size.name,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(AppLocalizations.of(context)!.thumb),
                const SizedBox(
                    width: 40, height: 40, child: Radio(value: 'medium')),
                const SizedBox(width: 20),
                Text(AppLocalizations.of(context)!.origin),
                const SizedBox(
                    width: 40, height: 40, child: Radio(value: 'origin')),
              ])),
        ])));
  }
}
