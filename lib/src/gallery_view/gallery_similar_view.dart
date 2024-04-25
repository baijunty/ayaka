import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

class GallerySimilaerView extends StatefulWidget {
  const GallerySimilaerView({super.key});
  static const routeName = '/gallery_similar';

  @override
  State<StatefulWidget> createState() {
    return _GallerySimilaerView();
  }
}

class _GallerySimilaerView extends State<GallerySimilaerView> {
  late Hitomi api;
  List<Gallery> data = [];
  late void Function(Gallery) click;
  CancelToken? _cancelToken;
  var netLoading = true;

  @override
  void initState() {
    super.initState();
    click = (g) => Navigator.of(context).pushNamed(GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': false});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    api = context.read<SettingsController>().hitomi();
    var gallery = ModalRoute.of(context)?.settings.arguments as Gallery;
    if (_cancelToken == null) {
      _cancelToken = CancelToken();
      api
          .findSimilarGalleryBySearch(gallery, token: _cancelToken)
          .then((value) => setState(() {
                netLoading = false;
                data = value.data;
              }))
          .catchError((e) {
        if (mounted) {
          setState(() {
            netLoading = false;
            context.showSnackBar('${AppLocalizations.of(context)!.failed}: $e');
          });
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _cancelToken?.cancel('dispose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
        ),
        body: Center(
            child: MaxWidthBox(
                maxWidth: 1200,
                child: netLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const CircularProgressIndicator(),
                            Text(AppLocalizations.of(context)!.loading)
                          ])
                    : data.isEmpty
                        ? Center(
                            child: Text(
                                AppLocalizations.of(context)!.emptyContent))
                        : GalleryListView(
                            data: data,
                            onRefresh: null,
                            click: click,
                            api: api,
                            menusBuilder: (g) =>
                                PopupMenuButton<String>(itemBuilder: (context) {
                                  return [
                                    PopupMenuItem(
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .download),
                                        onTap: () => context.addTask(g.id)),
                                  ];
                                })))));
  }
}
