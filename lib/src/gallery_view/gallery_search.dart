import 'dart:async';
import 'package:ayaka/src/utils/label_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/gallery_view/gallery_item_list_view.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../utils/debounce.dart';
import 'gallery_search_result.dart';

class GallerySearch extends StatefulWidget {
  const GallerySearch({super.key});
  static const routeName = '/gallery_search';
  @override
  State<StatefulWidget> createState() {
    return _GallerySearch();
  }
}

class _GallerySearch extends State<GallerySearch> {
  final _selected = <Map<String, dynamic>>[];
  late Hitomi hitomi;
  String _lastQuery = '';
  bool useInclude = true;
  late Debounce _debounce;
  final types = <Map<String, dynamic>>[];
  final languages = <Map<String, dynamic>>[];
  final _history = <Map<String, dynamic>>[];
  Future<Iterable<Widget>> fetchLabels(SearchController controller) async {
    var key = controller.value;
    if (key.text.length < 2 ||
        _lastQuery == key.text ||
        !zhAndJpCodeExp.hasMatch(key.text)) {
      return [];
    }
    _lastQuery = key.text;
    return _debounce.runDebounce(() {
      debugPrint('net fetch ${key.text}');
      try {
        return context
            .read<SettingsController>()
            .hitomi(localDb: true)
            .fetchSuggestions(key.text)
            .then((value) =>
                _lastQuery == key.text ? value : <Map<String, dynamic>>[])
            .then((value) => value.map((e) => _buildListTile(e, controller)));
      } catch (e) {
        debugPrint('$e');
        return [];
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var settings = context.read<SettingsController>();
    _debounce = Debounce();
    hitomi = settings.hitomi();
    hitomi.translate([
      ...settings.manager.config.excludes,
    ]).then((value) => setState(() {
          _selected.addAll(value.map((e) => e..['include'] = false));
        }));
    types.addAll([
      TypeLabel('doujinshi'),
      TypeLabel('manga'),
      TypeLabel('artistcg'),
      TypeLabel('gamecg'),
      TypeLabel('imageset'),
      TypeLabel('anime')
    ]
        .map((e) =>
            e.toMap()..['translate'] = mapGalleryType(context, e.typeName).key)
        .map((e) => e..['include'] = true)
        .toList());
    languages.addAll(settings.manager.config.languages
        .map((e) => Language(name: e))
        .map((e) => e.toMap()..['translate'] = mapLangugeType(context, e.name))
        .map((e) => e..['include'] = true)
        .toList());
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
    return SearchAnchor.bar(
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
    );
  }

  // Widget selectRow(String type, List<Map<String, dynamic>> labels) {
  //   return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
  //     Text(
  //       type,
  //       style: Theme.of(context).textTheme.bodyLarge,
  //       textScaler: const TextScaler.linear(1.2),
  //     ),
  //     const SizedBox(width: 16),
  //     Expanded(
  //         child: Wrap(children: [
  //       for (var label in labels)
  //         FilterChip(
  //             label: Text(label['translate']),
  //             selected: _selected.contains(label),
  //             onDeleted: () => setState(() {
  //                   _selected.remove(label);
  //                 }),
  //             onSelected: (b) => setState(() {
  //                   if (!_selected.contains(label)) {
  //                     _selected.add(label);
  //                   }
  //                 }))
  //     ])),
  //   ]);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: Column(children: [
          _inputRow(),
          DropdownMenu<bool>(
              dropdownMenuEntries: [
                DropdownMenuEntry(
                    label: AppLocalizations.of(context)!.alreadySelected,
                    value: true),
                DropdownMenuEntry(
                    label: AppLocalizations.of(context)!.exclude, value: false),
              ],
              label: Text(AppLocalizations.of(context)!.mode),
              onSelected: (b) => useInclude = b == true),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.grey),
          Text(AppLocalizations.of(context)!.alreadySelected),
          Wrap(children: [
            for (var label
                in _selected.where((element) => element['include'] == true))
              TextButton(
                  onPressed: () => Navigator.of(context).restorablePushNamed(
                      GalleryListView.routeName,
                      arguments: {'tag': label}),
                  child: Text(_showTranslate(label)))
          ]),
          Text(AppLocalizations.of(context)!.exclude),
          Wrap(children: [
            for (var label
                in _selected.where((element) => element['include'] == false))
              TextButton(
                  onPressed: () => Navigator.of(context).restorablePushNamed(
                      GalleryListView.routeName,
                      arguments: {'tag': label}),
                  child: Text(_showTranslate(label)))
          ]),
          const Divider(color: Colors.grey),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilledButton(
                style: Theme.of(context).filledButtonTheme.style?.copyWith(
                    backgroundColor:
                        const MaterialStatePropertyAll(Colors.orange)),
                onPressed: () {
                  Navigator.of(context).restorablePushNamed(
                      GallerySearchResultView.routeName,
                      arguments: {'tags': _selected, 'local': false});
                },
                child: Text(
                  AppLocalizations.of(context)!.search,
                  style: Theme.of(context).textTheme.bodyMedium,
                )),
            const SizedBox(width: 16),
            FilledButton(
                style: Theme.of(context).filledButtonTheme.style?.copyWith(
                    backgroundColor:
                        const MaterialStatePropertyAll(Colors.blue)),
                onPressed: () {
                  Navigator.of(context).restorablePushNamed(
                      GallerySearchResultView.routeName,
                      arguments: {'tags': _selected, 'local': true});
                },
                child: Text(
                  '搜索本地',
                  style: Theme.of(context).textTheme.bodyMedium,
                ))
          ]),
        ]));
  }

  void handleSelection(
      Map<String, dynamic> label, SearchController controller) {
    var useLabel = {...label, 'include': useInclude};
    setState(() {
      if (_selected
          .any((element) => _showTranslate(element) == _showTranslate(label))) {
        _selected.removeWhere(
            (element) => _showTranslate(element) == _showTranslate(label));
        debugPrint('remove $label');
      } else {
        _selected.add(useLabel);
        debugPrint('add $label');
      }
      controller.text = '';
    });
  }
}
