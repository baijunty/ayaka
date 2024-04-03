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
  final CancelToken _cancelToken = CancelToken();
  late Future<List<Gallery>> _findSimilar;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    api = context.read<SettingsController>().hitomi();
    click = (g) => Navigator.of(context).pushNamed(GalleryDetailsView.routeName,
        arguments: {'gallery': g, 'local': false});
    var gallery = ModalRoute.of(context)?.settings.arguments as Gallery;
    _findSimilar = api
        .findSimilarGalleryBySearch(gallery, token: _cancelToken)
        .then((value) => value.data);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    _cancelToken.cancel('dispose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
        ),
        body: FutureBuilder(
            key: ValueKey(data),
            future: _findSimilar,
            builder: (context, snap) {
              if (snap.hasData) {
                return snap.data!.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context)!.emptyContent))
                    : buildGalleryListView(controller, snap.data!, () => null,
                        () => null, click, api,
                        menusBuilder: (g) =>
                            PopupMenuButton<String>(itemBuilder: (context) {
                              return [
                                PopupMenuItem(
                                    child: Text(
                                        AppLocalizations.of(context)!.download),
                                    onTap: () => context
                                        .read<TaskController>()
                                        .addTask(g)
                                        .then((value) => showSnackBar(
                                            context,
                                            AppLocalizations.of(context)!
                                                .success))),
                              ];
                            }));
              } else if (snap.hasError) {
                return Center(
                    child: Text(snap.error.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.red)));
              } else {
                return Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.loading)
                  ],
                ));
              }
            }));
  }
}
