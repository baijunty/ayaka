import 'dart:async';
import 'dart:math';
import 'package:ayaka/src/utils/label_utils.dart';
import 'package:collection/collection.dart';
import 'package:ayaka/src/localization/app_localizations.dart';
import 'package:ayaka/src/settings/settings_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/lib.dart';
import 'package:provider/provider.dart';

import '../ui/common_view.dart';
import '../utils/debounce.dart';
import 'gallery_image_search.dart' show GalleryImageSearch;

class GallerySearch extends StatefulWidget {
  final Function(Map<String, dynamic>) onSearch;
  const GallerySearch({super.key, required this.onSearch});
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
    if (text.length < 2) {
      return [];
    }
    if (lastQuery == text) {
      return lastResult;
    }
    lastQuery = text;
    return _debounce.runDebounce(() {
      debugPrint('net fetch $text');
      try {
        if (lastQuery != text) {
          return [];
        }
        return api.fetchSuggestions(text).then((value) {
          if (lastQuery != text) {
            return [];
          }
          lastResult = value.map(
            (e) => _buildListTile(
              e,
              onTap: () {
                handleSelection(e, controller);
              },
            ),
          );
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
    focusNode = FocusNode(
      debugLabel: 'search View',
      onKeyEvent: (n, e) {
        debugPrint('${n} is ${e}');
        return KeyEventResult.ignored;
      },
    );
    controller.addListener(textChange);
    _debounce = Debounce();
  }

  void textChange() {
    var word = controller.text.characters.lastOrNull == ','
        ? controller.text
              .split(',')
              .lastWhereOrNull(
                (element) =>
                    element.isNotEmpty &&
                    !element.contains(':') &&
                    _selected.every((elem) => elem['name'] != element),
              )
        : null;
    if (word != null) {
      _selected.add({
        'type': '',
        'name': word,
        'translate': word,
        'include': true,
      });
    }
    if (controller.text.isEmpty) {
      _selected.clear();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var controller = Provider.of<SettingsController>(context);
    api = context.read<SettingsController>().hitomi(
      type: controller.remoteLib ? HitomiType.PROXY : HitomiType.Local,
    );
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

  Widget _buildListTile(
    Map<String, dynamic> label, {
    void Function()? onTap,
    void Function()? onLongPress,
  }) {
    var history = _showTranslate(label);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(history),
      trailing: const Icon(Icons.arrow_upward),
      onLongPress: onLongPress,
      onTap: onTap,
    );
  }

  Iterable<Widget> getHistoryList(SearchController controller) {
    return _history.map((label) {
      return _buildListTile(
        label,
        onLongPress: () {
          _history.remove(label);
          Navigator.of(context).pop();
          controller.openView();
        },
        onTap: () {
          handleSelection(label, controller);
        },
      );
    });
  }

  /// 以输入框内容为准收集搜索标签。
  ///
  /// `_selected` 仅用于补充 `type` / `translate` 等元信息，凡是输入框里出现的
  /// 词都会进入搜索条件。这样手动敲进去的关键词（不经过建议列表选择）同样生效，
  /// 同时用户从输入框里删掉的标签会被自动剔除，不再残留。
  List<Map<String, dynamic>> collectTags() {
    var meta = <String, Map<String, dynamic>>{};
    for (var label in _selected) {
      meta[_showTranslate(label)] = label;
    }
    var result = <Map<String, dynamic>>[];
    for (var chunk in controller.text.split(',')) {
      var word = chunk.trim();
      if (word.isEmpty) {
        continue;
      }
      var known = meta[word];
      if (known != null) {
        result.add({...known, 'include': useInclude});
        continue;
      }
      var type = '';
      var name = word;
      var sep = word.indexOf(':');
      if (sep > 0) {
        var reversed = reverseTagType(context, word.substring(0, sep));
        if (reversed != null) {
          type = reversed;
          name = word.substring(sep + 1).trim();
        }
      }
      if (name.isEmpty) {
        continue;
      }
      result.add({
        'type': type,
        'name': name,
        'translate': name,
        'include': useInclude,
      });
    }
    _selected
      ..clear()
      ..addAll(result);
    return result;
  }

  void onSearchEvent(String value) async {
    var text = controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    // 先收起搜索视图，把焦点交还搜索栏，避免浮层残留在结果页上方。
    if (controller.isOpen) {
      controller.closeView(null);
    }
    focusNode.unfocus();
    if (numberExp.hasMatch(text)) {
      await api
          .fetchGallery(text, usePrefence: false)
          .then((value) async {
            if (context.mounted) {
              widget.onSearch({'gallery': value, 'local': false});
            }
            return debugPrint('fetch ${value.name}');
          })
          .catchError(
            (e) => context.mounted
                ? context.showSnackBar(
                    '${AppLocalizations.of(context)!.networkError} or ${AppLocalizations.of(context)!.wrongId}',
                  )
                : false,
            test: (error) => true,
          );
      return;
    }
    var tags = collectTags();
    if (tags.isEmpty) {
      return;
    }
    widget.onSearch({'tags': tags});
  }

  Widget _inputRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: SearchAnchor(
        viewHintText: AppLocalizations.of(context)!.searchHint,
        // 输入框获得焦点时处于展开的视图里，其回车回调是 viewOnSubmitted，
        // 只设置 SearchBar.onSubmitted 无法覆盖该场景。
        viewOnSubmitted: onSearchEvent,
        suggestionsBuilder: (context, controller) {
          if (controller.text.isEmpty) {
            _selected.clear();
            if (_history.isNotEmpty) {
              return getHistoryList(controller);
            }
            return <Widget>[
              Center(
                child: Text(
                  AppLocalizations.of(context)!.emptyContent,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ];
          }
          return fetchLabels(controller);
        },
        searchController: controller,
        viewTrailing: [
          IconButton(
            onPressed: () {
              FilePicker.pickFiles(
                type: FileType.image,
                allowedExtensions: ['jpg', 'png', 'jpeg', 'webp'],
              ).then((value) async {
                if (value == null || value.files.isEmpty) {
                  return;
                }
                var file = value.files.first.path;
                if (file == null || !context.mounted) {
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GalleryImageSearch(path: file),
                  ),
                );
              });
            },
            icon: const Icon(Icons.file_upload),
          ),
          IconButton(
            onPressed: () {
              controller.text = '';
              _selected.clear();
            },
            icon: const Icon(Icons.close),
          ),
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
            padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0),
            ),
            leading: const Icon(Icons.search),
            onSubmitted: onSearchEvent,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _inputRow(context);
  }

  void handleSelection(
    Map<String, dynamic> label,
    SearchController controller,
  ) {
    var useLabel = {...label, 'include': useInclude};
    setState(() {
      _history.add(label);
      _selected.add(useLabel);
      var input = _selected.fold(
        '',
        (previousValue, element) =>
            previousValue + ('${_showTranslate(element)},'),
      );
      controller.text = (input);
      // Navigator.of(context)
      //     .restorablePushNamed(GallerySearchResultView.routeName, arguments: {
      //   'tags': [useLabel],
      //   'local': widget.localDb
      // });
      // controller.text = '';
    });
  }
}
