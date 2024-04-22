import 'package:ayaka/src/gallery_view/gallery_search.dart';
import 'package:ayaka/src/gallery_view/gallery_search_result.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/label.dart';
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
  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    pageController = PageController(initialPage: 0);
    scrollController = ScrollController();
    scrollController.addListener(() {
      debugPrint('cur ${scrollController.position.pixels}');
    });
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
    debugPrint('$tags vs ${children.length}');
    if (children.isEmpty) {
      children = tags.length <= 1
          ? [
              GalleryItemListView(
                  api: controller.hitomi(), label: tags.first, local: false),
              GalleryItemListView(
                  api: controller.hitomi(localDb: true),
                  label: tags.first,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: NestedScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    forceElevated: true,
                    pinned: true,
                    floating: true,
                    snap: true,
                    title: const GallerySearch(),
                    bottom: TabBar(
                        tabs: [
                          Tab(
                            text: AppLocalizations.of(context)!.network,
                          ),
                          Tab(text: AppLocalizations.of(context)!.local)
                        ],
                        controller: tabController,
                        onTap: (value) => pageController.jumpToPage(value)),
                  )
                ],
            scrollBehavior: MouseEnabledScrollBehavior(),
            floatHeaderSlivers: true,
            body: NotificationListener(
                child: PageView.builder(
                    itemBuilder: (context, index) => children[index],
                    controller: pageController,
                    itemCount: children.length,
                    scrollBehavior: MouseEnabledScrollBehavior(),
                    onPageChanged: (value) => tabController.animateTo(value)),
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    var dy = notification.dragDetails?.delta.dy ?? 0;
                    if (dy != 0) {
                      scrollController.position.pointerScroll(dy);
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
