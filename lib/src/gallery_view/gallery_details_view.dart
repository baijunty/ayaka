import 'dart:math';

import 'package:ayaka/src/gallery_view/gallery_viewer.dart';
import 'package:ayaka/src/model/gallery_manager.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/animation_view.dart';
import 'package:card_loading/card_loading.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;
import '../utils/label_utils.dart';
import '../utils/proxy_network_image.dart';
import '../utils/responsive_util.dart';

enum GalleryStatus { notExists, exists, upgrade }

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
  GalleryStatus status = GalleryStatus.notExists;
  bool netLoading = true;
  int? readedIndex;
  CancelToken? token;
  final List<img.Image> _selected = [];
  final List<Gallery> suggestGallerys = [];
  List<Map<String, dynamic>> translates = [];
  Future<void> _fetchTransLate() async {
    var api = controller.hitomi(localDb: true);
    await (status == GalleryStatus.exists
            ? Future.value(gallery)
            : context
                .read<GalleryManager>()
                .checkExist(gallery.id)
                .then((value) => value['value'] as List<dynamic>?)
                .then((value) async {
                if (value?.firstOrNull != null) {
                  gallery = await api.fetchGallery(value!.first, token: token);
                  var before = await controller
                      .hitomi()
                      .fetchGallery(value.first,
                          token: token, usePrefence: false)
                      .catchError((e) => gallery, test: (error) => true);
                  debugPrint(
                      'gallery id: ${gallery.id} compare to id ${value.first} before ${before.files.length} now len ${gallery.files.length}');
                  if (before.id != value.first ||
                      gallery.files.length > before.files.length) {
                    status = GalleryStatus.upgrade;
                  } else {
                    status = GalleryStatus.exists;
                  }
                }
                return gallery;
              }))
        .then((value) => api.translate(gallery.labels()))
        .then((value) {
      if (mounted) {
        setState(() {
          translates = value;
          netLoading = false;
        });
      }
    }).catchError((e) {
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
    if (token == null) {
      controller = context.read<SettingsController>();
      var args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      gallery = args['gallery'];
      bool local = args['local'] ?? false;
      if (local) {
        status = GalleryStatus.exists;
      }
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
        'gallery': gallery,
        'index': index,
        'local': status != GalleryStatus.notExists,
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
    var api = controller.hitomi(localDb: status != GalleryStatus.notExists);
    return Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
            opacity: _selected.isEmpty ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(4),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (!kIsWeb)
                    TextButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () async {
                                await context
                                    .read<GalleryManager>()
                                    .addAdImageHash(
                                        _selected.map((e) => e.hash).toList())
                                    .then((value) {
                                  if (mounted) {
                                    gallery.files.removeWhere((element) =>
                                        _selected.contains(element));
                                    setState(() {
                                      context.showSnackBar(
                                          AppLocalizations.of(context)!
                                              .success);
                                    });
                                  }
                                });
                              },
                        child: Text(AppLocalizations.of(context)!.markAdImg)),
                  const Spacer(),
                  TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(() {
                                _selected.clear();
                              }),
                      child: Text(AppLocalizations.of(context)!.cancel)),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(() {
                                _selected.clear();
                                _selected.addAll(gallery.files);
                              }),
                      child: Text(AppLocalizations.of(context)!.selectAll)),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: ((context) => AnimatedSaverDialog(
                                      selected: _selected,
                                      api: api,
                                      gallery: gallery))));
                            },
                      child: Text(AppLocalizations.of(context)!.makeGif)),
                ]))));
  }

  void fetchSuggestData(bool expand) async {
    if (expand && suggestGallerys.isEmpty) {
      return gallery.related?.isNotEmpty == true
          ? Future.wait(gallery.related!.map((id) => context
              .read<SettingsController>()
              .hitomi()
              .fetchGallery(id, usePrefence: false))).then((resp) {
              setState(() {
                suggestGallerys.addAll(resp);
              });
            }).catchError((e) {
              debugPrint('$e');
            }, test: (error) => true)
          : context.getSuggesution(gallery.id).then((resp) async {
              setState(() {
                suggestGallerys.addAll(resp);
              });
            }).catchError((e) {
              debugPrint('$e');
            }, test: (error) => true);
    }
  }

  @override
  Widget build(BuildContext context) {
    var api = controller.hitomi(localDb: status != GalleryStatus.notExists);
    var refererUrl = 'https://hitomi.la${gallery.urlEncode()}';
    var isDeskTop = context.currentDevice() == DeviceInfo.deskTop;
    var tagInfo = GalleryTagDetailInfo(
      gallery: gallery,
      extendedInfo: translates,
      netLoading: netLoading,
      readIndex: readedIndex,
      deskTop: isDeskTop,
      buildChildren: (children) => isDeskTop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children)
          : SliverList.list(children: children),
    );
    return Scaffold(
        body: SafeArea(
            child: Center(
      child: MaxWidthBox(
          maxWidth: 1280,
          child: LayoutBuilder(builder: (con, ctx) {
            return Stack(children: [
              CustomScrollView(key: ValueKey(gallery.id), slivers: [
                GalleryDetailHead(
                    key: ValueKey('head ${gallery.id}'),
                    manager: context.getCacheManager(
                        local: status != GalleryStatus.notExists),
                    gallery: gallery,
                    extendedInfo: translates,
                    netLoading: netLoading,
                    status: status,
                    readIndex: readedIndex,
                    languageChange: (id) async {
                      await context.progressDialogAction(api
                          .fetchGallery(id, usePrefence: false)
                          .then((value) => setState(() {
                                gallery = value;
                              }))
                          .catchError((e) {
                        if (context.mounted) {
                          context.showSnackBar('$e');
                        }
                      }, test: (error) => true));
                    },
                    tagInfo: isDeskTop ? tagInfo : null),
                if (!isDeskTop) tagInfo,
                if (context.read<SettingsController>().exntension)
                  SliverToBoxAdapter(
                      child: ExpansionTile(
                          title: Text(AppLocalizations.of(context)!.suggest),
                          onExpansionChanged: fetchSuggestData,
                          children: [SugguestView(gallery, suggestGallerys)])),
                SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 256),
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
                          child: Center(
                              child: ThumbImageView(
                            CacheImage(
                                manager: context.getCacheManager(
                                    local: status != GalleryStatus.notExists),
                                image: image,
                                refererUrl: refererUrl,
                                id: gallery.id.toString()),
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
                          )));
                    })
              ]),
              imagesToolbar()
            ]);
          })),
    )));
  }
}

