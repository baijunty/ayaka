import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../model/task_controller.dart';

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
  final EasyRefreshController controller = EasyRefreshController();
  late void Function(Gallery) click;
  CancelToken? _cancelToken;
  var netLoading = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    api = context.read<SettingsController>().hitomi();
    click = (g) => Navigator.of(context).pushNamed(GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': false});
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
          showSnackBar(context, '$e');
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
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
                    : GalleryListView(
                        controller: controller,
                        data: data,
                        onLoad: null,
                        onRefresh: null,
                        click: click,
                        api: api,
                        menusBuilder: (g) =>
                            PopupMenuButton<String>(itemBuilder: (context) {
                              return [
                                PopupMenuItem(
                                    child: Text(
                                        AppLocalizations.of(context)!.download),
                                    onTap: () => context
                                        .read<TaskController>()
                                        .addTask(g.id)
                                        .then((value) => showSnackBar(
                                            context,
                                            AppLocalizations.of(context)!
                                                .success))),
                              ];
                            })))));
  }
}
