import 'dart:async';
import 'dart:math';

import 'package:ayaka/src/gallery_view/gallery_tabview.dart';
import 'package:ayaka/src/utils/proxy_netwrok_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart' as img show ThumbnaiSize;
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/gallery_manager.dart';
import '../settings/settings_controller.dart';
import '../utils/common_define.dart';
import '../utils/label_utils.dart';

class ThumbImageView extends StatelessWidget {
  final ImageProvider provider;
  final Widget? label;
  final double aspectRatio;
  const ThumbImageView(this.provider,
      {super.key, this.label, this.aspectRatio = 9 / 16});

  Widget loadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    return loadingProgress == null
        ? child
        : Center(
            child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null));
  }

  Widget errorBuilder(context, error, stackTrace) {
    return const Icon(Icons.error);
  }

  Widget frameBuilder(BuildContext context, Widget child, int? frame,
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
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AspectRatio(
        aspectRatio: max(aspectRatio, 0.65),
        child: Image(
          image: provider,
          errorBuilder: errorBuilder,
          loadingBuilder: loadingBuilder,
          frameBuilder: frameBuilder,
          fit: BoxFit.cover,
        ),
      ),
      if (label != null)
        SizedBox(
            width: 40,
            height: 40,
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
  final List<Gallery> data;
  final Future<dynamic> Function()? onRefresh;
  final void Function(Gallery gallery) click;
  final Hitomi api;
  final ScrollController? scrollController;
  final PopupMenuButton<String> Function(Gallery gallery)? menusBuilder;

  const GalleryListView(
      {super.key,
      required this.data,
      this.onRefresh,
      required this.click,
      required this.api,
      this.scrollController,
      this.menusBuilder});

  Widget dataList() {
    return LayoutBuilder(builder: (context, cons) {
      return MasonryGridView.count(
          controller: scrollController,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          crossAxisCount: max(cons.maxWidth ~/ 550, 1),
          itemCount: data.length,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            final item = data[index];
            return GalleryInfo(
              key: ValueKey(item.id),
              gallery: item,
              click: click,
              api: api,
              menus: menusBuilder?.call(item),
            );
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return onRefresh != null
        ? RefreshIndicator.adaptive(onRefresh: onRefresh!, child: dataList())
        : dataList();
  }
}

class GalleryInfo extends StatelessWidget {
  final Gallery gallery;
  final Hitomi api;
  final void Function(Gallery) click;
  final PopupMenuButton<String>? menus;
  const GalleryInfo(
      {super.key,
      required this.gallery,
      required this.click,
      required this.api,
      required this.menus});

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    var image = gallery.files.first;
    return LayoutBuilder(builder: (context, cons) {
      return InkWell(
          key: ValueKey(gallery.id),
          onTap: () => click(gallery),
          child: Container(
            color: entry.value,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MaxWidthBox(
                  maxWidth: min(cons.maxWidth / 3, 300),
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
                          aspectRatio: image.width / image.height))),
              Expanded(
                  child: Stack(children: [
                Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Hero(
                              tag: 'gallery_${gallery.id}_name',
                              child: Text(gallery.name,
                                  maxLines: 2,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true))),
                      const SizedBox(width: 8),
                      if (gallery.artists?.first.translate != null)
                        TagButton(
                            label: gallery.artists!.first.translate!,
                            style: smallText),
                      const SizedBox(width: 8),
                      buildTypeAndDate(context, gallery, entry.key),
                    ]),
                if (menus != null)
                  Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                          children: [const SizedBox(height: 48), menus!]))
              ])),
            ]),
          ));
    });
  }
}

