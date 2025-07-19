import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';
import 'package:ayaka/src/localization/app_localizations.dart';
import '../settings/settings_controller.dart';
import '../ui/common_view.dart';
import 'gallery_details_view.dart';
import 'gallery_similar_view.dart';

class GallerySearchResultView extends StatefulWidget {
  final Hitomi api;
  final List<Map<String, dynamic>> selected;
  final bool local;
  final int startPage;
  final SortEnum dateDesc;
  const GallerySearchResultView(
      {super.key,
      required this.api,
      required this.selected,
      required this.local,
      required this.dateDesc,
      this.startPage = 1});
  @override
  State<StatefulWidget> createState() {
    return _GallerySearchResultView();
  }
}

class _GallerySearchResultView extends State<GallerySearchResultView>
    with AutomaticKeepAliveClientMixin {
  List<Gallery> data = [];
  var _page = 1;
  late void Function(Gallery) click;
  final _ids = <int>[];
  late PopupMenuButton<String> Function(Gallery gallery)? menuBuilder;
  late ScrollController scrollController;
  var totalCount = 0;
  CancelToken? token;
  var netLoading = false;
  final readIndexMap = <int, int?>{};
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
    scrollController = ScrollController();
    scrollController.addListener(handleScroll);
    menuBuilder = kIsWeb
        ? null
        : (g) => PopupMenuButton<String>(itemBuilder: (context) {
              return [
                PopupMenuItem(
                    child: Text(AppLocalizations.of(context)!.download),
                    onTap: () => context.addTask(g.id)),
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
          '$_page/${(totalCount / 25).ceil()} ${AppLocalizations.of(context)!.loading}');
      await context.progressDialogAction(_fetchData());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 1) {
      _page = widget.startPage;
      _fetchData();
      setState(() {});
    }
  }

  Future<void> _fetchData() async {
    token = CancelToken();
    Future<List<int>> idsFuture;
    netLoading = true;
    if (_page == widget.startPage || _ids.length < totalCount) {
      idsFuture = widget.api
          .search(
              widget.selected
                      .where((element) => (element['include'] ?? true) == true)
                      .map((e) => fromString(e['type'], e['name']))
                      .toList() +
                  context
                      .read<SettingsController>()
                      .config
                      .languages
                      .map((e) => Language(name: e))
                      .toList(),
              exclude: context
                  .read<SettingsController>()
                  .config
                  .excludes
                  .map((e) => fromString(e.type, e.name))
                  .toList(),
              page: _page,
              sort: widget.dateDesc,
              token: token)
          .then((value) {
        totalCount = value.totalCount;
        debugPrint('search found items $totalCount ');
        _ids.addAll(value.data);
        return _ids;
      });
    } else {
      idsFuture = Future.value(_ids);
    }
    idsFuture
        .then((value) => value.sublist(
            min((_page - 1) * 25, value.length), min(value.length, _page * 25)))
        .then((value) => Future.wait(value.map((e) =>
            widget.api.fetchGallery(e, usePrefence: false, token: token))))
        .then((value) {
      var labels = value.fold(<Label>[],
          (previousValue, element) => previousValue..addAll(element.labels()));
      return widget.api.translate(labels).then((trans) {
        for (var g in labels) {
          g.translate = trans.firstWhereOrNull(
              (l) => g.type == l['type'] && g.name == l['name']);
        }
        return value;
      });
    }).then((value) {
      return Future.wait(
              value.map((e) => context.readUserDb(e.id, readHistoryMask)))
          .then((result) => result.foldIndexed(
              readIndexMap,
              (index, previous, element) =>
                  previous..[value[index].id] = element))
          .then((map) => value);
    }).then((value) {
      setState(() {
        data.addAll(value);
        _page++;
        netLoading = false;
      });
    }).catchError((e) {
      if (mounted) {
        setState(() {
          context.showSnackBar('$e');
        });
        netLoading = false;
      }
    }, test: (error) => true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(children: [
      data.isEmpty && !netLoading
          ? Center(
              child: InkWell(
                  onTap: _fetchData,
                  child: Text(AppLocalizations.of(context)!.emptyContent,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.red))))
          : GalleryListView(
              data: data,
              onRefresh: null,
              click: click,
              manager: context.getCacheManager(local: widget.local),
              scrollController: scrollController,
              readIndexMap: readIndexMap,
              menusBuilder: menuBuilder),
      if (netLoading) const Center(child: CircularProgressIndicator())
    ]);
  }

  @override
  bool get wantKeepAlive => true;
}
