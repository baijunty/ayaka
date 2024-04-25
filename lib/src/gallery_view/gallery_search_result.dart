import 'dart:math';

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
import 'gallery_details_view.dart';
import 'gallery_similar_view.dart';

class GallerySearchResultView extends StatefulWidget {
  final Hitomi api;
  final List<Map<String, dynamic>> selected;
  final bool local;
  const GallerySearchResultView(
      {super.key,
      required this.api,
      required this.selected,
      required this.local});
  @override
  State<StatefulWidget> createState() {
    return _GallerySearchResultView();
  }
}

class _GallerySearchResultView extends State<GallerySearchResultView>
    with AutomaticKeepAliveClientMixin {
  List<Gallery> data = [];
  var _page = 1;
  int totalPage = 1;
  late void Function(Gallery) click;
  final _ids = <int>[];
  late PopupMenuButton<String> Function(Gallery gallery)? menuBuilder;
  late ScrollController scrollController;
  var totalCount = 0;
  CancelToken? token;
  var netLoading = false;
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
                          context.cancelTask(g.id).then((value) => setState(() {
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
          '$_page/$totalPage ${AppLocalizations.of(context)!.loading}');
      await _fetchData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 1) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    token = CancelToken();
    if (_page <= totalPage) {
      netLoading = true;
      Future<List<int>> idsFuture;
      debugPrint('search $_page and ids len ${_ids.length}');
      if (_page == 1 || _ids.length < totalCount) {
        idsFuture = widget.api
            .search(
                widget.selected
                        .where(
                            (element) => (element['include'] ?? true) == true)
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
                token: token)
            .then((value) {
          totalCount = value.totalCount;
          totalPage = (value.totalCount / 25).ceil();
          _ids.addAll(value.data);
          return _ids;
        });
      } else {
        idsFuture = Future.value(_ids);
      }
      idsFuture
          .then((value) => value.sublist(min(_page * 25 - 25, value.length),
              min(value.length, _page * 25)))
          .then((value) => Future.wait(value.map((e) =>
              widget.api.fetchGallery(e, usePrefence: false, token: token))))
          .then((value) {
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
            menusBuilder: menuBuilder);
  }

  @override
  bool get wantKeepAlive => true;
}
