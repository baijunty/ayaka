import 'dart:async';
import 'dart:ui';

import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:card_loading/card_loading.dart';
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
  final String? label;
  const ThumbImageView(this.url, {super.key, this.header, this.label});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AspectRatio(
        aspectRatio: 9 / 16,
        child: Image.network(
          url,
          headers: header,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.error);
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
          fit: BoxFit.cover,
        ),
      ),
      if (label != null)
        SizedBox(
            width: 32,
            height: 32,
            child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.black45),
                  child: Center(
                      child: Text(label!,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.deepOrange))),
                )))
    ]);
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
    FutureOr<dynamic> Function()? onRefresh,
    void Function(Gallery) click,
    Hitomi api,
    {ScrollController? scrollController,
    PopupMenuButton<String> Function(Gallery gallery)? menusBuilder}) {
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
                              label: gallery.files.length.toString())),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(gallery.dirName,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text('${gallery.languageLocalname}'),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key),
                                  Text(format
                                      .format(format.parse(gallery.date))),
                                ]),
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
  final bool netLoading;
  final SettingsController controller;
  final bool local;
  static final types = [
    // 'artist',
    // 'group',
    'series',
    'character',
    'female',
    'male',
    'tag'
  ];
  const GalleryDetailHeadInfo(
      {super.key,
      required this.gallery,
      required this.extendedInfo,
      required this.controller,
      required this.local,
      required this.netLoading});

  String findMatchLabel(Label label) {
    var translate = extendedInfo.firstWhereOrNull((element) =>
        element['type'] == label.type &&
        element['name'] == label.name)?['translate'];
    return translate ?? label.name;
  }

  @override
  Widget build(BuildContext context) {
    var entries = extendedInfo
        .where((element) => types.contains(element['type']))
        .toList();
    return SliverList.list(children: [
      netLoading
          ? const CardLoading(height: 40)
          : Wrap(children: [
              for (var label in entries)
                TextButton(
                    child: Text('${label['translate']}'),
                    onPressed: () => Navigator.of(context).pushNamed(
                        GalleryListView.routeName,
                        arguments: {'tag': label}))
            ])
    ]);
  }
}

class GalleryDetailHead extends StatelessWidget {
  final SettingsController controller;
  final Gallery gallery;
  final bool local;
  final List<Map<String, dynamic>> extendedInfo;
  final bool netLoading;
  final bool exist;
  final int? readIndex;
  const GalleryDetailHead(
      {super.key,
      required this.controller,
      required this.gallery,
      required this.local,
      required this.extendedInfo,
      required this.netLoading,
      required this.exist,
      required this.readIndex});

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    final url = controller.hitomi(localDb: local).buildImageUrl(
        gallery.files.first,
        id: gallery.id,
        proxy: true,
        size: img.ThumbnaiSize.medium);
    var header = buildRequestHeader(
        url, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}');
    var format = DateFormat('yyyy-MM-dd');
    var artists =
        extendedInfo.where((element) => element['type'] == 'artist').take(2);
    var groupes =
        extendedInfo.where((element) => element['type'] == 'group').take(2);
    return SliverAppBar(
        backgroundColor: netLoading ? Colors.transparent : entry.value,
        automaticallyImplyLeading: false,
        expandedHeight: 240,
        flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
                child: Column(children: [
          AppBar(
              leading: BackButton(onPressed: () => Navigator.of(context).pop()),
              actions: const [
                IconButton(onPressed: null, icon: Icon(Icons.share))
              ],
              backgroundColor: entry.value),
          netLoading
              ? const Row(children: [
                  CardLoading(height: 160, width: 100),
                  SizedBox(width: 8),
                  Expanded(child: CardLoading(height: 160)),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                      width: 100,
                      child: ThumbImageView(url,
                          header: header,
                          label: gallery.files.length.toString())),
                  Expanded(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gallery.languageLocalname ?? ''),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(gallery.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                  style:
                                      Theme.of(context).textTheme.titleSmall))
                        ]),
                    if (artists.isNotEmpty)
                      SizedBox(
                          height: 28,
                          child: Row(children: [
                            for (var artist in artists)
                              TextButton(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(GalleryListView.routeName,
                                          arguments: {'tag': artist}),
                                  style: TextButton.styleFrom(
                                    fixedSize: const Size.fromHeight(25),
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(40, 25),
                                  ),
                                  child: Text(
                                    '${artist['translate']}',
                                    style: const TextStyle(fontSize: 12),
                                  ))
                          ])),
                    if (groupes.isNotEmpty)
                      SizedBox(
                          height: 28,
                          child: Row(children: [
                            for (var group in groupes)
                              TextButton(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(GalleryListView.routeName,
                                          arguments: {'tag': group}),
                                  style: TextButton.styleFrom(
                                    maximumSize: const Size.fromHeight(25),
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(40, 25),
                                  ),
                                  child: Text(
                                    '${group['translate']}',
                                    style: const TextStyle(fontSize: 12),
                                  ))
                          ])),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 8),
                          if (!exist)
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: OutlinedButton(
                                        onPressed: () async {
                                          await controller.manager
                                              .parseCommandAndRun(
                                                  '${gallery.id}')
                                              .then((value) => showSnackBar(
                                                  context,
                                                  AppLocalizations.of(context)!
                                                      .addTaskSuccess))
                                              .catchError(
                                                  (e) => showSnackBar(
                                                      context, e.toString()),
                                                  test: (error) => true);
                                        },
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .download)))),
                          Expanded(
                            child: FilledButton(
                                onPressed: () => Navigator.of(context)
                                        .pushNamed(GalleryViewer.routeName,
                                            arguments: {
                                          'gallery': gallery,
                                          'index': 0,
                                          'local': local,
                                        }),
                                child:
                                    Text(AppLocalizations.of(context)!.read)),
                          ),
                          const SizedBox(width: 8),
                        ]),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(entry.key),
                          Text(format.format(format.parse(gallery.date)))
                        ]),
                    if (readIndex != null)
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            LinearProgressIndicator(
                                value: readIndex! / gallery.files.length),
                            Text('$readIndex/${gallery.files.length}')
                          ])
                  ])),
                ])
        ]))));
  }
}
