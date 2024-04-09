import 'dart:async';
import 'dart:math';

import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:card_loading/card_loading.dart';
import 'package:collection/collection.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' as img show ThumbnaiSize, Image;
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gallery_view/gallery_item_list_view.dart';
import '../model/task_controller.dart';
import '../utils/label_utils.dart';

class ThumbImageView extends StatelessWidget {
  final String url;
  final Map<String, String>? header;
  final String? label;
  final double aspectRatio;
  const ThumbImageView(this.url,
      {super.key, this.header, this.label, this.aspectRatio = 9 / 16});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AspectRatio(
        aspectRatio: aspectRatio,
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

class GalleryListView extends StatelessWidget {
  final EasyRefreshController controller;
  final List<Gallery> data;
  final FutureOr<dynamic> Function()? onLoad;
  final FutureOr<dynamic> Function()? onRefresh;
  final void Function(Gallery) click;
  final Hitomi api;
  final ScrollController? scrollController;
  final PopupMenuButton<String> Function(Gallery gallery)? menusBuilder;

  const GalleryListView(
      {super.key,
      required this.controller,
      required this.data,
      required this.onLoad,
      this.onRefresh,
      required this.click,
      required this.api,
      this.scrollController,
      this.menusBuilder});

  @override
  Widget build(BuildContext context) {
    return MaxWidthBox(
        maxWidth: 1200,
        child: EasyRefresh(
            key: ValueKey(controller),
            controller: controller,
            header: const MaterialHeader(),
            footer: const MaterialFooter(),
            onLoad: onLoad,
            onRefresh: onRefresh,
            child: LayoutBuilder(builder: (c, cons) {
              return MasonryGridView.count(
                  controller: scrollController,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  crossAxisCount: max(cons.maxWidth ~/ 450, 1),
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
                  });
            })));
  }
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
    var image = gallery.files.first;
    final url = api.buildImageUrl(image,
        id: gallery.id, size: img.ThumbnaiSize.medium, proxy: true);
    var header = buildRequestHeader(url,
        'https://hitomi.la${gallery.galleryurl != null ? Uri.encodeFull(gallery.galleryurl!) : '${gallery.id}.html'}');
    debugPrint('width ${MediaQuery.of(context).size.width}');
    return InkWell(
        key: ValueKey(gallery.id),
        onTap: () => click(gallery),
        child: Card(
            child: Container(
                color: entry.value,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MaxWidthBox(
                          maxWidth:
                              min(MediaQuery.of(context).size.width / 3, 200),
                          child: ThumbImageView(url,
                              header: header,
                              label: gallery.files.length.toString(),
                              aspectRatio: image.width / image.height)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(gallery.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true),
                            Text(mapLangugeType(
                                context, gallery.language ?? '')),
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

class GalleryTagDetailInfo extends StatelessWidget {
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
  const GalleryTagDetailInfo(
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
                    onLongPress: () => showModalBottomSheet(
                        context: context,
                        builder: (context) => TagDetail(tag: label)),
                    onPressed: () => Navigator.of(context).pushNamed(
                        GalleryItemListView.routeName,
                        arguments: {'tag': label, 'local': local}))
            ])
    ]);
  }
}

class TagDetail extends StatelessWidget {
  final Map<String, dynamic> tag;
  static final urlExp =
      RegExp(r'!?\[(?<name>.*?)\]\(#*\s*\"?(?<url>\S+?)\"?\)');
  const TagDetail({super.key, required this.tag});

  List<MapEntry<String, String>> takeUrls(String input) {
    var urls = <MapEntry<String, String>>[];
    var sb = StringBuffer();
    var start = 0;
    for (var e in urlExp.allMatches(input)) {
      sb.write(input.substring(start, e.start));
      urls.add(MapEntry(e.namedGroup('name')!, e.namedGroup('url')!));
      start = e.end;
    }
    sb.write(input.substring(start, input.length));
    urls.add(MapEntry(sb.toString(), ''));
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    var imgs = takeUrls(tag['intro'] ?? '')
        .where((element) => imageExtension
            .any((extension) => element.value.endsWith(extension)))
        .toList();
    var text = takeUrls(tag['intro'] ?? '')
        .where((element) => !imageExtension
            .any((extension) => element.value.endsWith(extension)))
        .toList();
    var links = takeUrls(tag['links'] ?? '')
        .where((element) => !imageExtension
            .any((extension) => element.value.endsWith(extension)))
        .toList();
    return SizedBox(
        height: MediaQuery.of(context).size.height / 2,
        child: CustomScrollView(slivers: [
          SliverList.list(children: [
            Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(children: [
                  const Expanded(child: Divider()),
                  Text('${tag['translate']}'),
                  const Expanded(child: Divider()),
                ]))
          ]),
          SliverGrid.extent(
              maxCrossAxisExtent: 300,
              children: [for (var url in imgs) Image.network(url.value)]),
          SliverList.list(children: [
            const SizedBox(height: 8),
            Center(
                child: RichText(
                    text: TextSpan(children: [
              for (var url in text)
                TextSpan(
                    text: url.key,
                    style: url.value.isNotEmpty
                        ? const TextStyle(color: Colors.blue)
                        : const TextStyle(color: Colors.black),
                    recognizer: url.value.isNotEmpty
                        ? (TapGestureRecognizer()
                          ..onTap = () => launchUrl(Uri.parse(url.value)))
                        : null)
            ]))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (var url in links)
                TextButton(
                  child: Text(url.key),
                  onPressed: () => launchUrl(Uri.parse(url.value)),
                )
            ]),
          ])
        ]));
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
    var header = buildRequestHeader(url,
        'https://hitomi.la${gallery.galleryurl != null ? Uri.encodeFull(gallery.galleryurl!) : '${gallery.id}.html'}');
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
                      child: ThumbImageView(
                        url,
                        header: header,
                        label: gallery.files.length.toString(),
                        aspectRatio: gallery.files.first.width /
                            gallery.files.first.height,
                      )),
                  Expanded(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mapLangugeType(context, gallery.language ?? '')),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(gallery.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                  style:
                                      Theme.of(context).textTheme.titleSmall))
                        ]),
                    if (artists.isNotEmpty || groupes.isNotEmpty)
                      SizedBox(
                          height: 28,
                          child: Row(children: [
                            for (var artist in artists)
                              TextButton(
                                  onPressed: () => Navigator.of(context)
                                          .pushNamed(
                                              GalleryItemListView.routeName,
                                              arguments: {
                                            'tag': artist,
                                            'local': local
                                          }),
                                  style: TextButton.styleFrom(
                                    fixedSize: const Size.fromHeight(25),
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(40, 25),
                                  ),
                                  child: Text(
                                    '${artist['translate']}',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                            for (var group in groupes)
                              TextButton(
                                  onPressed: () => Navigator.of(context)
                                          .pushNamed(
                                              GalleryItemListView.routeName,
                                              arguments: {
                                            'tag': group,
                                            'local': local
                                          }),
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
                                          await context
                                              .read<TaskController>()
                                              .addTask(gallery)
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
                                value: (readIndex! + 1) / gallery.files.length),
                            Text('${(readIndex! + 1)}/${gallery.files.length}')
                          ])
                  ])),
                ])
        ]))));
  }
}