class GalleryDetailHead extends StatelessWidget {
  final Gallery gallery;
  final List<Map<String, dynamic>> extendedInfo;
  final bool netLoading;
  final GalleryStatus status;
  final CacheManager manager;
  final GalleryTagDetailInfo? tagInfo;
  final int? readIndex;
  final Function(int id) languageChange;
  const GalleryDetailHead(
      {super.key,
      required this.manager,
      required this.gallery,
      required this.extendedInfo,
      required this.netLoading,
      required this.status,
      required this.languageChange,
      required this.readIndex,
      this.tagInfo});

  Widget headThumbImage(BuildContext context) {
    return Hero(
        tag: 'gallery-thumb ${gallery.id}',
        child: ThumbImageView(
          CacheImage(
              manager: manager,
              image: gallery.files.first,
              refererUrl: 'https://hitomi.la${gallery.urlEncode()}',
              id: gallery.id.toString(),
              size: img.ThumbnaiSize.medium),
          label: Text(gallery.files.length.toString(),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.deepOrange)),
          aspectRatio: gallery.files.first.width / gallery.files.first.height,
        ));
  }

  Widget actionButton(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const SizedBox(width: 8),
      if (!kIsWeb)
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: netLoading
                    ? null
                    : switch (status) {
                        GalleryStatus.notExists => OutlinedButton(
                            onPressed: () async {
                              await context.addTask(gallery.id);
                            },
                            child:
                                Text(AppLocalizations.of(context)!.download)),
                        GalleryStatus.exists => OutlinedButton(
                            onPressed: () async {
                              await context.addTask(gallery.id);
                            },
                            child: Text(AppLocalizations.of(context)!.fix)),
                        GalleryStatus.upgrade => OutlinedButton(
                            onPressed: () async {
                              await context.addTask(gallery.id);
                            },
                            child: Text(AppLocalizations.of(context)!.update)),
                      })),
      Expanded(
        child: FilledButton(
            onPressed: () => Navigator.of(context)
                    .pushNamed(GalleryViewer.routeName, arguments: {
                  'gallery': gallery,
                  'local': status != GalleryStatus.notExists,
                }),
            child: Text(AppLocalizations.of(context)!.read)),
      ),
      const SizedBox(width: 8),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    var entry = mapGalleryType(context, gallery.type);
    int size;
    switch (context.currentDevice()) {
      case DeviceInfo.mobile:
        size = 2;
      case DeviceInfo.tablet:
        size = 5;
      case DeviceInfo.deskTop:
        size = 8;
    }
    var artists = extendedInfo
        .where((element) => element['type'] == 'artist')
        .take(size)
        .toList();
    var groupes = extendedInfo
        .where((element) => element['type'] == 'group')
        .take(size - artists.length)
        .toList();
    var mediaData = MediaQuery.of(context);
    var width =
        min(mediaData.size.width * mediaData.devicePixelRatio / 3, 300.0);
    var minHeight =
        tagInfo != null ? width - 32 : width / mediaData.devicePixelRatio + 24;
    var height = width *
        gallery.files.first.height /
        gallery.files.first.width /
        mediaData.devicePixelRatio;
    if (height < minHeight) {
      height = minHeight;
    }
    var totalHeight =
        height + (Theme.of(context).appBarTheme.toolbarHeight ?? 56);
    var userLanges = context.getManager().config.languages;
    var lanuages = gallery.languages
        ?.where((lang) => userLanges.any((element) => element == lang.name))
        .toList();
    debugPrint(
        '${gallery.id} screenW ${mediaData.size} ration ${mediaData.devicePixelRatio} w $width h $height totalH $totalHeight ${gallery.files.first.height / gallery.files.first.width}');
    return SliverAppBar(
        backgroundColor: entry.value,
        leading: AppBar(
            backgroundColor: Colors.transparent,
            leading: BackButton(
              onPressed: () => Navigator.of(context).pop(readIndex),
            )),
        title:
            Hero(tag: 'gallery_${gallery.id}_name', child: Text(gallery.name)),
        pinned: true,
        expandedHeight: totalHeight,
        actions: [
          IconButton(
              onPressed: () async {
                await context.insertToUserDb((gallery).id, lateReadMark,
                    showResult: true);
              },
              icon: const Icon(Icons.playlist_add_circle),
              tooltip: AppLocalizations.of(context)!.readLater),
          IconButton(
              onPressed: () async {
                await context.insertToUserDb((gallery).id, bookMask,
                    showResult: true);
              },
              icon: const Icon(Icons.bookmark),
              tooltip: AppLocalizations.of(context)!.collect)
        ],
        flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
                child: Column(children: [
          SizedBox(height: Theme.of(context).appBarTheme.toolbarHeight ?? 56),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                    width: width / mediaData.devicePixelRatio,
                    height: height - 8,
                    child: headThumbImage(context))),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  actionButton(context),
                  if (artists.isNotEmpty || groupes.isNotEmpty)
                    SizedBox(
                        height: 28,
                        child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (var artist in artists)
                                TagButton(
                                    label: artist,
                                    style: smallText,
                                    commondPrefix: '--${artist['type']}',
                                    icon: const Icon(Icons.person)),
                              for (var group in groupes)
                                TagButton(
                                    label: group,
                                    style: smallText,
                                    commondPrefix: '--${group['type']}',
                                    icon: const Icon(Icons.group))
                            ])),
                  SizedBox(
                      height: 40,
                      child:
                          ListView(scrollDirection: Axis.horizontal, children: [
                        Row(children: [
                          TagButton(label: {
                            ...TypeLabel(gallery.type).toMap(),
                            'translate': entry.key
                          }),
                          const SizedBox(width: 16),
                          if (lanuages?.isNotEmpty == true)
                            DropdownButton<int>(
                                items: [
                                  if (lanuages!.every((element) =>
                                      element.galleryid!.toInt() != gallery.id))
                                    DropdownMenuItem(
                                        value: gallery.id,
                                        child: Text(mapLangugeType(
                                            context, gallery.language ?? ''))),
                                  for (var language in lanuages)
                                    DropdownMenuItem(
                                        value: language.galleryid!.toInt(),
                                        child: Text(mapLangugeType(
                                            context, language.name))),
                                ],
                                value: gallery.id,
                                onChanged: (id) {
                                  if (id != null) {
                                    languageChange(id);
                                  }
                                })
                          else
                            Text(mapLangugeType(
                                context, gallery.language ?? '')),
                          const SizedBox(width: 8),
                          Text(formater.formatString(gallery.date)),
                        ])
                      ])),
                  if (tagInfo != null) tagInfo!,
                ])),
          ])
        ]))));
  }
}

