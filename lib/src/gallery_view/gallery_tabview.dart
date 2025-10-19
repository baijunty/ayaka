import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/gallery_view/gallery_search.dart';
import 'package:ayaka/src/gallery_view/gallery_search_result.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/common_define.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:ayaka/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import 'gallery_item_list_view.dart';

class GalleryTabView extends StatefulWidget {
  static const routeName = '/gallery_list';

  const GalleryTabView({super.key});

  @override
  State<StatefulWidget> createState() {
    return _GalleryTabView();
  }
}

class _GalleryTabView extends State<GalleryTabView>
    with SingleTickerProviderStateMixin {
  late SettingsController controller;
  late List<Map<String, dynamic>> tags;
  late TabController tabController;
  late PageController pageController;
  late ScrollController scrollController;
  late Function(Map<String, dynamic>) onSearch;
  final FocusNode _focusNode = FocusNode();
  List<Widget> children = [];
  List<Widget> tabs = [];
  List<MapEntry<int, SortEnum>> pageKey =
      List.filled(2, const MapEntry(1, SortEnum.Default));
  @override
  void initState() {
    super.initState();
    tabController = TabController(length: kIsWeb ? 1 : 2, vsync: this);
    pageController = PageController(initialPage: 0);
    scrollController = ScrollController();
    onSearch = (Map<String, dynamic> args) async {
      if (args['gallery'] != null) {
        await Navigator.of(context).pushNamed(GalleryDetailsView.routeName,
            arguments: {'gallery': args['gallery'], 'local': args['local']});
      } else {
        await Navigator.of(context).pushNamed(GalleryTabView.routeName,
            arguments: {'tags': args['tags']});
      }
    };
  }

  @override
  void dispose() {
    super.dispose();
    tabController.dispose();
    pageController.dispose();
    scrollController.dispose();
    _focusNode.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.read<SettingsController>();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    tags =
        args?['tags'] as List<Map<String, dynamic>>? ?? [QueryText('').toMap()];
    var search = args != null &&
        tags.first['name'] != '' &&
        tags.first['type'] != 'type';
    if (search) {
      children = kIsWeb
          ? [
              GallerySearchResultView(
                  key: ValueKey(pageKey[0]),
                  api: controller.hitomi(type: HitomiType.PROXY),
                  selected: tags,
                  local: true,
                  dateDesc: pageKey[0].value,
                  startPage: pageKey[0].key)
            ]
          : [
              GallerySearchResultView(
                  key: ValueKey(pageKey[0]),
                  api: controller.hitomi(),
                  selected: tags,
                  local: false,
                  dateDesc: pageKey[0].value,
                  startPage: pageKey[0].key),
              GallerySearchResultView(
                  key: ValueKey(pageKey[1]),
                  api: controller.hitomi(
                      type: controller.remoteLib
                          ? HitomiType.PROXY
                          : HitomiType.Local),
                  selected: tags,
                  local: true,
                  dateDesc: pageKey[1].value,
                  startPage: pageKey[1].key)
            ];
    } else {
      children = kIsWeb
          ? [
              GalleryItemListView(
                  key: ValueKey(pageKey[0]),
                  api: controller.hitomi(type: HitomiType.PROXY),
                  label: tags.first,
                  local: true,
                  sortEnum: pageKey[0].value,
                  startPage: pageKey[0].key)
            ]
          : [
              GalleryItemListView(
                  key: ValueKey(pageKey[0]),
                  api: controller.hitomi(),
                  label: tags.first,
                  local: false,
                  sortEnum: pageKey[0].value,
                  startPage: pageKey[0].key),
              GalleryItemListView(
                  key: ValueKey(pageKey[1]),
                  api: controller.hitomi(
                      type: controller.remoteLib
                          ? HitomiType.PROXY
                          : HitomiType.Local),
                  label: tags.first,
                  sortEnum: pageKey[1].value,
                  startPage: pageKey[1].key,
                  local: true),
            ];
    }
    tabs = children.length == 1
        ? [Tab(text: AppLocalizations.of(context)!.local)]
        : [
            Tab(
              text: AppLocalizations.of(context)!.network,
            ),
            Tab(text: AppLocalizations.of(context)!.local)
          ];
  }

  Widget _sortWidget() {
    return PopupMenuButton<SortEnum>(
        itemBuilder: (context) {
          return pageController.page == 1 ||
                  kIsWeb ||
                  children[0] is GallerySearchResultView
              ? <PopupMenuEntry<SortEnum>>[
                  PopupMenuItem(
                      value: SortEnum.Default,
                      child: Text(AppLocalizations.of(context)!.dateDefault)),
                  PopupMenuItem(
                      value: SortEnum.ID_ASC,
                      child: Text(AppLocalizations.of(context)!.idAsc)),
                  if (pageController.page == 1 || kIsWeb)
                    PopupMenuItem(
                        value: SortEnum.ADD_TIME,
                        child: Text(AppLocalizations.of(context)!.addTime)),
                ]
              : <PopupMenuEntry<SortEnum>>[
                  PopupMenuItem(
                      value: SortEnum.Default,
                      child: Text(AppLocalizations.of(context)!.dateDefault)),
                ];
        },
        onSelected: (value) => setState(() {
              var preEntry = pageKey[pageController.page!.floor()];
              pageKey[pageController.page!.floor()] =
                  MapEntry(preEntry.key, value);
            }),
        icon: const Icon(Icons.sort));
  }

  Widget content() {
    return MaxWidthBox(
        maxWidth: 1280,
        child: NestedScrollView(
            controller: scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    forceElevated: innerBoxIsScrolled,
                    pinned: true,
                    floating: true,
                    snap: true,
                    title: children[0] is GallerySearchResultView
                        ? Text(tags.fold(
                            '',
                            (acc, tag) =>
                                '${acc + (tag['translate'] ?? tag['name'])},'))
                        : GallerySearch(onSearch: onSearch),
                    bottom: TabBar(
                        tabs: tabs,
                        controller: tabController,
                        onTap: (value) => pageController.jumpToPage(value)),
                    actions: [
                      _sortWidget(),
                      IconButton(
                          onPressed: () async {
                            var s = await context.showDialogInput(
                                textField: TextField(
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            signed: true),
                                    controller: TextEditingController(),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ]),
                                inputHint:
                                    AppLocalizations.of(context)!.pageJumpHint);
                            if (s?.isNotEmpty == true) {
                              setState(() {
                                var preEntry =
                                    pageKey[pageController.page!.floor()];
                                pageKey[pageController.page!.floor()] =
                                    MapEntry(int.parse(s!), preEntry.value);
                              });
                            }
                          },
                          icon: const Icon(Icons.forward_5))
                    ],
                  )
                ],
            scrollBehavior: MouseEnabledScrollBehavior(),
            body: NotificationListener(
                child: PageView.builder(
                    itemBuilder: (context, index) => children[index],
                    controller: pageController,
                    itemCount: children.length,
                    scrollBehavior: MouseEnabledScrollBehavior(),
                    onPageChanged: (value) => tabController.animateTo(value)),
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification &&
                      notification.metrics.runtimeType == FixedScrollMetrics) {
                    var dy = notification.scrollDelta ?? 0;
                    if (dy != 0) {
                      scrollController.position
                          .jumpTo(scrollController.position.pixels + dy);
                    }
                  }
                  return true;
                })));
  }

  @override
  Widget build(BuildContext context) {
    _focusNode.requestFocus();
    final backAble = children[0] is GallerySearchResultView;
    return Scaffold(
        body: Center(
      child: Focus(
          focusNode: _focusNode,
          onKeyEvent: (focus, value) {
            if (backAble &&
                backKeys.contains(value.logicalKey) &&
                focus.hasPrimaryFocus &&
                value is KeyUpEvent) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: content()),
    ));
  }
}

class MouseEnabledScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
