import 'dart:io';

import 'package:ayaka/src/ui/common_view.dart';
import 'package:ayaka/src/utils/label_utils.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart' show WatchContext;
import 'settings_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' show join;

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  static const routeName = '/settings';

  @override
  State<StatefulWidget> createState() {
    return _StateSetting();
  }
}

class _StateSetting extends State<SettingsView> {
  late SettingsController _settingsController;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    super.dispose();
    _textController.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settingsController = context.watch<SettingsController>();
  }

  Future<bool> testWriteble(String path) {
    return File(join(path, 'test.txt'))
        .writeAsString('1', flush: true)
        .then((value) => value.delete())
        .then((value) => true);
  }

  Widget _settingsContent() {
    return Column(children: [
      ListTile(
          leading: Icon(_settingsController.themeMode == ThemeMode.light
              ? Icons.light_mode
              : Icons.mode_night),
          title: Text(AppLocalizations.of(context)!.themeMode),
          subtitle: _settingsController.themeMode == ThemeMode.light
              ? Text(AppLocalizations.of(context)!.dayTheme)
              : Text(AppLocalizations.of(context)!.darkTheme),
          trailing: Switch.adaptive(
              value: _settingsController.themeMode == ThemeMode.light,
              onChanged: (b) => setState(() {
                    _settingsController
                        .updateThemeMode(b ? ThemeMode.light : ThemeMode.dark);
                  }))),
      if (!kIsWeb)
        ListTile(
            leading: const ImageIcon(AssetImage('assets/images/vpn.png')),
            title: Text(AppLocalizations.of(context)!.proxy),
            subtitle: Text(_settingsController.config.proxy),
            trailing: IconButton(
                onPressed: () async {
                  _textController.text = _settingsController.config.proxy;
                  var s = await context.showDialogInput(
                      textField: TextField(
                          controller: _textController,
                          keyboardType: TextInputType.url,
                          inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter
                      ]));
                  if (s != null) {
                    await _settingsController.updateConfig(
                        _settingsController.config.copyWith(proxy: s));
                  }
                },
                icon: const Icon(Icons.edit))),
      if (!kIsWeb)
        ListTile(
            leading: const ImageIcon(AssetImage('assets/images/direction.png')),
            title: Text(AppLocalizations.of(context)!.gallerySorce),
            subtitle: Text(_settingsController.remoteLib
                ? AppLocalizations.of(context)!.remote
                : AppLocalizations.of(context)!.local),
            trailing: Switch.adaptive(
                value: _settingsController.remoteLib,
                onChanged: (b) => setState(() {
                      _settingsController.switchConn(b);
                    }))),
      if (_settingsController.remoteLib)
        ListTile(
            leading: const ImageIcon(AssetImage('assets/images/url.png')),
            title: Text(AppLocalizations.of(context)!.remoteAddr),
            subtitle: Text(_settingsController.config.remoteHttp),
            trailing: IconButton(
                onPressed: () async {
                  _textController.text = _settingsController.config.remoteHttp;
                  var s = await context.showDialogInput(
                      textField: TextField(
                          controller: _textController,
                          keyboardType: TextInputType.url,
                          inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter
                      ]));
                  if (s?.isNotEmpty == true) {
                    await _settingsController.updateConfig(
                        _settingsController.config.copyWith(remoteHttp: s!));
                  }
                },
                icon: const Icon(Icons.edit))),
      if (_settingsController.remoteLib)
        ListTile(
            leading: const ImageIcon(
                AssetImage('assets/images/user-authentication.png')),
            title: Text(AppLocalizations.of(context)!.authToken),
            subtitle: Text(_settingsController.config.auth),
            trailing: IconButton(
                onPressed: () async {
                  _textController.text = _settingsController.config.auth;
                  var s = await context.showDialogInput(
                      textField: TextField(
                          controller: _textController,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter
                      ]));
                  if (s?.isNotEmpty == true) {
                    await _settingsController.updateConfig(
                        _settingsController.config.copyWith(auth: s!));
                  }
                },
                icon: const Icon(Icons.edit))),
      if (!kIsWeb)
        ListTile(
            leading: Icon(_settingsController.runServer
                ? Icons.online_prediction
                : Icons.airplanemode_active),
            title: Text(AppLocalizations.of(context)!.runServer),
            subtitle: _settingsController.runServer
                ? FutureBuilder(
                    future: localIp(),
                    builder: (context, snap) {
                      return Text('http://${snap.data}:7890');
                    })
                : Text(AppLocalizations.of(context)!.closed),
            trailing: Switch.adaptive(
                value: _settingsController.runServer,
                onChanged: (b) => _settingsController
                    .openServer(b)
                    .then((value) => setState(() {})))),
      if (!kIsWeb)
        ListTile(
            leading: const ImageIcon(AssetImage('assets/images/database.png')),
            title: Text(AppLocalizations.of(context)!.updateDatabase),
            trailing: IconButton(
                onPressed: () async {
                  await context.progressDialogAction(
                      _settingsController.manager.parseCommandAndRun('-u'));
                },
                icon:
                    const ImageIcon(AssetImage('assets/images/refresh.png')))),
      if (!kIsWeb)
        ListTile(
            leading: Icon(Icons.broken_image),
            title: Text(AppLocalizations.of(context)!.fixDb),
            trailing: IconButton(
                onPressed: () async {
                  await context.progressDialogAction(
                      _settingsController.manager.parseCommandAndRun('--fix'));
                },
                icon: Icon(Icons.auto_fix_high))),
      if (!kIsWeb)
        ListTile(
            leading:
                const ImageIcon(AssetImage('assets/images/open-folder.png')),
            title: Text(AppLocalizations.of(context)!.savePath),
            subtitle: Text(_settingsController.config.output),
            trailing: IconButton(
                onPressed: () async {
                  var initDir = await getExternalStorageDirectory()
                      .catchError((e) => getApplicationSupportDirectory(),
                          test: (error) => true)
                      .then((value) async =>
                          value ?? await getApplicationSupportDirectory());
                  var path = await FilePicker.platform
                      .getDirectoryPath(initialDirectory: initDir.path);
                  if (path?.isNotEmpty == true) {
                    await testWriteble(path!)
                        .then((value) => _settingsController.updateConfig(
                            _settingsController.config.copyWith(output: path)))
                        .catchError(
                            (e) => _settingsController.updateConfig(
                                _settingsController.config
                                    .copyWith(output: initDir.path)),
                            test: (error) => true)
                        .then((value) => setState(() {}));
                  }
                },
                icon: const Icon(Icons.edit))),
      if (!kIsWeb)
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(AppLocalizations.of(context)!.language),
          subtitle: Text(Iterable.iterableToFullString(
              _settingsController.config.languages
                  .map((l) => mapLangugeType(context, l)),
              '',
              '')),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () async {
            var languages = await _settingsController
                .hitomi(localDb: true)
                .translate(
                    [Language.chinese, Language.japanese, Language.english]);
            for (var item in languages) {
              item['selected'] =
                  _settingsController.config.languages.contains(item['name']);
            }
            if (mounted) {
              List<Map<String, dynamic>>? data = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => MultiSelectListView(items: languages)));
              if (data != null) {
                setState(() {
                  _settingsController.updateConfig(_settingsController.config
                      .copyWith(
                          languages: data
                              .map((e) => e['name'] as String)
                              .toList(growable: false)));
                });
              }
            }
          },
        ),
      if (!kIsWeb)
        ListTile(
          leading: const Icon(Icons.block),
          title: Text(AppLocalizations.of(context)!.blockTag),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () async {
            var items = await _settingsController
                .hitomi(localDb: true)
                .translate(_settingsController.config.excludes);
            for (var item in items) {
              item['selected'] = true;
            }
            if (mounted) {
              List<Map<String, dynamic>>? data = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => MultiSelectListView(items: items)));
              if (data != null) {
                setState(() {
                  _settingsController.updateConfig(_settingsController.config
                      .copyWith(
                          excludes: data
                              .map((e) => FilterLabel(
                                  type: e['type'],
                                  name: e['name'],
                                  weight: 1.0))
                              .toList(growable: false)));
                });
              }
            }
          },
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _settingsContent()))));
  }
}

class MultiSelectListView extends StatefulWidget {
  const MultiSelectListView({
    super.key,
    required this.items,
  });

  final List<Map<String, dynamic>> items;

  @override
  State<MultiSelectListView> createState() => _MultiSelectListViewState();
}

class _MultiSelectListViewState extends State<MultiSelectListView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(actions: [
          IconButton(
              onPressed: () => Navigator.pop(
                  context,
                  widget.items
                      .where((item) => item['selected'] ?? false)
                      .toList()),
              icon: const Icon(Icons.done))
        ]),
        body: ReorderableListView(
            children: [
              for (var item in widget.items)
                ListTile(
                  key: Key(item['name']),
                  title: Text(item['translate']),
                  selected: item['selected'] ?? false,
                  onTap: () {
                    setState(() {
                      item['selected'] = !(item['selected'] ?? false);
                    });
                  },
                ),
            ],
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                var item = widget.items.removeAt(oldIndex);
                widget.items.insert(newIndex, item);
              });
            }));
  }
}
