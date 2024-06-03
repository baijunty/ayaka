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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import '../ui/common_view.dart';
import '../utils/common_define.dart';
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
        (read is int ? Future.value(read) : context.readUserDb(g.id, readMask))
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
                if (!widget.local)
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
        data.length < totalCount) {
      context.showSnackBar(
          '$_page/${(totalCount / 25).ceil()} ${AppLocalizations.of(context)!.loading}');
      await _fetchData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 1) {
      _page = widget.startPage;
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    token = CancelToken();
    netLoading = true;
    Future<List<int>> idsFuture;
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
              exclude: widget.selected
                  .where((element) => element['include'] == false)
                  .map((e) => fromString(e['type'], e['name']))
                  .toList(),
              page: _page,
              sort: widget.dateDesc,
              token: token)
          .then((value) {
        totalCount = value.totalCount;
        debugPrint(
            'search found items $totalCount sample ${value.data.take(5).toList()}');
        _ids.addAll(value.data);
        return _ids;
      });
    } else {
      idsFuture = Future.value(_ids);
    }
    idsFuture
        .then((value) => value.sublist(
            min((_page - widget.startPage) * 25, value.length),
            min(value.length, (_page - widget.startPage + 1) * 25)))
        .then((value) => Future.wait(value.map((e) =>
            widget.api.fetchGallery(e, usePrefence: false, token: token))))
        .then((value) => context
            .getManager()
            .translateLabel(value.fold(
                <Label>[],
                (previousValue, element) =>
                    previousValue..addAll(element.labels())))
            .then((trans) => value))
        .then((value) {
      return Future.wait(value.map((e) => context.readUserDb(e.id, readMask)))
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
          netLoading = false;
          context.showSnackBar('$e');
        });
      }
    }, test: (error) => true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return data.isEmpty
        ? Center(
            child: netLoading
                ? const CircularProgressIndicator()
                : InkWell(
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
            api: widget.api,
            scrollController: scrollController,
            readIndexMap: readIndexMap,
            menusBuilder: menuBuilder);
  }

  @override
  bool get wantKeepAlive => true;
}
