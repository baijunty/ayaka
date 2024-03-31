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
  late TextEditingController controller;
  String _lastQuery = '';
  bool useInclude = true;
  Map<String, dynamic>? _current;
  late Debounce _debounce;
  final types = <Map<String, dynamic>>[];
  final languages = <Map<String, dynamic>>[];
  Future<List<Map<String, dynamic>>> fetchLabels(TextEditingValue key) async {
    if (key.text.length < 2 ||
        _lastQuery == key.text ||
        !zhAndJpCodeExp.hasMatch(key.text)) {
      return [];
    }
    _lastQuery = key.text;
    return _debounce.runDebounce(() {
      if (_current != null && _showTranslate(_current!) == key.text) {
        return <Map<String, dynamic>>[];
      }
      debugPrint('net fetch ${key.text}');
      try {
        return context
            .read<SettingsController>()
            .hitomi(localDb: true)
            .fetchSuggestions(key.text)
            .then((value) => _lastQuery == key.text ? value : []);
      } catch (e) {
        debugPrint('$e');
        return <Map<String, dynamic>>[];
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

  Row _inputRow() {
    return Row(
      children: [
        Expanded(
            child: Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (text) async {
            if (text.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            return fetchLabels(text);
          },
          displayStringForOption: (option) => _showTranslate(option),
          onSelected: (option) {
            _current = {...option, 'include': useInclude};
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
            controller = textEditingController;
            return TextFormField(
                focusNode: focusNode,
                onFieldSubmitted: (value) {
                  onFieldSubmitted();
                },
                controller: controller);
          },
        )),
        Text(useInclude
            ? AppLocalizations.of(context)!.alreadySelected
            : AppLocalizations.of(context)!.exclude),
        Switch(
            value: useInclude,
            onChanged: (b) => setState(() {
                  useInclude = b;
                })),
        IconButton(
            onPressed: () => setState(() {
                  if (_current != null) {
                    _selected.add(_current!);
                  } else if (controller.text.isNotEmpty) {
                    _selected.add({
                      'type': '',
                      'name': controller.text,
                      'translate': controller.text,
                      'include': useInclude
                    });
                  }
                  _current = null;
                  controller.text = '';
                }),
            icon: const Icon(Icons.add)),
      ],
    );
  }

  Widget selectRow(String type, List<Map<String, dynamic>> labels) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(
        type,
        style: Theme.of(context).textTheme.bodyLarge,
        textScaler: const TextScaler.linear(1.2),
      ),
      const SizedBox(width: 16),
      for (var label in labels)
        Row(children: [
          Text(label['translate']),
          Checkbox(
              value: _selected.contains(label),
              onChanged: (b) => setState(() {
                    if (b == true) {
                      _selected.add(label);
                    } else {
                      _selected.remove(label);
                    }
                  })),
          const SizedBox(width: 8),
        ])
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
        body: Column(children: [
      _inputRow(),
      const SizedBox(height: 56),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton(
            style: Theme.of(context).filledButtonTheme.style?.copyWith(
                backgroundColor: const MaterialStatePropertyAll(Colors.orange)),
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
                backgroundColor: const MaterialStatePropertyAll(Colors.blue)),
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
      selectRow(mapTagType(context, 'type'), types),
      selectRow(mapTagType(context, 'language'), languages),
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
      const Divider(color: Colors.grey),
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
    ]));
  }
}
