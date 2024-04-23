import 'dart:async';
import 'dart:math';
import 'package:ayaka/src/gallery_view/gallery_details_view.dart';
import 'package:ayaka/src/gallery_view/gallery_tabview.dart';
import 'package:ayaka/src/utils/label_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../ui/common_view.dart';
import '../utils/debounce.dart';

class GallerySearch extends StatefulWidget {
  const GallerySearch({super.key});
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
  late SearchController controller;
  late FocusNode focusNode;
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
        context.showSnackBar('err $e');
        return [];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    controller = SearchController();
    focusNode = FocusNode();
    controller.addListener(textChange);
    _debounce = Debounce();
  }

  void textChange() {
    var word = controller.text.characters.lastOrNull == ','
        ? controller.text.split(',').lastWhereOrNull((element) =>
            element.isNotEmpty &&
            !element.contains(':') &&
            _selected.every((elem) => elem['name'] != element))
        : null;
    if (word != null) {
      _selected
          .add({'type': '', 'name': word, 'translate': word, 'include': true});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    api = context.read<SettingsController>().hitomi(localDb: true);
    focusNode.unfocus();
  }

  @override
  void dispose() {
    super.dispose();
    _debounce.dispose();
    focusNode.dispose();
    controller.removeListener(textChange);
    controller.dispose();
  }

  String _showTranslate(Map<String, dynamic> map) {
    String type = map['type'];
    String translate = map['translate'];
    String showType = mapTagType(context, type);
    return '${showType.isNotEmpty ? '$showType:' : ''}$translate';
  }

  Widget _buildListTile(Map<String, dynamic> label,
      {void Function()? onTap, void Function()? onLongPress}) {
    var history = _showTranslate(label);
    return ListTile(
        leading: const Icon(Icons.history),
        title: Text(history),
        trailing: const Icon(Icons.arrow_upward),
        onLongPress: onLongPress,
        onTap: onTap);
  }

  Iterable<Widget> getHistoryList(SearchController controller) {
    return _history.map((label) {
      return _buildListTile(label, onLongPress: () {
        _history.remove(label);
        Navigator.of(context).pop();
        controller.openView();
      }, onTap: () {
        handleSelection(label, controller);
      });
    });
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: SearchAnchor(
          viewHintText: AppLocalizations.of(context)!.searchHint,
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
          searchController: controller,
          viewTrailing: [
            IconButton(
                onPressed: () {
                  controller.text = '';
                  _selected.clear();
                },
                icon: const Icon(Icons.close))
          ],
          builder: (context, controller) {
            return SearchBar(
                controller: controller,
                onTap: () {
                  controller.openView();
                },
                onChanged: (String value) {
                  controller.openView();
                },
                focusNode: focusNode,
                padding: const MaterialStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16.0)),
                leading: const Icon(Icons.search),
                onSubmitted: (value) async {
                  if (controller.text.isNotEmpty) {
                    if (_selected.isNotEmpty) {
                      Navigator.of(context).restorablePushNamed(
                          GalleryTabView.routeName,
                          arguments: {
                            'tags': _selected,
                          });
                    } else if (numberExp.hasMatch(controller.text)) {
                      await api.fetchGallery(controller.text).then(
                          (value) async {
                        await Navigator.of(context).pushNamed(
                            GalleryDetailsView.routeName,
                            arguments: {'gallery': value, 'local': false});
                        return debugPrint('fetch ${value.name}');
                      }).catchError(
                          (e) => context.showSnackBar(
                              '${AppLocalizations.of(context)!.networkError} or ${AppLocalizations.of(context)!.wrongId}'),
                          test: (error) => true);
                    }
                  }
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
      var input = _selected.fold(
          '',
          (previousValue, element) =>
              previousValue + ('${_showTranslate(element)},'));
      controller.closeView(input);
      // Navigator.of(context)
      //     .restorablePushNamed(GallerySearchResultView.routeName, arguments: {
      //   'tags': [useLabel],
      //   'local': widget.localDb
      // });
      // controller.text = '';
    });
  }
}
