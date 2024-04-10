import 'dart:math';

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../model/task_controller.dart';
import '../settings/settings_controller.dart';
import '../ui/common_view.dart';
import 'gallery_details_view.dart';
import 'gallery_similar_view.dart';

class GallerySearchResultView extends StatefulWidget {
  const GallerySearchResultView({super.key});

  static const routeName = '/gallery_search_result_view';
  @override
  State<StatefulWidget> createState() {
    return _GallerySearchResultView();
  }
}

class _GallerySearchResultView extends State<GallerySearchResultView> {
  List<Gallery> data = [];
  var _page = 1;
  int totalPage = 1;
  late void Function(Gallery) click;
  late Hitomi api;
  late EasyRefreshController _controller;
  late List<Map<String, dynamic>> _selected;
  final _ids = <int>[];
  late PopupMenuButton<String> Function(Gallery gallery)? menuBuilder;
  late bool local;
  var title = '';
  CancelToken? token;
  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
        controlFinishRefresh: true, controlFinishLoad: true);
    menuBuilder = kIsWeb
        ? null
        : (g) => PopupMenuButton<String>(itemBuilder: (context) {
              return [
                if (!local)
                  PopupMenuItem(
                      child: Text(AppLocalizations.of(context)!.download),
                      onTap: () => context
                          .read<TaskController>()
                          .addTask(g)
                          .then((value) => showSnackBar(
                              context, AppLocalizations.of(context)!.success))),
                PopupMenuItem(
                    child: Text(AppLocalizations.of(context)!.findSimiler),
                    onTap: () => Navigator.of(context).pushNamed(
                        GallerySimilaerView.routeName,
                        arguments: g)),
                if (local)
                  PopupMenuItem(
                      child: Text(AppLocalizations.of(context)!.delete),
                      onTap: () => context
                          .read<TaskController>()
                          .cancelTask(g.id)
                          .then((value) => setState(() {
                                data.removeWhere(
                                    (element) => element.id == g.id);
                                showSnackBar(context,
                                    AppLocalizations.of(context)!.success);
                              })))
              ];
            });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    token?.cancel('dispose');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _selected = args['tags'];
    local = args['local'];
    click = (g) => Navigator.pushNamed(context, GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': local});
    api = context.watch<SettingsController>().hitomi(localDb: local);
    title = _selected
        .fold(
            StringBuffer(),
            (previousValue, element) => previousValue
              ..write(element['translate'])
              ..write(','))
        .toString();
    if (data.isEmpty) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    token = CancelToken();
    if (_page <= totalPage) {
      Future<List<int>> idsFuture;
      if (25 * _page > _ids.length) {
        idsFuture = api
            .search(
                _selected
                    .where((element) => element['include'] == true)
                    .map((e) => fromString(e['type'], e['name']))
                    .toList(),
                exclude: _selected
                    .where((element) => element['include'] == false)
                    .map((e) => fromString(e['type'], e['name']))
                    .toList(),
                page: _page,
                token: token)
            .then((value) {
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
          .then((value) => Future.wait(value.map(
              (e) => api.fetchGallery(e, usePrefence: false, token: token))))
          .then((value) {
        setState(() {
          data.addAll(value);
          _page++;
          _controller.finishLoad();
          _controller.finishRefresh();
        });
      }).catchError((e) {
        showSnackBar(context, '$e');
        _controller.finishLoad();
        _controller.finishRefresh();
      }, test: (error) => true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: Text(title),
        ),
        body: Center(
            child: data.isEmpty
                ? Text(AppLocalizations.of(context)!.emptyContent,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.red))
                : GalleryListView(
                    controller: _controller,
                    data: data,
                    onLoad: () async {
                      if (_page <= totalPage) {
                        await _fetchData();
                      } else {
                        showSnackBar(
                            context, AppLocalizations.of(context)!.endOfPage);
                        _controller.finishLoad();
                        _controller.finishRefresh();
                      }
                    },
                    onRefresh: null,
                    click: click,
                    api: api,
                    menusBuilder: menuBuilder)));
  }
}
