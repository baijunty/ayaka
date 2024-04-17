import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/model/task_controller.dart';
import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../settings/settings_controller.dart';
import 'gallery_search.dart';
import 'gallery_similar_view.dart';

/// Displays a list of SampleItems.
class GalleryItemListView extends StatefulWidget {
  final bool localDb;
  const GalleryItemListView({super.key, this.localDb = false});

  static const routeName = '/gallery_list';

  @override
  State<StatefulWidget> createState() => _GalleryListView();
}

class _GalleryListView extends State<GalleryItemListView> {
  List<Gallery> data = [];
  late Map<String, dynamic> _label;
  var _page = 1;
  var showAppBar = false;
  int totalPage = 1;
  late void Function(Gallery) click;
  bool local = false;
  late EasyRefreshController _controller;
  late PopupMenuButton<String> Function(Gallery gallery)? menuBuilder;
  SortEnum? sortEnum;
  CancelToken? token;
  late SettingsController settingsController;
  var totalCount = 0;
  Hitomi? _api;
  Hitomi get api {
    _api ??= settingsController.hitomi(localDb: local);
    return _api!;
  }

  Future<void> _fetchData({bool refresh = false}) async {
    token = CancelToken();
    return api
        .viewByTag(fromString(_label['type'], _label['name']),
            page: _page, sort: sortEnum, token: token)
        .then((value) => setState(() {
              var insertList = value.data
                  .where((element) => data.every((g) => g.id != element.id));
              refresh ? data.insertAll(0, insertList) : data.addAll(insertList);
              _page++;
              totalCount = value.totalCount;
              totalPage = (value.totalCount / 25).ceil();
              _controller.finishLoad();
              _controller.finishRefresh();
            }))
        .catchError((e) {
      _controller.finishLoad();
      _controller.finishRefresh();
      if (mounted) {
        showSnackBar(context, 'err $e');
      }
    }, test: (error) => true);
  }

  @override
  void initState() {
    super.initState();
    click = (g) => Navigator.pushNamed(context, GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': local});
    _controller = EasyRefreshController(
        controlFinishRefresh: true, controlFinishLoad: true);
    menuBuilder = kIsWeb
        ? null
        : (g) => PopupMenuButton<String>(itemBuilder: (context) {
              return [
                PopupMenuItem(
                    child: Text(AppLocalizations.of(context)!.download),
                    onTap: () => context
                        .read<GalleryManager>()
                        .addTask(g.id.toString())
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
                          .read<GalleryManager>()
                          .deleteTask(g.id)
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
    if (_api == null) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _label = (args?['tag'] ?? QueryText('').toMap());
      showAppBar = args != null;
      local = (args?['local'] ?? widget.localDb);
      settingsController = context.watch<SettingsController>();
      _fetchData();
    }
  }

  Widget _bodyContentList() {
    return Column(children: [
      Row(children: [
        if (showAppBar)
          BackButton(onPressed: () => Navigator.of(context).pop()),
        Expanded(child: GallerySearch(localDb: local)),
        if (kIsWeb)
          IconButton(
              onPressed: () => setState(() {
                    settingsController.updateThemeMode(
                        settingsController.themeMode != ThemeMode.light
                            ? ThemeMode.light
                            : ThemeMode.dark);
                  }),
              icon: Icon(settingsController.themeMode == ThemeMode.light
                  ? Icons.light_mode
                  : Icons.mode_night)),
        PopupMenuButton<SortEnum?>(
            itemBuilder: (context) {
              if (local) {
                return <PopupMenuEntry<SortEnum?>>[
                  PopupMenuItem(
                      value: null,
                      child: Text(AppLocalizations.of(context)!.dateDefault)),
                  PopupMenuItem(
                      value: SortEnum.Date,
                      child: Text(AppLocalizations.of(context)!.dateAsc)),
                  PopupMenuItem(
                      value: SortEnum.DateDesc,
                      child: Text(AppLocalizations.of(context)!.dateDesc)),
                ];
              }
              return <PopupMenuEntry<SortEnum>>[
                PopupMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.dateDefault)),
                PopupMenuItem(
                    value: SortEnum.week,
                    child: Text(AppLocalizations.of(context)!.popWeek)),
                PopupMenuItem(
                    value: SortEnum.month,
                    child: Text(AppLocalizations.of(context)!.popMonth)),
                PopupMenuItem(
                    value: SortEnum.year,
                    child: Text(AppLocalizations.of(context)!.popYear)),
              ];
            },
            onSelected: (value) => setState(() {
                  data.clear();
                  _page = 1;
                  sortEnum = value;
                  _fetchData();
                }),
            icon: const Icon(Icons.sort)),
        if (!kIsWeb && showAppBar)
          PopupMenuButton<bool>(
              itemBuilder: (context) {
                return <PopupMenuEntry<bool>>[
                  PopupMenuItem(
                      value: false,
                      child: Text(AppLocalizations.of(context)!.network)),
                  PopupMenuItem(
                      value: true,
                      child: Text(AppLocalizations.of(context)!.local))
                ];
              },
              onSelected: (value) async {
                local = value;
                _api = settingsController.hitomi(localDb: value);
                _page = 1;
                data.clear();
                await _fetchData();
              },
              icon: Icon(local ? Icons.local_library : Icons.network_wifi))
      ]),
      Expanded(
          child: GalleryListView(
              controller: _controller,
              data: data,
              onLoad: data.length < totalCount
                  ? () async {
                      showSnackBar(context,
                          '$_page/$totalPage ${AppLocalizations.of(context)!.loading}');
                      await _fetchData();
                    }
                  : null,
              onRefresh: () async {
                var before = _page;
                _page = 1;
                await _fetchData(refresh: true);
                _page = before;
              },
              click: click,
              api: api,
              menusBuilder: menuBuilder))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return showAppBar
        ? Scaffold(
            body: SafeArea(
                child: Center(
                    child: MaxWidthBox(
                        maxWidth: 1280, child: _bodyContentList()))))
        : _bodyContentList();
  }
}