Widget buildTypeAndDate(BuildContext context, Gallery gallery, String type) {
  return SizedBox(
      height: 28,
      child: Row(children: [
        Hero(
            tag: 'gallery_${gallery.id}_type',
            child: TagButton(
                label: {...TypeLabel(gallery.type).toMap(), 'translate': type},
                style: smallText)),
        const SizedBox(width: 16),
        Hero(
            tag: 'gallery_${gallery.id}_language',
            child: Text(mapLangugeType(context, gallery.language ?? ''))),
        const SizedBox(width: 16),
        Hero(
            tag: 'gallery_${gallery.id}_date',
            child: Text(formater.formatString(gallery.date))),
      ]));
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
  final ButtonStyle? style;
  final String? commondPrefix;
  final Icon? icon;
  const TagButton(
      {super.key,
      required this.label,
      this.style,
      this.commondPrefix,
      this.icon});

  @override
  Widget build(BuildContext context) {
    var button = TextButton(
        style: style ?? Theme.of(context).textButtonTheme.style,
        onLongPress: () => showModalBottomSheet(
            context: context,
            builder: (context) =>
                TagDetail(tag: label, commondPrefix: commondPrefix)),
        onPressed: () => Navigator.of(context)
                .pushNamed(GalleryTabView.routeName, arguments: {
              'tags': [label]
            }),
        child: Text('${label['translate'] ?? label['name']}'));
    return icon == null ? button : Row(children: [icon!, button]);
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
    var dio = context.read<SettingsController>().manager.dio;
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
                padding: const EdgeInsets.only(
                    left: 16, top: 8, right: 16, bottom: 8),
                child: Row(children: [
                  const Expanded(child: Divider()),
                  Text('${tag['translate']}'),
                  const SizedBox(width: 8),
                  if (tag['count'] != null)
                    Text(
                        '${AppLocalizations.of(context)!.downloaded}:${tag['count']} at ${formater.formatString(tag['date'])}'),
                  if (commondPrefix != null)
                    IconButton(
                        onPressed: () async => taskControl
                                .addTask('$commondPrefix "${tag['name']}"')
                                .then((value) {
                              Navigator.of(context).pop();
                              context.showSnackBar(
                                  AppLocalizations.of(context)!.addTaskSuccess);
                            }),
                        icon: const Icon(Icons.download)),
                  const Expanded(child: Divider()),
                ]))
          ]),
          SliverGrid.extent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var url in imgs)
                  Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: Image(
                          image: ProxyNetworkImage(
                              dataStream: (chunkEvents) =>
                                  dio.httpInvoke<List<int>>(url.value,
                                      onProcess: (now, total) =>
                                          chunkEvents.add(ImageChunkEvent(
                                              cumulativeBytesLoaded: now,
                                              expectedTotalBytes: total))),
                              key: url.value)))
              ]),
          SliverList.list(children: [
            const SizedBox(height: 8),
            Center(
                child: RichText(
                    text: TextSpan(children: [
              for (var url in text)
                TextSpan(
                    text: url.key,
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

extension ContextAction on BuildContext {
  Future<void> addTask(int id) async {
    return read<GalleryManager>()
        .addTask(id.toString())
        .then(
            (value) => showSnackBar(AppLocalizations.of(this)!.addTaskSuccess))
        .catchError((e) => debugPrint('$e'), test: (error) => true);
  }

  Future<void> deleteTask(int id) async {
    return read<GalleryManager>()
        .deleteTask(id)
        .then((value) => showSnackBar(AppLocalizations.of(this)!.success))
        .catchError((e) => debugPrint('$e'), test: (error) => true);
  }

  Future<void> cancelTask(int id) async {
    return read<GalleryManager>()
        .cancelTask(id)
        .then((value) => showSnackBar(AppLocalizations.of(this)!.success))
        .catchError((e) => debugPrint('$e'), test: (error) => true);
  }

  void showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(this).showSnackBar(SnackBar(
          content: Text(msg, style: Theme.of(this).textTheme.labelMedium),
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(this).colorScheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          )));
    }
  }

  Future<void> insertToUserDb(int id, int type,
      {int data = 0, String? content, List<int>? extension}) async {
    return getSqliteHelper()
        .insertUserLog(id, type,
            mark: data, content: content, extension: extension ?? [])
        .then((value) => debugPrint('$value'))
        .catchError((e) => debugPrint('$e'), test: (error) => true);
  }

  SqliteHelper getSqliteHelper() {
    return read<SettingsController>().manager.helper;
  }

  TaskManager getManager() {
    return read<SettingsController>().manager;
  }

  Future<int?> readUserDb(int id, int type, {int? defaultValue}) async {
    return read<SettingsController>()
        .manager
        .helper
        .readlData<int>('UserLog', 'mark', {'id': id, 'type': type})
        .then((value) => value ?? defaultValue)
        .catchError((e) {
          debugPrint('$e');
          return defaultValue;
        }, test: (error) => true);
  }

  Future<bool?> showConfirmDialog(String msg) async {
    return showDialog(
        context: this,
        builder: (context) {
          return AlertDialog.adaptive(
              content: Center(child: Text(msg)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(AppLocalizations.of(context)!.confirm)),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppLocalizations.of(context)!.cancel)),
              ]);
        });
  }

  Future<String?> showDialogInput(
      {required TextField textField, String? inputHint}) async {
    return showDialog<String?>(
        context: this,
        builder: (context) => AlertDialog.adaptive(
                title:
                    Text(inputHint ?? AppLocalizations.of(context)!.inputHint),
                content: textField,
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(textField.controller?.text);
                      },
                      child: Text(AppLocalizations.of(context)!.confirm)),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(AppLocalizations.of(context)!.cancel))
                ]));
  }
}
