import 'dart:async';
import 'dart:math';

import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/utils/proxy_netwrok_image.dart';
import 'package:card_loading/card_loading.dart';
import 'package:collection/collection.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gallery_view/gallery_item_list_view.dart';
import '../model/gallery_manager.dart';
import '../utils/label_utils.dart';
import '../utils/responsive_util.dart';

class ThumbImageView extends StatelessWidget {
  final ImageProvider provider;
  final Widget? label;
  final double aspectRatio;
  const ThumbImageView(this.provider,
      {super.key, this.label, this.aspectRatio = 9 / 16});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AspectRatio(
        aspectRatio: max(aspectRatio, 0.5),
        child: Image(
          image: provider,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.error);
          },
          loadingBuilder: (context, child, loadingProgress) {
            return loadingProgress == null
                ? child
                : Center(
                    child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null));
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
                  child: Center(child: label!),
                )))
    ]);
  }
}

void showSnackBar(BuildContext context, String msg) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: Theme.of(context).textTheme.labelMedium),
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        )));
  }
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
    return EasyRefresh(
        controller: controller,
        header: ClassicHeader(
            dragText: AppLocalizations.of(context)!.pullToRefresh,
            armedText: AppLocalizations.of(context)!.releaseReady,
            readyText: AppLocalizations.of(context)!.releaseReady,
            processingText: AppLocalizations.of(context)!.refreshing,
            processedText: AppLocalizations.of(context)!.success,
            noMoreText: AppLocalizations.of(context)!.noMore,
            failedText: AppLocalizations.of(context)!.failed,
            messageText: '${AppLocalizations.of(context)!.lastUpdatedAt} %T'),
        footer: ClassicFooter(
            dragText: AppLocalizations.of(context)!.pullToRefresh,
            armedText: AppLocalizations.of(context)!.releaseReady,
            readyText: AppLocalizations.of(context)!.releaseReady,
            processingText: AppLocalizations.of(context)!.refreshing,
            processedText: AppLocalizations.of(context)!.success,
            noMoreText: AppLocalizations.of(context)!.noMore,
            failedText: AppLocalizations.of(context)!.failed,
            messageText: '${AppLocalizations.of(context)!.lastUpdatedAt} %T'),
        onLoad: onLoad,
        onRefresh: onRefresh,
        child: LayoutBuilder(builder: (c, cons) {
          return MasonryGridView.count(
              controller: scrollController,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              crossAxisCount: max(cons.maxWidth ~/ 550, 1),
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
        }));
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
    return LayoutBuilder(builder: (context, cons) {
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
                            maxWidth: min(cons.maxWidth / 3, 300),
                            child: Hero(
                                tag: 'gallery-thumb ${gallery.id}',
                                child: ThumbImageView(
                                    ProxyNetworkImage(
                                        dataStream: (chunkEvents) =>
                                            api.fetchImageData(
                                              gallery.files.first,
                                              id: gallery.id,
                                              size: img.ThumbnaiSize.medium,
                                              refererUrl:
                                                  'https://hitomi.la${gallery.urlEncode()}',
                                              onProcess: (now, total) =>
                                                  chunkEvents
                                                      .add(ImageChunkEvent(
                                                          cumulativeBytesLoaded:
                                                              now,
                                                          expectedTotalBytes:
                                                              total)),
                                            ),
                                        key: gallery.files.first.hash),
                                    label: Text(gallery.files.length.toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                                color: Colors.deepOrange)),
                                    aspectRatio: image.width / image.height))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Hero(
                                  tag: 'gallery_${gallery.id}_name',
                                  child: Text(gallery.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true)),
                              const SizedBox(height: 8),
                              Hero(
                                  tag: 'gallery_${gallery.id}_language',
                                  child: Text(mapLangugeType(
                                      context, gallery.language ?? ''))),
                              const SizedBox(height: 8),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Hero(
                                        tag: 'gallery_${gallery.id}_type',
                                        child: TagButton(label: {
                                          ...TypeLabel(gallery.type).toMap(),
                                          'translate': entry.key
                                        }, local: false)),
                                    Hero(
                                        tag: 'gallery_${gallery.id}_date',
                                        child: Text(format.format(
                                            format.parse(gallery.date)))),
                                  ]),
                            ])),
                        if (menus != null) menus!
                      ]))));
    });
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

class TagButton extends StatelessWidget {
  final Map<String, dynamic> label;
  final bool local;
  final ButtonStyle? style;
  final String? commondPrefix;
  const TagButton(
      {super.key,
      required this.label,
      required this.local,
      this.style,
      this.commondPrefix});

