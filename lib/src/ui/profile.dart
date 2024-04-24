import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../utils/proxy_netwrok_image.dart';
import 'common_view.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _UserProfileView();
  }
}

class _UserProfileView extends State<UserProfileView>
    with AutomaticKeepAliveClientMixin {
  final List<Gallery> history = [];
  final List<Gallery> likes = [];
  final List<Gallery> collection = [];
  late Hitomi api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var controller = context.read<SettingsController>();
    api = controller.hitomi();
    if (history.length + likes.length + collection.length == 0) {
      var types = [readMask, likeMask, bookMark];
      controller.manager.helper
          .selectSqlMultiResultAsync(
              'select id from UserLog where type=? limit 10',
              types.map((e) => [e]).toList())
          .then((value) {
            var r = value.values.map((e) => e.fold(<int>[],
                (previousValue, element) => previousValue..add(element['id'])));
            return r.toList();
          })
          .then((value) => Future.wait(value.map((e) => e
              .asStream()
              .asyncMap((event) => api.fetchGallery(event))
              .fold(
                  <Gallery>[], (previous, element) => previous..add(element)))))
          .then((value) => setState(() {
                history.addAll(value[0]);
                likes.addAll(value[1]);
                collection.addAll(value[2]);
              }));
    }
  }

  Widget _itemTitle(String title, int type) {
    return ListTile(
      title: Text(title, style: Theme.of(context).primaryTextTheme.titleLarge),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => UserProfleLogView(type: type, title: title))),
    );
  }

  Widget _galleryList(List<Gallery> list) {
    return SizedBox(
        height: 200,
        child: ListView.separated(
            itemBuilder: (context, index) {
              var gallery = list[index];
              return InkWell(
                  child: SizedBox(
                      width: 160,
                      child: Column(children: [
                        ThumbImageView(
                            ProxyNetworkImage(
                                dataStream: (chunkEvents) => api.fetchImageData(
                                      gallery.files.first,
                                      id: gallery.id,
                                      refererUrl:
                                          'https://hitomi.la${gallery.urlEncode()}',
                                      onProcess: (now, total) =>
                                          chunkEvents.add(ImageChunkEvent(
                                              cumulativeBytesLoaded: now,
                                              expectedTotalBytes: total)),
                                    ),
                                key: gallery.files.first.hash),
                            aspectRatio: 1),
                        Text(gallery.name, maxLines: 2, softWrap: true)
                      ])),
                  onTap: () => Navigator.of(context).pushNamed(
                      GalleryDetailsView.routeName,
                      arguments: {'gallery': gallery, 'local': false}));
            },
            separatorBuilder: (context, index) =>
                const SizedBox(width: 8, child: Divider()),
            itemCount: list.length,
            scrollDirection: Axis.horizontal));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _itemTitle(AppLocalizations.of(context)!.readHistory, readMask),
        _galleryList(history),
        _itemTitle(AppLocalizations.of(context)!.like, likeMask),
        _galleryList(likes),
        _itemTitle(AppLocalizations.of(context)!.collect, bookMark),
        _galleryList(collection),
      ],
    ))));
  }

  @override
  bool get wantKeepAlive => true;
}

class UserProfleLogView extends StatefulWidget {
  final int type;
  final String title;
  const UserProfleLogView({super.key, required this.type, required this.title});

  @override
  State<StatefulWidget> createState() {
    return _UserProfleLogView();
  }
}

class _UserProfleLogView extends State<UserProfleLogView> {
  final List<Gallery> data = [];
  late void Function(Gallery gallery) click;
  late Hitomi api;
  int page = 0;
  int totalCount = 0;
  late ScrollController scrollController;
  late PopupMenuButton<String> Function(Gallery gallery)? menusBuilder;
  void fetchDataFromDb() {
    context
        .read<SettingsController>()
        .manager
        .helper
        .querySql(
            'select COUNT(1) OVER() AS total_count, id from UserLog where type=? limit 25 offset ?',
            [
              widget.type,
              page * 25
            ])
        .then((value) => value.map((element) {
              totalCount = element['total_count'] as int;
              return element['id'] as int;
            }))
        .then((value) => value
            .asStream()
            .asyncMap((event) => api.fetchGallery(event))
            .fold(<Gallery>[], (previous, element) => data..add(element)))
        .then((value) => setState(() {
              if (value.isNotEmpty) {
                var insertList = value
                    .where((element) => data.every((g) => g.id != element.id));
                data.addAll(insertList);
                page++;
              }
            }));
  }

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    scrollController.addListener(handleScroll);
    menusBuilder = (gallery) => PopupMenuButton<String>(itemBuilder: (context) {
          return [
            PopupMenuItem(
                child: Text(AppLocalizations.of(context)!.delete),
                onTap: () => context
                        .read<SettingsController>()
                        .manager
                        .helper
                        .delete('UserLog', {
                      'id': gallery.id,
                      'type': widget.type
                    }).then((value) => setState(() {
                              data.removeWhere(
                                  (element) => element.id == gallery.id);
                            })))
          ];
        });
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.removeListener(handleScroll);
    scrollController.dispose();
  }

  void handleScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent &&
        data.length < totalCount) {
      fetchDataFromDb();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    api = context.read<SettingsController>().hitomi();
    click = (gallery) => Navigator.of(context).pushNamed(
        GalleryDetailsView.routeName,
        arguments: {'gallery': gallery, 'local': false});
    if (page == 0) {
      fetchDataFromDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
            child: Center(
                child: MaxWidthBox(
                    maxWidth: 1280,
                    child: GalleryListView(
                        data: data,
                        click: click,
                        api: api,
                        scrollController: scrollController,
                        menusBuilder: menusBuilder)))));
  }
}
