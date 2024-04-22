import 'package:ayaka/src/gallery_view/gallery_search.dart';
import 'package:ayaka/src/gallery_view/gallery_search_result.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  List<Widget> children = [];
  List<Widget> tabs = [];
  List<SortEnum> sortEnums = List.filled(2, SortEnum.Default);
  @override
  void initState() {
    super.initState();
    tabController = TabController(length: kIsWeb ? 1 : 2, vsync: this);
    pageController = PageController(initialPage: 0);
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();
    tabController.dispose();
    pageController.dispose();
    scrollController.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.read<SettingsController>();
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    tags =
        args?['tags'] as List<Map<String, dynamic>>? ?? [QueryText('').toMap()];
    children = kIsWeb
        ? [
            GalleryItemListView(
                key: ValueKey(sortEnums[1]),
                api: controller.hitomi(localDb: true),
                label: tags.first,
                sortEnum: sortEnums[1],
                local: true)
          ]
        : tags.length <= 1
            ? [
                GalleryItemListView(
                    key: ValueKey(sortEnums[0]),
                    api: controller.hitomi(),
                    label: tags.first,
                    local: false,
                    sortEnum: sortEnums[0]),
                GalleryItemListView(
                    key: ValueKey(sortEnums[1]),
                    api: controller.hitomi(localDb: true),
                    label: tags.first,
                    sortEnum: sortEnums[1],
                    local: true),
              ]
            : [
                GallerySearchResultView(
                    api: controller.hitomi(), selected: tags, local: false),
                GallerySearchResultView(
                    api: controller.hitomi(localDb: true),
                    selected: tags,
                    local: true)
              ];
    tabs = kIsWeb
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
          return pageController.page == 1 || kIsWeb
              ? <PopupMenuEntry<SortEnum>>[
                  PopupMenuItem(
                      value: SortEnum.Default,
                      child: Text(AppLocalizations.of(context)!.dateDefault)),
                  PopupMenuItem(
                      value: SortEnum.Date,
                      child: Text(AppLocalizations.of(context)!.dateAsc)),
                  PopupMenuItem(
                      value: SortEnum.DateDesc,
                      child: Text(AppLocalizations.of(context)!.dateDesc)),
                ]
              : <PopupMenuEntry<SortEnum>>[
                  PopupMenuItem(
                      value: SortEnum.Default,
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
              sortEnums[pageController.page!.floor()] = value;
            }),
        icon: const Icon(Icons.sort));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: NestedScrollView(
            controller: scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    forceElevated: innerBoxIsScrolled,
                    pinned: true,
                    floating: true,
                    snap: true,
                    title: const GallerySearch(),
                    bottom: TabBar(
                        tabs: tabs,
                        controller: tabController,
                        onTap: (value) => pageController.jumpToPage(value)),
                    actions: tags.length <= 1 ? [_sortWidget()] : null,
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
}

class MouseEnabledScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}