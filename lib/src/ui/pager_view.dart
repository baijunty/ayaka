// ignore_for_file: implementation_imports

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:easy_image_viewer/src/easy_image_provider.dart';
import 'package:easy_image_viewer/src/easy_image_view.dart';

class MouseEnabledScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

class EasyImageViewPager extends StatefulWidget {
  final EasyImageProvider easyImageProvider;
  final PageController pageController;
  final bool doubleTapZoomable;
  final bool infinitelyScrollable;
  final void Function(double)? onScaleChanged;

  /// Create new instance, using the [easyImageProvider] to populate the [PageView],
  /// and the [pageController] to control the initial image index to display.
  /// The optional [doubleTapZoomable] boolean defaults to false and allows double tap to zoom.
  const EasyImageViewPager({
    super.key,
    required this.easyImageProvider,
    required this.pageController,
    this.doubleTapZoomable = false,
    this.onScaleChanged,
    this.infinitelyScrollable = false,
  });

  @override
  State<EasyImageViewPager> createState() => _EasyImageViewPagerState();
}

class _EasyImageViewPagerState extends State<EasyImageViewPager> {
  bool _pagingEnabled = true;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      physics: _pagingEnabled
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      key: GlobalObjectKey(widget.easyImageProvider),
      itemCount: widget.infinitelyScrollable
          ? null
          : widget.easyImageProvider.imageCount,
      controller: widget.pageController,
      allowImplicitScrolling: true,
      scrollBehavior: MouseEnabledScrollBehavior(),
      itemBuilder: (context, index) {
        final pageIndex = _getPageIndex(index);
        return EasyImageView.imageWidget(
          widget.easyImageProvider.imageWidgetBuilder(context, pageIndex),
          key: Key('easy_image_view_$pageIndex'),
          doubleTapZoomable: widget.doubleTapZoomable,
          onScaleChanged: (scale) {
            if (widget.onScaleChanged != null) {
              widget.onScaleChanged!(scale);
            }
            setState(() {
              _pagingEnabled = scale <= 1.0;
            });
          },
        );
      },
    );
  }

  int _getPageIndex(int index) {
    if (widget.infinitelyScrollable) {
      return index % widget.easyImageProvider.imageCount;
    }
    return index;
  }
}
