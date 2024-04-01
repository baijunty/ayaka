import 'dart:async';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:collection/collection.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' as img show ThumbnaiSize, Image;
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:intl/intl.dart';

import '../gallery_view/gallery_item_list_view.dart';
import '../utils/label_utils.dart';

class ThumbImageView extends StatelessWidget {
  final String url;
  final Map<String, String>? header;
  final String? indexStr;
  const ThumbImageView(this.url, {super.key, this.header, this.indexStr});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(children: [
          AspectRatio(
              aspectRatio: 9 / 16,
              child: Image.network(
                url,
                headers: header,
                errorBuilder: (context, error, stackTrace) {
                  return Text(error.toString());
                },
                loadingBuilder: (context, child, loadingProgress) {
                  return loadingProgress == null
                      ? child
                      : const CircularProgressIndicator();
                },
                frameBuilder: (BuildContext context, Widget child, int? frame,
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
                },
                fit: BoxFit.contain,
              )),
          if (indexStr != null)
            Positioned(
                left: 4,
                top: 4,
                child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          indexStr!,
                          style: Theme.of(context)
                              .primaryTextTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white),
                          textScaler: const TextScaler.linear(1.2),
                        ))))
        ]));
  }
}

void showSnackBar(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 2000),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      )));
}

String takeTranslateText(String input) {
  var reg = RegExp(r'!?\[(?<name>.*?)\]\(#*\s*"?(?<url>\S+?)"?\)');
  var matches = reg.allMatches(input);
  if (matches.isNotEmpty) {
    int start = 0;
    var sb = StringBuffer();
    for (var element in matches) {
      sb.write(input.substring(start, element.start));
      start = element.end;
    }
    sb.write(input.substring(start));
    return sb.toString();
  }
  return input;
}

Widget buildGalleryListView(
    EasyRefreshController controller,
    List<Gallery> data,
    FutureOr<dynamic> Function() onLoad,
    FutureOr<dynamic> Function() onRefresh,
    void Function(Gallery) click,
    Hitomi api,
    {ScrollController? scrollController,
    PopupMenuButton<String> Function(Gallery)? menusBuilder}) {
  return EasyRefresh(
      key: ValueKey(controller),
      controller: controller,
      header: const MaterialHeader(),
      footer: const MaterialFooter(),
      onLoad: onLoad,
      onRefresh: onRefresh,
      child: GridView.builder(
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400, mainAxisExtent: 160),
          itemCount: data.length,
          itemBuilder: (BuildContext context, int index) {
            final item = data[index];
            return GalleryInfo(
              key: ValueKey(item.id),
              gallery: item,
              image: item.files.first,
              click: click,
              api: api,
              menus: menusBuilder?.call(item),
            );
          }));
}

class GalleryInfo extends StatelessWidget {
  final Gallery gallery;
  final img.Image image;
  final Hitomi api;
  final void Function(Gallery) click;
  final PopupMenuButton<String>? menus;
  const GalleryInfo(
      {super.key,
      required this.gallery,
      required this.image,
      required this.click,
      required this.api,
      required this.menus});

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    var format = DateFormat('yyyy-MM-dd');
    final url = api.buildImageUrl(gallery.files.first,
        id: gallery.id, size: img.ThumbnaiSize.medium, proxy: true);
    var header = buildRequestHeader(
        url, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}');
    return InkWell(
        key: ValueKey(gallery.id),
        onTap: () => click(gallery),
        child: Card(
            child: Container(
                color: entry.value,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.fromSize(
                          size: const Size.fromWidth(100),
                          child: ThumbImageView(url,
                              header: header,
                              indexStr: gallery.files.length.toString())),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(gallery.dirName, maxLines: 2, softWrap: true),
                            Text('${gallery.languageLocalname}'),
                            Text(entry.key),
                            Text(format.format(format.parse(gallery.date))),
                          ])),
                      if (menus != null) menus!
                    ]))));
  }
}

class MaxWidthBox extends StatelessWidget {
  final double? maxWidth;
  final AlignmentGeometry alignment;
  final Widget child;
  final Widget? background;

  const MaxWidthBox(
      {super.key,
      required this.maxWidth,
      required this.child,
      this.background,
      this.alignment = Alignment.topCenter});

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    if (maxWidth != null) {
      if (mediaQuery.size.width > maxWidth!) {
        mediaQuery =
            mediaQuery.copyWith(size: Size(maxWidth!, mediaQuery.size.height));
      }
    }

