import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';
import 'package:hitomi/gallery/image.dart' as img show Image;
import '../model/gallery_manager.dart';
import '../utils/proxy_network_image.dart';
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
  final List<Gallery> todoCollection = [];
  late Hitomi api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var controller = context.read<SettingsController>();
    api = controller.hitomi(localDb: true);
    if (history.length + likes.length + todoCollection.length == 0) {
      var types = [readHistoryMask, bookMarkMask, lateReadMark];
      controller.manager.helper
          .selectSqlMultiResultAsync(
              'select id from UserLog where type=? ORDER by date desc limit 10 ',
              types.map((e) => [e]).toList())
          .then((value) {
            var r = value.values.map((e) => e.fold(<int>[],
                (previousValue, element) => previousValue..add(element['id'])));
            return r.toList();
          })
          .then((value) => Future.wait(value.map((e) => e
              .asStream()
              .asyncMap((event) => api.fetchGallery(event, usePrefence: false))
              .fold(
                  <Gallery>[], (previous, element) => previous..add(element)))))
          .then((value) {
            if (mounted) {
              setState(() {
                history.addAll(value[0]);
                likes.addAll(value[1]);
                todoCollection.addAll(value[2]);
              });
            }
          });
    }
  }

  Widget _itemTitle(String title, int type) {
    return ListTile(
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      tileColor: Theme.of(context).colorScheme.primaryContainer,
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => UserProfileLogView(type: type, title: title))),
    );
  }

  Widget _galleryList(List<Gallery> list) {
    return SizedBox(
        height: 170,
        child: ListView.separated(
            itemBuilder: (context, index) {
              var gallery = list[index];
              return InkWell(
                  child: SizedBox(
                      width: 120,
                      child: Column(children: [
                        ThumbImageView(
                            CacheImage(
                                manager: context.getCacheManager(local: true),
                                image: gallery.files.first,
                                refererUrl:
                                    'https://hitomi.la${gallery.urlEncode()}',
                                id: gallery.id.toString()),
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
        _itemTitle(AppLocalizations.of(context)!.readHistory, readHistoryMask),
        _galleryList(history),
        _itemTitle(AppLocalizations.of(context)!.collect, bookMarkMask),
        _galleryList(likes),
        _itemTitle(AppLocalizations.of(context)!.readLater, lateReadMark),
        _galleryList(todoCollection),
        ListTile(
          title: Text(AppLocalizations.of(context)!.adImage,
              style: Theme.of(context).textTheme.titleLarge),
          tileColor: Theme.of(context).colorScheme.primaryContainer,
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AdImageView())),
        ),
      ],
    ))));
  }

  @override
  bool get wantKeepAlive => true;
}

class AdImageView extends StatefulWidget {
  const AdImageView({super.key});
  @override
  State<StatefulWidget> createState() {
    return _AdImageView();
  }
}

class _AdImageView extends State<AdImageView> {
  final List<String> adImages = [];
  late Hitomi api;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var controller = context.read<SettingsController>();
    api = controller.hitomi();
    if (adImages.isEmpty) {
      adImages.addAll(controller.manager.adImage);
    }
  }

  Future<bool> syncAdImage() async {
    var controller = context.read<SettingsController>();
    if (adImages.isNotEmpty &&
        controller.manager.config.remoteHttp.isNotEmpty) {
      var size = adImages.length;
      await controller.manager.dio
          .post('${controller.config.remoteHttp}/sync',
              options: Options(
                  headers: {'Content-Type': 'application/json'},
                  responseType: ResponseType.json),
              data: {
                'auth': controller.config.auth,
                'mark': admarkMask,
                'returnValue': true,
                'content': adImages.toList()
              })
          .then((data) => data.data! as Map<String, dynamic>)
          .then((map) => map['content'] as List)
          .then((list) => list.map((str) => str as String))
          .then((d) => setState(() {
                var set = d.toSet();
                set.addAll(controller.manager.adImage);
                adImages.addAll(set);
                debugPrint('ad image length  ${adImages.length}');
              }))
          .catchError((e) => debugPrint('sync ad image error $e'),
              test: (error) => true);
      if (mounted && size != adImages.length) {
        await context.read<GalleryManager>().addAdImageHash(adImages.toList());
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.adImage),
            actions: [
              IconButton(
                  onPressed: () async =>
                      await context.progressDialogAction(syncAdImage()),
                  icon: const Icon(Icons.sync))
            ]),
        body: SafeArea(
            child: Center(
                child: MaxWidthBox(
                    maxWidth: 1280,
                    child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 320),
                        itemCount: adImages.length,
                        itemBuilder: (context, index) {
                          var image = adImages[index];
                          return GestureDetector(
                            child: ThumbImageView(CacheImage(
                                manager: context.getCacheManager(),
                                image: img.Image(
                                    hash: image,
                                    hasavif: 0,
                                    width: 0,
                                    height: 0,
                                    name: 'test.jpg'),
                                refererUrl: 'https://hitomi.la',
                                id: '1')),
                            onLongPress: () => context.showSnackBar(image),
                          );
                        })))));
  }
}

class UserProfileLogView extends StatefulWidget {
  final int type;
  final String title;
  const UserProfileLogView(
      {super.key, required this.type, required this.title});

  @override
  State<StatefulWidget> createState() {
    return _UserProfileLogView();
  }
}

