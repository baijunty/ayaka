import 'dart:io';

import 'package:ayaka/src/gallery_view/gallery_details_view.dart'
    show GalleryDetailsView;
import 'package:ayaka/src/gallery_view/gallery_similar_view.dart'
    show GallerySimilaerView;
import 'package:ayaka/src/localization/app_localizations.dart'
    show AppLocalizations;
import 'package:ayaka/src/ui/common_view.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart' show Gallery;
import 'package:hitomi/lib.dart' show readHistoryMask, IntParse;

class GalleryImageSearch extends StatefulWidget {
  final String path;
  static const routeName = '/gallery_image_search';
  const GalleryImageSearch({super.key, required this.path});

  @override
  State createState() => _GalleryImageSearchState();
}

class _GalleryImageSearchState extends State<GalleryImageSearch> {
  List<Gallery> data = [];
  late void Function(Gallery) click;
  late PopupMenuButton<String> Function(Gallery gallery)? menuBuilder;
  CancelToken? token;
  bool netLoading = false;
  final readIndexMap = <int, int?>{};
  Future<void> _fetchData() async {
    token = CancelToken();
    netLoading = true;
    context
        .querrByImage(await File(widget.path).readAsBytes())
        .then(
          (d) => setState(() {
            data.addAll(d);
            netLoading = false;
          }),
        )
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
        context,
        GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': true},
      );
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
    menuBuilder = kIsWeb
        ? null
        : (g) => PopupMenuButton<String>(
            itemBuilder: (context) {
              var userLangs = context.getConfig().languages;
              var langs = g.languages?.where(
                (element) =>
                    userLangs.any((lang) => lang == element.name) &&
                    element.galleryid != g.id.toString(),
              );
              return [
                PopupMenuItem(
                  child: Text(AppLocalizations.of(context)!.download),
                  onTap: () => context.addTask(g.id),
                ),
                if (langs?.isNotEmpty == true)
                  for (var lang in langs!)
                    PopupMenuItem(
                      child: Text(
                        '${AppLocalizations.of(context)!.download}${lang.languageLocalname}',
                      ),
                      onTap: () => context.addTask(lang.galleryid!.toInt()),
                    ),
                PopupMenuItem(
                  child: Text(AppLocalizations.of(context)!.findSimiler),
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(GallerySimilaerView.routeName, arguments: g),
                ),
                PopupMenuItem(
                  child: Text(AppLocalizations.of(context)!.delete),
                  onTap: () => context
                      .deleteTask(g.id)
                      .then(
                        (value) => setState(() {
                          data.removeWhere((element) => element.id == g.id);
                        }),
                      ),
                ),
              ];
            },
          );
  }

  @override
  void dispose() {
    super.dispose();
    token?.cancel('dispose');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (data.isEmpty) {
      _fetchData();
    }
  }

  Widget _bodyContentList() {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: GalleryListView(
          data: data,
          onRefresh: null,
          click: click,
          manager: context.getCacheManager(local: true),
          scrollController: null,
          readIndexMap: readIndexMap,
          menusBuilder: menuBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _bodyContentList(),
        if (netLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