    return Stack(
      alignment: alignment,
      children: [
        background ?? const SizedBox.shrink(),
        MediaQuery(
            data: mediaQuery, child: SizedBox(width: maxWidth, child: child)),
      ],
    );
  }
}

class GalleryDetailHeadInfo extends StatelessWidget {
  final Gallery gallery;
  final List<Map<String, dynamic>> extendedInfo;
  final SettingsController controller;
  final bool local;
  const GalleryDetailHeadInfo(
      {super.key,
      required this.gallery,
      required this.extendedInfo,
      required this.controller,
      required this.local});

  String findMatchLabel(Label label) {
    var translate = extendedInfo.firstWhereOrNull((element) =>
        element['type'] == label.type &&
        element['name'] == label.name)?['translate'];
    return translate ?? label.name;
  }

  @override
  Widget build(BuildContext context) {
    var entries = gallery
        .labels()
        .groupListsBy((element) => element.type)
        .entries
        .toList();
    return SliverList.builder(
        itemBuilder: (context, index) {
          var entry = entries[index];
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(mapTagType(context, entry.key),
                style: Theme.of(context).textTheme.labelMedium),
            Expanded(
                child: Wrap(children: [
              for (var label in entry.value)
                TextButton(
                    child: Text(findMatchLabel(label)),
                    onPressed: () => Navigator.of(context).pushNamed(
                        GalleryListView.routeName,
                        arguments: {'tag': label}))
            ]))
          ]);
        },
        itemCount: entries.length);
  }
}

class GalleryDetailHead extends StatelessWidget {
  final SettingsController controller;
  final Gallery gallery;
  final bool local;
  const GalleryDetailHead(
      {super.key,
      required this.controller,
      required this.gallery,
      required this.local});

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    final url = controller
        .hitomi(localDb: local)
        .buildImageUrl(gallery.files.first, id: gallery.id, proxy: true);
    var header = buildRequestHeader(
        url, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}');
    FutureBuilder<List<Gallery>>? buttonBuilder;
    if (!local) {
      buttonBuilder = FutureBuilder(
          future: controller
              .hitomi(localDb: true)
              .findSimilarGalleryBySearch(gallery)
              .then((value) => value.data),
          builder: (c, snap) {
            if (snap.hasData && snap.data!.isNotEmpty) {
              return OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed(
                      GalleryDetailsView.routeName,
                      arguments: {'gallery': snap.data!.first, 'local': local}),
                  child: Text(AppLocalizations.of(context)!.downloaded));
            } else if (snap.hasData) {
              return OutlinedButton(
                  onPressed: () async {
                    await controller.manager
                        .parseCommandAndRun('${gallery.id}')
                        .then((value) => showSnackBar(context,
                            AppLocalizations.of(context)!.addTaskSuccess))
                        .catchError((e) => showSnackBar(context, e.toString()),
                            test: (error) => true);
                  },
                  child: Text(AppLocalizations.of(context)!.download));
            }
            return Container();
          });
    }
    return SliverAppBar.large(
        excludeHeaderSemantics: true,
        backgroundColor: entry.value,
        title: Text(gallery.name),
        leading: Row(children: [
          BackButton(onPressed: () => Navigator.of(context).pop())
        ]),
        expandedHeight: 200,
        flexibleSpace: FlexibleSpaceBar(
            background: Container(
                margin: const EdgeInsets.only(left: 40, top: 24),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 100,
                          child: ThumbImageView(url,
                              header: header,
                              indexStr: gallery.files.length.toString())),
                      Expanded(
                          child: Column(children: [
                        Text(gallery.name,
                            style: Theme.of(context).textTheme.titleSmall),
                        Divider(color: Theme.of(context).primaryColor),
                        Text(gallery.languageLocalname ?? ''),
                        Row(children: [
                          if (buttonBuilder != null) buttonBuilder,
                          const SizedBox(width: 16),
                          OutlinedButton(
                              onPressed: () => Navigator.of(context).pushNamed(
                                      GalleryViewer.routeName,
                                      arguments: {
                                        'gallery': gallery,
                                        'index': 0,
                                        'local': local,
                                      }),
                              child: Text(AppLocalizations.of(context)!.read)),
                        ]),
                        Row(children: [
                          Text(AppLocalizations.of(context)!.type),
                          const SizedBox(width: 16),
                          Text(entry.key),
                        ])
                      ])),
                    ]))));
  }
}
