import 'dart:async';
import 'dart:math';
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
  // final types = <Map<String, dynamic>>[];
  // final languages = <Map<String, dynamic>>[];
  final _selected = <Map<String, dynamic>>[];
  final _history = <Map<String, dynamic>>{};
  late Hitomi api;
  Iterable<Widget> lastResult = const Iterable.empty();
  String lastQuery = '';
  Future<Iterable<Widget>> fetchLabels(SearchController controller) async {
    var text = controller.value.text;
    text = text.substring(min(text.lastIndexOf(',') + 1, text.length));
    if (text.length < 2 || !zhAndJpCodeExp.hasMatch(text)) {
      return [];
    }
    if (lastQuery == text) {
      return lastResult;
    }
    lastQuery = text;
    return _debounce.runDebounce(() {
      debugPrint('net fetch $text');
      try {
        return api.fetchSuggestions(text).then((value) {
          if (lastQuery != text) {
            return [];
          }
          lastResult = value.map((e) => _buildListTile(e, onTap: () {
                handleSelection(e, controller);
              }));
          return lastResult;
        });
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
    return '$showType:$translate';
  }

  Widget _buildListTile(Map<String, dynamic> label,
      {void Function()? onTap, void Function()? onLongPress}) {
    var history = _showTranslate(label);
    return ListTile(
        leading: const Icon(Icons.history),
        title: Text(history),
        onLongPress: onLongPress,
        onTap: onTap);
  }

  Iterable<Widget> getHistoryList(SearchController controller) {
    return _history.map((label) {
      return _buildListTile(label,
          onLongPress: () => setState(() {
                _history.remove(label);
              }),
          onTap: () {
            handleSelection(label, controller);
          });
    });
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: SearchAnchor.bar(
          barHintText: AppLocalizations.of(context)!.searchHint,
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
          onSubmitted: (value) {
            var queryKey = value.split(',').where(
                (element) => element.isNotEmpty && !element.contains(':'));
            Navigator.of(context).restorablePushNamed(
                GallerySearchResultView.routeName,
                arguments: {
                  'tags': [
                    ..._selected,
                    ...queryKey
                        .map((e) => {'type': '', 'name': e,'translate':e, 'include': true})
                  ],
                  'local': widget.localDb
                });
          }),
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
      _selected.add(useLabel);
      var input =
          controller.text.substring(0, controller.text.indexOf(',') + 1);
      controller.closeView('$input${_showTranslate(useLabel)},');
      // Navigator.of(context)
      //     .restorablePushNamed(GallerySearchResultView.routeName, arguments: {
      //   'tags': [useLabel],
      //   'local': widget.localDb
      // });
      // controller.text = '';
    });
  }
}