class _UserProfileLogView extends State<UserProfileLogView> {
  final List<Gallery> data = [];
  late void Function(Gallery gallery) click;
  late Hitomi api;
  int page = 0;
  int totalCount = 0;
  String? query;
  late ScrollController scrollController;
  late PopupMenuButton<String> Function(Gallery gallery)? menusBuilder;
  final readIndexMap = <int, int?>{};
  Future<void> fetchDataFromDb() async {
    var sqlite = context.getSqliteHelper();
    sqlite
        .querySql(
            'select COUNT(1) OVER() AS total_count, id from UserLog where type=? ORDER by date desc limit 25 offset ?',
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
            .asyncMap((event) => api
                .fetchGallery(event, usePrefence: false)
                .then((g) => g.id == event ? g : g.copyWith(id: event)))
            .fold(<Gallery>[], (previous, element) => data..add(element)))
        .then((value) {
          return Future.wait(
                  value.map((e) => context.readUserDb(e.id, readHistoryMask)))
              .then((result) => result.foldIndexed(
                  readIndexMap,
                  (index, previous, element) =>
                      previous..[value[index].id] = element))
              .then((map) => value);
        })
        .then((value) => setState(() {
              if (value.isNotEmpty) {
                var insertList = value
                    .where((element) => data.every((g) => g.id != element.id));
                data.addAll(insertList);
                page++;
              }
            }));
  }

  Future<bool> syncDelete(int id) async {
    var controller = context.read<SettingsController>();
    if (controller.manager.config.remoteHttp.isNotEmpty) {
      return controller.manager.dio
          .post('${controller.config.remoteHttp}/sync',
              options: Options(
                  headers: {'Content-Type': 'application/json'},
                  responseType: ResponseType.json),
              data: {
                'auth': controller.config.auth,
                'mark': widget.type,
                'content': [{'id': -id}]
              })
          .then((data) => data.data! as Map<String, dynamic>)
          .then((map) => map['success'] as bool)
          .catchError((e) => false, test: (error) => true);
    }
    return false;
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
                    .delete('UserLog', {'id': gallery.id, 'type': widget.type})
                    .then((b) => syncDelete(gallery.id))
                    .then((value) => setState(() {
                          data.removeWhere(
                              (element) => element.id == gallery.id);
                        })))
          ];
        });
  }

  void clearData() async {
    await context
        .showConfirmDialog(AppLocalizations.of(context)!.clearDataWarn)
        .then((value) async {
      if (mounted && value == true) {
        await context
            .getSqliteHelper()
            .delete('UserLog', {'type': widget.type});
        setState(() {
          data.clear();
          page = 0;
          totalCount = 0;
        });
      }
    });
  }

  Future<bool> syncData() async {
    var sqlite = context.getSqliteHelper();
    var controller = context.read<SettingsController>();
    return sqlite
        .querySql('select id,value,type,content,date from UserLog where type=?',
            [widget.type])
        .then((value) =>
            value.fold(<Map<String, dynamic>>[], (acc, row) => acc..add(row)))
        .then((values) => controller.manager.dio
            .post('${controller.config.remoteHttp}/sync',
                options: Options(
                    headers: {'Content-Type': 'application/json'},
                    responseType: ResponseType.json),
                data: {
                  'auth': controller.config.auth,
                  'mark': widget.type,
                  'returnValue': true,
                  'content': values
                })
            .then((resp) {
              return resp.data!;
            })
            .then((data) => data['content'] as List)
            .then((list) =>
                list.map((str) => str as Map<String, dynamic>).toList())
            .then((d) {
              return controller.manager.helper.excuteSqlMultiParams(
                  'replace into UserLog(id,value,type,content,date) values (?,?,?,?,?)',
                  d
                      .map((e) => [
                            e['id'],
                            e['value'],
                            e['type'],
                            e['content'],
                            e['date']
                          ])
                      .toList());
            })
            .then((v) async {
              data.clear();
              page = 0;
              readIndexMap.clear();
              await fetchDataFromDb();
              return v;
            })
            .catchError((err) {
              debugPrint('err $err');
              return false;
            }, test: (error) => true));
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
    api = context.read<SettingsController>().hitomi(localDb: true);
    click = (g) async {
      var read = await Navigator.pushNamed(
          context, GalleryDetailsView.routeName,
          arguments: {'gallery': g, 'local': false});
      setState(() {
        readIndexMap[g.id] = read as int?;
      });
    };
    if (page == 0) {
      fetchDataFromDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    var controller = context.read<SettingsController>();
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (controller.remoteLib)
              IconButton(
                  onPressed: () async {
                    context.progressDialogAction(syncData()
                        .then((r) => setState(() {
                              if (mounted) {
                                if (r) {
                                  context.showSnackBar(
                                      AppLocalizations.of(context)!.success);
                                } else {
                                  context.showSnackBar(
                                      AppLocalizations.of(context)!.failed);
                                }
                              }
                            }))
                        .catchError((e, stack) {
                      debugPrint('Error: $e with stack trace:  $stack');
                    }, test: (error) => false));
                  },
                  icon: const Icon(Icons.sync)),
            IconButton(onPressed: clearData, icon: const Icon(Icons.clear))
          ],
        ),
        body: SafeArea(
            child: Center(
                child: MaxWidthBox(
                    maxWidth: 1280,
                    child: GalleryListView(
                        data: data,
                        click: click,
                        manager: context.getCacheManager(local: true),
                        readIndexMap: readIndexMap,
                        scrollController: scrollController,
                        menusBuilder: menusBuilder)))));
  }
}
