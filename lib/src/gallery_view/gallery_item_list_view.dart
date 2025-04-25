import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../settings/settings_controller.dart';
import 'gallery_similar_view.dart';

class GalleryItemListView extends StatefulWidget {
  final Hitomi api;
  final Map<String, dynamic> label;
  final bool local;
  final int startPage;
  final SortEnum? sortEnum;
  const GalleryItemListView(
      {super.key,
      required this.api,
      required this.label,
      required this.local,
      this.startPage = 1,
      this.sortEnum});

  @override
  State<StatefulWidget> createState() => _GalleryListView();
}

class _GalleryListView extends State<GalleryItemListView>
    with AutomaticKeepAliveClientMixin {
  List<Gallery> data = [];
  var _page = 1;
  int totalPage = 1;
  late void Function(Gallery) click;
  late PopupMenuButton<String> Function(Gallery gallery)? menuBuilder;
  CancelToken? token;
  late SettingsController settingsController;
  var totalCount = 0;
  bool netLoading = false;
  late ScrollController scrollController;
  final readIndexMap = <int, int?>{};
  Future<void> _fetchData({bool refresh = false}) async {
    token = CancelToken();
    netLoading = true;
    widget.api
        .viewByTag(fromString(widget.label['type'], widget.label['name']),
            page: _page, sort: widget.sortEnum, token: token)
        .then((value) {
          var labels = value.data.fold(
              <Label>[],
              (previousValue, element) =>
                  previousValue..addAll(element.labels()));
          return widget.api.translate(labels).then((trans) {
            for (var g in labels) {
              g.translate = trans.firstWhereOrNull(
                  (l) => g.type == l['type'] && g.name == l['name']);
            }
            return value;
          });
        })
        .then((value) {
          totalCount = value.totalCount;
          totalPage = (value.totalCount / 25).ceil();
          return value.data
              .where((element) => data.every((g) => g.id != element.id))
              .toList();
        })
        .then((value) {
          return Future.wait(
                  value.map((e) => context.readUserDb(e.id, readHistoryMask)))
              .then((result) => result.foldIndexed(
                  readIndexMap,
                  (index, previous, element) =>
                      previous..[value[index].id] = element))
              .then((map) => value);
        })
        .then((value) => setState(() {
              refresh ? data.insertAll(0, value) : data.addAll(value);
              _page++;
              netLoading = false;
            }))
        .catchError((e) {
          debugPrint('$e');
          netLoading = false;
          if (mounted) {
            context.showSnackBar('err $e');
          }
        }, test: (error) => true);
  }

  @override
  void initState() {
    super.initState();
    click = (g) async {
      var read = await Navigator.pushNamed(
          context, GalleryDetailsView.routeName,
          arguments: {'gallery': g, 'local': widget.local});
      if (mounted) {
        (read is int
                ? Future.value(read)
                : context.readUserDb(g.id, readHistoryMask))
            .then((value) {
          setState(() {
            readIndexMap[g.id] = value;
          });
        });
      }
    };
    _page = widget.startPage;
    scrollController = ScrollController();
    scrollController.addListener(handleScroll);
    menuBuilder = kIsWeb
        ? null
        : (g) => PopupMenuButton<String>(itemBuilder: (context) {
              var userLangs = context.getConfig().languages;
              var langs = g.languages?.where((element) =>
                  userLangs.any((lang) => lang == element.name) &&
                  element.galleryid != g.id.toString());
              return [
                PopupMenuItem(
                    child: Text(AppLocalizations.of(context)!.download),
                    onTap: () => context.addTask(g.id)),
                if (langs?.isNotEmpty == true)
                  for (var lang in langs!)
                    PopupMenuItem(
                        child: Text(
                            '${AppLocalizations.of(context)!.download}${lang.languageLocalname}'),
                        onTap: () => context.addTask(lang.galleryid!.toInt())),
                PopupMenuItem(
                    child: Text(AppLocalizations.of(context)!.findSimiler),
                    onTap: () => Navigator.of(context).pushNamed(
                        GallerySimilaerView.routeName,
                        arguments: g)),
                if (widget.local)
                  PopupMenuItem(
                      child: Text(AppLocalizations.of(context)!.delete),
                      onTap: () =>
                          context.deleteTask(g.id).then((value) => setState(() {
                                totalCount -= 1;
                                data.removeWhere(
                                    (element) => element.id == g.id);
                              })))
              ];
            });
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.removeListener(handleScroll);
    scrollController.dispose();
    token?.cancel('dispose');
  }

  void handleScroll() async {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent &&
        data.length < totalCount &&
        !netLoading) {
      context.showSnackBar(
          '$_page/$totalPage ${AppLocalizations.of(context)!.loading}');
      await context.progressDialogAction(_fetchData());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    settingsController = context.watch<SettingsController>();
    if (data.isEmpty) {
      _fetchData();
    }
  }

  Widget _bodyContentList() {
    return GalleryListView(
        data: data,
        onRefresh: () async {
          var before = _page;
          _page = 1;
          await context.progressDialogAction(_fetchData(refresh: true));
          _page = before;
        },
        click: click,
        manager: context.getCacheManager(local: widget.local),
        scrollController: scrollController,
        readIndexMap: readIndexMap,
        menusBuilder: menuBuilder);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(children: [
      _bodyContentList(),
      if (netLoading) const Center(child: CircularProgressIndicator())
    ]);
  }

  @override
  bool get wantKeepAlive => true;
}
