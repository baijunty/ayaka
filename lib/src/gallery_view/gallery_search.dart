import 'dart:async';
import 'package:ayaka/src/gallery_view/gallery_search_result.dart';
import 'package:ayaka/src/utils/label_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../ui/common_view.dart';
import '../utils/debounce.dart';

class GallerySearch extends StatefulWidget {
  final bool localDb;
  const GallerySearch({super.key, required this.localDb});
  @override
  State<StatefulWidget> createState() {
    return _GallerySearch();
  }
}

class _GallerySearch extends State<GallerySearch> {
  bool useInclude = true;
  late Debounce _debounce;
  final types = <Map<String, dynamic>>[];
  final languages = <Map<String, dynamic>>[];
  final _history = <Map<String, dynamic>>{};
  late Hitomi api;
  Future<Iterable<Widget>> fetchLabels(SearchController controller) async {
    var key = controller.value;
    if (key.text.length < 2 || !zhAndJpCodeExp.hasMatch(key.text)) {
      return [];
    }
    return _debounce.runDebounce(() {
      debugPrint('net fetch ${key.text}');
      try {
        return api
            .fetchSuggestions(key.text)
            .then((value) => value.map((e) => _buildListTile(e, controller)));
      } catch (e) {
        showSnackBar(context, 'err $e');
        return [];
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _debounce = Debounce();
    api = context.read<SettingsController>().hitomi(localDb: true);
  }

  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
  }

  String _showTranslate(Map<String, dynamic> map) {
    String type = map['type'];
    String translate = map['translate'];
    String showType = mapTagType(context, type);
    return '$showType $translate';
  }

  Widget _buildListTile(
      Map<String, dynamic> label, SearchController controller) {
    var history = _showTranslate(label);
    return ListTile(
        leading: const Icon(Icons.history),
        title: Text(history),
        onTap: () {
          controller.closeView(history);
          handleSelection(label, controller);
        });
  }

  Iterable<Widget> getHistoryList(SearchController controller) {
    return _history.map((label) {
      return _buildListTile(label, controller);
    });
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: SearchAnchor.bar(
          barHintText: AppLocalizations.of(context)!.search,
          suggestionsBuilder: (context, controller) {
            if (controller.text.isEmpty) {
              if (_history.isNotEmpty) {
                return getHistoryList(controller);
              }
              return <Widget>[
                Center(
                  child: Text(AppLocalizations.of(context)!.emptyContent,
                      style: const TextStyle(color: Colors.grey)),
                )
              ];
            }
            return fetchLabels(controller);
          },
          onSubmitted: (value) => Navigator.of(context).restorablePushNamed(
                  GallerySearchResultView.routeName,
                  arguments: {
                    'tags': [
                      {'type': '', 'name': value, 'include': true}
                    ],
                    'local': widget.localDb
                  })),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _inputRow();
  }

  void handleSelection(
      Map<String, dynamic> label, SearchController controller) {
    var useLabel = {...label, 'include': useInclude};
    setState(() {
      _history.add(label);
      Navigator.of(context)
          .restorablePushNamed(GallerySearchResultView.routeName, arguments: {
        'tags': [useLabel],
        'local': widget.localDb
      });
      controller.text = '';
    });
  }
}