  @override
  Widget build(BuildContext context) {
    return TextButton(
        style: style ?? Theme.of(context).textButtonTheme.style,
        onLongPress: () => showModalBottomSheet(
            context: context,
            builder: (context) =>
                TagDetail(tag: label, commondPrefix: commondPrefix)),
        onPressed: () => Navigator.of(context).pushNamed(
            GalleryItemListView.routeName,
            arguments: {'tag': label, 'local': local}),
        child: Text('${label['translate'] ?? label['name']}'));
  }
}

class GalleryTagDetailInfo extends StatelessWidget {
  final Gallery gallery;
  final List<Map<String, dynamic>> extendedInfo;
  final bool netLoading;
  final SettingsController controller;
  final bool local;
  final int? readIndex;
  const GalleryTagDetailInfo(
      {super.key,
      required this.gallery,
      required this.extendedInfo,
      required this.controller,
      required this.local,
      required this.netLoading,
      this.readIndex});

  String findMatchLabel(Label label) {
    var translate = extendedInfo.firstWhereOrNull((element) =>
        element['type'] == label.type &&
        element['name'] == label.name)?['translate'];
    return translate ?? label.name;
  }

  Widget _buildIndexView(int readIndex) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      LinearProgressIndicator(value: (readIndex + 1) / gallery.files.length),
      Text('${(readIndex + 1)}/${gallery.files.length}')
    ]);
  }

  Widget _serialInfo(BuildContext context, List<Map<String, dynamic>> series,
      List<Map<String, dynamic>> characters) {
    return ExpansionTile(
        title: Text(
            '${AppLocalizations.of(context)!.series} & ${AppLocalizations.of(context)!.character}'),
        children: [
          Wrap(children: [
            for (var serial in series) TagButton(label: serial, local: local),
            for (var character in characters)
              TagButton(label: character, local: local),
          ])
        ]);
  }

  Widget _otherTagInfo(
      BuildContext context,
      List<Map<String, dynamic>>? females,
      List<Map<String, dynamic>>? males,
      List<Map<String, dynamic>>? tags) {
    return ExpansionTile(
        title: Text(AppLocalizations.of(context)!.tag),
        children: [
          Wrap(children: [
            if (females != null)
              for (var female in females)
                TagButton(
                  label: female,
                  local: local,
                ),
            if (males != null)
              for (var male in males)
                TagButton(
                  label: male,
                  local: local,
                ),
            if (tags != null)
              for (var tag in tags)
                TagButton(
                  label: tag,
                  local: local,
                ),
          ])
        ]);
  }

  @override
  Widget build(BuildContext context) {
    var typeList =
        extendedInfo.groupListsBy((element) => element['type'] as String);
    return SliverList.list(children: [
      if (readIndex != null) _buildIndexView(readIndex!),
      if (netLoading) const CardLoading(height: 40),
      if (!netLoading &&
          [typeList['series'], typeList['character']]
              .every((element) => element != null))
        _serialInfo(context, typeList['series']!, typeList['character']!),
      if (!netLoading &&
          [typeList['female'], typeList['male'], typeList['tag']]
              .any((element) => element != null))
        _otherTagInfo(
            context, typeList['female'], typeList['male'], typeList['tag'])
    ]);
  }
}

