import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:easy_refresh/easy_refresh.dart';
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
class GalleryListView extends StatefulWidget {
  final bool localDb;
  const GalleryListView({super.key, this.localDb = false});

  static const routeName = '/gallery_list';

  @override
  State<StatefulWidget> createState() => _GalleryListView();
}

class _GalleryListView extends State<GalleryListView> {
  List<Gallery> data = [];
  late Map<String, dynamic> _label;
  var _page = 1;
  var showAppBar = false;
  int totalPage = 1;
  late void Function(Gallery) click;
  late Hitomi api;
  late EasyRefreshController _controller;
  late PopupMenuButton<String> Function(Gallery gallery) menuBuilder;
  Future<void> _fetchData() async {
    return api
        .viewByTag(fromString(_label['type'], _label['name']), page: _page)
        .then((value) {
      setState(() {
        data.addAll(value.data
            .where((element) => data.every((g) => g.id != element.id)));
        _page++;
        totalPage = (value.totalCount / 25).ceil();
        _controller.finishLoad();
        _controller.finishRefresh();
      });
    }).catchError((e) {
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
        arguments: {'gallery': g, 'local': widget.localDb});
    _controller = EasyRefreshController(
        controlFinishRefresh: true, controlFinishLoad: true);
    menuBuilder = (g) => PopupMenuButton<String>(itemBuilder: (context) {
          var settings = context.read<SettingsController>();
          return [
            if (!widget.localDb)
              PopupMenuItem(
                  child: Text(AppLocalizations.of(context)!.download),
                  onTap: () => settings.manager
                      .parseCommandAndRun(g.id.toString())
                      .then((value) => showSnackBar(
                          context, AppLocalizations.of(context)!.success))),
            PopupMenuItem(
                child: Text(AppLocalizations.of(context)!.findSimiler),
                onTap: () => Navigator.of(context)
                    .pushNamed(GallerySimilaerView.routeName, arguments: g)),
            if (widget.localDb)
              PopupMenuItem(
                  child: Text(AppLocalizations.of(context)!.delete),
                  onTap: () => settings.manager
                      .parseCommandAndRun('-d ${g.id}')
                      .then((value) => setState(() {
                            data.removeWhere((element) => element.id == g.id);
                            showSnackBar(
                                context, AppLocalizations.of(context)!.success);
                          })))
          ];
        });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _label = (args?['tag'] ?? QueryText('').toMap());
    showAppBar = args != null;
    var settings = context.watch<SettingsController>();
    api = settings.hitomi(localDb: widget.localDb);
    if (data.isEmpty) {
      _fetchData();
    }
  }

  Widget _bodyContentList() {
    return buildGalleryListView(_controller, data, () async {
      if (_page <= totalPage) {
        await _fetchData();
      } else {
        showSnackBar(context, AppLocalizations.of(context)!.endOfPage);
        _controller.finishLoad();
        _controller.finishRefresh();
      }
    }, () async {
      var before = _page;
      _page = 1;
      await _fetchData();
      _page = before;
    }, click, api, menusBuilder: menuBuilder);
  }

  @override
  Widget build(BuildContext context) {
    return showAppBar
        ? Scaffold(
            appBar: AppBar(
                leading:
                    BackButton(onPressed: () => Navigator.of(context).pop()),
                title: Text('${_label['translate']}')),
            body: _bodyContentList())
        : _bodyContentList();
  }
}
