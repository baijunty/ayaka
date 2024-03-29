import 'dart:math';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../settings/settings_controller.dart';
import '../ui/common_view.dart';
import 'gallery_details_view.dart';

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
  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
        controlFinishRefresh: true, controlFinishLoad: true);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _selected = args['tags'];
    var locol = args['local'];
    click = (g) => Navigator.pushNamed(context, GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': locol});
    api = context.watch<SettingsController>().hitomi(localDb: locol);
    if (data.isEmpty) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (_page <= totalPage) {
      if (25 * _page > _ids.length) {
        await api
            .search(
                _selected
                    .where((element) => element['include'] == true)
                    .map((e) => fromString(e['type'], e['name']))
                    .toList(),
                exclude: _selected
                    .where((element) => element['include'] == false)
                    .map((e) => fromString(e['type'], e['name']))
                    .toList(),
                page: _page)
            .then((value) {
          totalPage = (value.totalCount / 25).ceil();
          _ids.addAll(value.data);
        });
      }
      await Future.value(_ids.sublist(
              min(_page * 25 - 25, _ids.length), min(_ids.length, _page * 25)))
          .then((value) => Future.wait(
              value.map((e) => api.fetchGallery(e, usePrefence: false))))
          .then((value) {
        setState(() {
          data.addAll(value);
          debugPrint('total $totalPage ${value.length} ${data.length}');
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
        ),
        body: buildGalleryListView(_controller, data, () async {
          if (_page <= totalPage) {
            await _fetchData();
          } else {
            showSnackBar(context, AppLocalizations.of(context)!.endOfPage);
            _controller.finishLoad();
            _controller.finishRefresh();
          }
        }, () async {
          _ids.clear();
          data.clear();
          _page = 1;
          await _fetchData();
        }, click, api));
  }
}