class TagDetail extends StatelessWidget {
  final Map<String, dynamic> tag;
  static final urlExp =
      RegExp(r'!?\[(?<name>.*?)\]\(#*\s*\"?(?<url>\S+?)\"?\)');
  final String? commondPrefix;
  const TagDetail({super.key, required this.tag, this.commondPrefix});

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
    var taskControl = context.read<GalleryManager>();
    var imgs = takeUrls(tag['intro'] ?? '')
        .where((element) => imageExtension
            .any((extension) => element.value.endsWith(extension)))
        .toList();
    var text = takeUrls(tag['intro'] ?? '')
        .where((element) => !imageExtension
            .any((extension) => element.value.endsWith(extension)))
        .toList();
    var links = takeUrls(tag['links'] ?? '')
        .where((element) =>
            element.value.isNotEmpty &&
            !imageExtension
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
                  const SizedBox(width: 8),
                  if (tag['count'] != null)
                    Text(
                        '${AppLocalizations.of(context)!.downloaded}:${tag['count']} ${AppLocalizations.of(context)!.lastUpdatedAt} ${tag['date']}'),
                  if (commondPrefix != null)
                    IconButton(
                        onPressed: () async => taskControl
                            .addTask('$commondPrefix "${tag['name']}"')
                            .then((value) => showSnackBar(context,
                                AppLocalizations.of(context)!.addTaskSuccess)),
                        icon: const Icon(Icons.download)),
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
  final Gallery gallery;
  final bool local;
  final List<Map<String, dynamic>> extendedInfo;
  final bool netLoading;
  final Gallery? exist;
  final Hitomi api;
  const GalleryDetailHead(
      {super.key,
      required this.api,
      required this.gallery,
      required this.local,
      required this.extendedInfo,
      required this.netLoading,
      required this.exist});

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    var format = DateFormat('yyyy-MM-dd');
    var size = currentDevice(context) == DeviceInfo.mobile ? 1 : 2;
    var artists = extendedInfo
            .where((element) => element['type'] == 'artist')
            .take(size)
            .toList() +
        extendedInfo
            .where((element) => element['type'] == 'group')
            .take(size)
            .toList();
    var width = min(MediaQuery.of(context).size.width / 3, 300.0);
    var height = max(
        160.0, width * gallery.files.first.height / gallery.files.first.width);
    debugPrint('w $width h $height');
    var totalHeight =
        height + (Theme.of(context).appBarTheme.toolbarHeight ?? 56);
    var smallText = TextButton.styleFrom(
      fixedSize: const Size.fromHeight(25),
      padding: const EdgeInsets.all(4),
      minimumSize: const Size(40, 25),
    );
    return SliverAppBar(
        backgroundColor: entry.value,
        leading: AppBar(backgroundColor: Colors.transparent),
        title:
            Hero(tag: 'gallery_${gallery.id}_name', child: Text(gallery.name)),
        pinned: true,
        expandedHeight: totalHeight,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.share))],
        flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
                child: Column(children: [
          SizedBox(height: Theme.of(context).appBarTheme.toolbarHeight ?? 56),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: SizedBox(
                    width: width,
                    height: height - 8,
                    child: Hero(
                        tag: 'gallery-thumb ${gallery.id}',
                        child: ThumbImageView(
                          ProxyNetworkImage(
                              dataStream: (chunkEvents) => api.fetchImageData(
                                    gallery.files.first,
                                    id: gallery.id,
                                    size: img.ThumbnaiSize.medium,
                                    refererUrl:
                                        'https://hitomi.la${gallery.urlEncode()}',
                                    onProcess: (now, total) => chunkEvents.add(
                                        ImageChunkEvent(
                                            cumulativeBytesLoaded: now,
                                            expectedTotalBytes: total)),
                                  ),
                              key: gallery.files.first.hash),
                          label: Text(gallery.files.length.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.deepOrange)),
                          aspectRatio: gallery.files.first.width /
                              gallery.files.first.height,
                        )))),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Hero(
                      tag: 'gallery_${gallery.id}_language',
                      child: SizedBox(
                          height: 28,
                          child: TagButton(label: {
                            ...Language(name: gallery.language ?? '').toMap(),
                            'translate':
                                mapLangugeType(context, gallery.language ?? '')
                          }, style: smallText, local: local))),
                  if (artists.isNotEmpty)
                    SizedBox(
                        height: 28,
                        child: Row(children: [
                          for (var artist in artists)
                            TagButton(
                                label: artist,
                                style: smallText,
                                commondPrefix: '--${artist['type']}',
                                local: local)
                        ])),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 8),
                        if (!kIsWeb)
                          Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: OutlinedButton(
                                      onPressed: netLoading || exist != null
                                          ? null
                                          : () async {
                                              await context
                                                  .read<GalleryManager>()
                                                  .addTask(
                                                      gallery.id.toString())
                                                  .then((value) => showSnackBar(
                                                      context,
                                                      AppLocalizations.of(
                                                              context)!
                                                          .addTaskSuccess))
                                                  .catchError(
                                                      (e) => debugPrint('$e'),
                                                      test: (error) => true);
                                            },
                                      child: Text(exist != null
                                          ? AppLocalizations.of(context)!
                                              .downloaded
                                          : AppLocalizations.of(context)!
                                              .download)))),
                        Expanded(
                          child: FilledButton(
                              onPressed: () => Navigator.of(context).pushNamed(
                                      GalleryViewer.routeName,
                                      arguments: {
                                        'gallery': exist ?? gallery,
                                        'local': exist != null,
                                      }),
                              child: Text(AppLocalizations.of(context)!.read)),
                        ),
                        const SizedBox(width: 8),
                      ]),
                  SizedBox(
                      height: 28,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Hero(
                                tag: 'gallery_${gallery.id}_type',
                                child: TagButton(label: {
                                  ...TypeLabel(gallery.type).toMap(),
                                  'translate': entry.key
                                }, style: smallText, local: local)),
                            Hero(
                                tag: 'gallery_${gallery.id}_date',
                                child: Text(
                                    format.format(format.parse(gallery.date))))
                          ])),
                ])),
          ])
        ]))));
  }
}
