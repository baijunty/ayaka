import 'dart:math';

import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/model/gallery_manager.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/animation_view.dart';
import 'package:card_loading/card_loading.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;
import '../utils/label_utils.dart';
import '../utils/proxy_netwrok_image.dart';
import '../utils/responsive_util.dart';

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
          context.showSnackBar('$e');
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
    context.readUserDb(gallery.id, readMask).then((value) {
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

  Widget imagesToolbar() {
    var api = controller.hitomi(localDb: local);
    return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
            color: Theme.of(context).colorScheme.background,
            padding: const EdgeInsets.all(4),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => setState(() {
                        _selected.clear();
                      }),
                  child: Text(AppLocalizations.of(context)!.cancel)),
              const SizedBox(width: 8),
              TextButton(
                  onPressed: () => setState(() {
                        _selected.clear();
                        _selected.addAll(gallery.files);
                      }),
                  child: Text(AppLocalizations.of(context)!.selectAll)),
              const SizedBox(width: 8),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: ((context) => AnimatedSaverDialog(
                            selected: _selected, api: api, gallery: gallery))));
                  },
                  child: Text(AppLocalizations.of(context)!.makeGif)),
              const SizedBox(width: 8),
              if (!kIsWeb)
                TextButton(
                    onPressed: () async {
                      await context
                          .read<GalleryManager>()
                          .addAdImageHash(_selected.map((e) => e.hash).toList())
                          .then((value) {
                        if (mounted) {
                          gallery.files.removeWhere(
                              (element) => _selected.contains(element));
                          setState(() {
                            context.showSnackBar(
                                AppLocalizations.of(context)!.success);
                          });
                        }
                      });
                    },
                    child: Text(AppLocalizations.of(context)!.markAdImg)),
            ])));
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
          child: Stack(children: [
            CustomScrollView(slivers: [
              GalleryDetailHead(
                  api: controller.hitomi(localDb: local),
                  gallery: gallery,
                  local: local,
                  extendedInfo: translates,
                  netLoading: netLoading,
                  exist: exists),
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
            ]),
            if (_selected.isNotEmpty) imagesToolbar()
          ])),
    )));
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

  void insertToDb(BuildContext context, int type) async {
    await context.insertToUserDb((exist ?? gallery).id, type);
  }

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    var format = DateFormat('yyyy-MM-dd');
    var size = currentDevice(context) == DeviceInfo.mobile ? 1 : 2;
    var artists = extendedInfo
        .where((element) => element['type'] == 'artist')
        .take(size)
        .toList();
    var groupes = extendedInfo
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
        actions: [
          IconButton(
              onPressed: () async {
                insertToDb(context, bookMark);
              },
              icon: const Icon(Icons.bookmark)),
          IconButton(
              onPressed: () async {
                insertToDb(context, likeMask);
              },
              icon: const Icon(Icons.favorite))
        ],
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
                                              await context.addTask(gallery.id);
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
                  if (artists.isNotEmpty || groupes.isNotEmpty)
                    SizedBox(
                        height: 28,
                        child: Row(children: [
                          for (var artist in artists)
                            TagButton(
                                label: artist,
                                style: smallText,
                                commondPrefix: '--${artist['type']}',
                                local: local,
                                icon: const Icon(Icons.person)),
                          for (var group in groupes)
                            TagButton(
                                label: group,
                                style: smallText,
                                commondPrefix: '--${group['type']}',
                                local: local,
                                icon: const Icon(Icons.group))
                        ])),
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