class GalleryTagDetailInfo extends StatelessWidget {
  final Gallery gallery;
  final List<Map<String, dynamic>> extendedInfo;
  final bool netLoading;
  final Widget Function(List<Widget> children) buildChildren;
  final int? readIndex;
  final bool deskTop;
  const GalleryTagDetailInfo(
      {super.key,
      required this.gallery,
      required this.extendedInfo,
      required this.netLoading,
      required this.buildChildren,
      required this.deskTop,
      this.readIndex});

  String findMatchLabel(Label label) {
    var translate = extendedInfo.firstWhereOrNull((element) =>
        element['type'] == label.type &&
        element['name'] == label.name)?['translate'];
    return translate ?? label.name;
  }

  Widget _buildIndexView(int readIndex) {
    return Stack(children: [
      LinearProgressIndicator(value: (readIndex + 1) / gallery.files.length),
      Align(
          alignment: Alignment.bottomRight,
          child: Text('${(readIndex + 1)}/${gallery.files.length}'))
    ]);
  }

  Widget _serialInfo(BuildContext context, List<Map<String, dynamic>> series,
      List<Map<String, dynamic>> characters) {
    var child = Wrap(children: [
      for (var serial in series) TagButton(label: serial),
      for (var character in characters) TagButton(label: character),
    ]);

    var title = Text(
        '${AppLocalizations.of(context)!.series} & ${AppLocalizations.of(context)!.character}');
    return deskTop
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ListTile(title: title), child])
        : ExpansionTile(title: title, children: [child]);
  }

  Widget _otherTagInfo(
      BuildContext context,
      List<Map<String, dynamic>>? females,
      List<Map<String, dynamic>>? males,
      List<Map<String, dynamic>>? tags) {
    var title = Text(AppLocalizations.of(context)!.tag);
    var child = Wrap(children: [
      if (females != null)
        for (var female in females)
          TagButton(
            label: female,
          ),
      if (males != null)
        for (var male in males)
          TagButton(
            label: male,
          ),
      if (tags != null)
        for (var tag in tags)
          TagButton(
            label: tag,
          ),
    ]);
    return deskTop
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ListTile(title: title), child])
        : ExpansionTile(title: title, children: [child]);
  }

  @override
  Widget build(BuildContext context) {
    var typeList =
        extendedInfo.groupListsBy((element) => element['type'] as String);
    return buildChildren([
      if (readIndex != null) _buildIndexView(readIndex!),
      if (netLoading) const CardLoading(height: 40),
      if (!netLoading &&
          [typeList['series'], typeList['character']]
              .every((element) => element != null))
        _serialInfo(context, typeList['series']!.take(10).toList(),
            typeList['character']!.take(20).toList()),
      if (!netLoading &&
          [typeList['female'], typeList['male'], typeList['tag']]
              .any((element) => element != null))
        _otherTagInfo(context, typeList['female']?.take(20).toList(),
            typeList['male'], typeList['tag']?.take(20).toList())
    ]);
  }
}

