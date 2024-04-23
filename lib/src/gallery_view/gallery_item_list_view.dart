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
  final SortEnum? sortEnum;
  const GalleryItemListView(
      {super.key,
      required this.api,
      required this.label,
      required this.local,
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
  late ScrollController scrollController;
  Future<void> _fetchData({bool refresh = false}) async {
    token = CancelToken();
    return widget.api
        .viewByTag(fromString(widget.label['type'], widget.label['name']),
            page: _page, sort: widget.sortEnum, token: token)
        .then((value) => setState(() {
              var insertList = value.data
                  .where((element) => data.every((g) => g.id != element.id));
              refresh ? data.insertAll(0, insertList) : data.addAll(insertList);
              _page++;
              totalCount = value.totalCount;
              totalPage = (value.totalCount / 25).ceil();
            }))
        .catchError((e) {
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
                                context.showSnackBar(
                                    AppLocalizations.of(context)!.success);
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
          '$_page/$totalPage ${AppLocalizations.of(context)!.loading}');
      await _fetchData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    settingsController = context.watch<SettingsController>();
    if (_page == 1) {
      _fetchData();
    }
    debugPrint(
        'didChangeDependencies ${widget.api.runtimeType} $_page ${data.length}');
  }

  Widget _bodyContentList() {
    return Center(
        child: MaxWidthBox(
            maxWidth: 1200,
            child: GalleryListView(
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
                menusBuilder: menuBuilder)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _bodyContentList();
  }

  @override
  bool get wantKeepAlive => true;
}
