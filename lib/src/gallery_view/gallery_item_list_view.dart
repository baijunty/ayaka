import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
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

/// Displays a list of SampleItems.
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
  Future<void> _fetchData({bool refresh = false}) async {
    token = CancelToken();
    netLoading = true;
    return widget.api
        .viewByTag(fromString(widget.label['type'], widget.label['name']),
            page: _page, sort: widget.sortEnum, token: token)
        .then((value) => context
            .getManager()
            .translateLabel(value.data.fold(
                <Label>[],
                (previousValue, element) =>
                    previousValue..addAll(element.labels())))
            .then((trans) => value))
        .then((value) {
          totalCount = value.totalCount;
          totalPage = (value.totalCount / 25).ceil();
          return value.data
              .where((element) => data.every((g) => g.id != element.id));
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
    click = (g) => Navigator.pushNamed(context, GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': widget.local});
    _page = widget.startPage;
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
      await _fetchData();
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
          await _fetchData(refresh: true);
          _page = before;
        },
        click: click,
        api: widget.api,
        scrollController: scrollController,
        menusBuilder: menuBuilder);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _bodyContentList();
  }

  @override
  bool get wantKeepAlive => true;
}