class SugguestView extends StatefulWidget {
  final Gallery gallery;
  final List<Gallery> suggestGallerys;
  const SugguestView(this.gallery, this.suggestGallerys, {super.key});
  @override
  State<StatefulWidget> createState() {
    return _SuggestView();
  }
}

class _SuggestView extends State<SugguestView> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: widget.suggestGallerys.isEmpty ? 0 : 120,
        child: ListView.separated(
          itemCount: widget.suggestGallerys.length,
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(),
          itemBuilder: (context, index) {
            var gallery = widget.suggestGallerys[index];
            return SizedBox(
                width: 120,
                child: InkWell(
                    child: Column(children: [
                      SizedBox(
                          height: 100,
                          child: ThumbImageView(
                              CacheImage(
                                  manager: context.getCacheManager(
                                      local: widget.gallery.related == null),
                                  image: gallery.files.first,
                                  refererUrl:
                                      'https://hitomi.la${gallery.urlEncode()}',
                                  id: gallery.id.toString(),
                                  size: img.ThumbnaiSize.smaill),
                              label: Text(gallery.files.length.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: Colors.deepOrange)),
                              aspectRatio: 1)),
                      Center(
                          widthFactor: 80,
                          child: Text(gallery.name,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true)),
                    ]),
                    onTap: () => Navigator.of(context).pushNamed(
                        GalleryDetailsView.routeName,
                        arguments: {'gallery': gallery, 'local': true})));
          },
          scrollDirection: Axis.horizontal,
        ));
  }
}
