import 'dart:io';

import 'package:ayaka/src/ui/common_view.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
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
  bool netLoading = false;
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

  Future<String?> _showDialogInput(
      {TextInputType type = TextInputType.text,
      String defaultValue = ''}) async {
    _textController.text = defaultValue;
    return showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
                title: Text(AppLocalizations.of(context)!.inputHint),
                content: TextField(
                  controller: _textController,
                  keyboardType: type,
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(_textController.text);
                      },
                      child: Text(AppLocalizations.of(context)!.confirm)),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(AppLocalizations.of(context)!.cancel))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(children: [
              Column(children: [
                ListTile(
                    leading: Icon(
                        _settingsController.themeMode == ThemeMode.light
                            ? Icons.light_mode
                            : Icons.mode_night),
                    title: Text(AppLocalizations.of(context)!.themeMode),
                    subtitle: _settingsController.themeMode == ThemeMode.light
                        ? Text(AppLocalizations.of(context)!.dayTheme)
                        : Text(AppLocalizations.of(context)!.darkTheme),
                    trailing: Switch.adaptive(
                        value: _settingsController.themeMode == ThemeMode.light,
                        onChanged: (b) => setState(() {
                              _settingsController.updateThemeMode(
                                  b ? ThemeMode.light : ThemeMode.dark);
                            }))),
                ListTile(
                    leading:
                        const ImageIcon(AssetImage('assets/images/vpn.png')),
                    title: Text(AppLocalizations.of(context)!.proxy),
                    subtitle: Text(_settingsController.config.proxy),
                    trailing: IconButton(
                        onPressed: () async {
                          var s = await _showDialogInput(
                              type: TextInputType.url,
                              defaultValue: _settingsController.config.proxy);
                          if (s?.isNotEmpty == true) {
                            await _settingsController.updateConfig(
                                _settingsController.config.copyWith(proxy: s!));
                          }
                        },
                        icon: const Icon(Icons.edit))),
                ListTile(
                    leading:
                        const ImageIcon(AssetImage('assets/images/url.png')),
                    title: Text(AppLocalizations.of(context)!.remoteAddr),
                    subtitle: Text(_settingsController.config.remoteHttp),
                    trailing: IconButton(
                        onPressed: () async {
                          var s = await _showDialogInput(
                              type: TextInputType.url,
                              defaultValue:
                                  _settingsController.config.remoteHttp);
                          if (s?.isNotEmpty == true) {
                            await _settingsController.updateConfig(
                                _settingsController.config
                                    .copyWith(remoteHttp: s!));
                          }
                        },
                        icon: const Icon(Icons.edit))),
                ListTile(
                    leading: const ImageIcon(
                        AssetImage('assets/images/user-authentication.png')),
                    title: Text(AppLocalizations.of(context)!.authToken),
                    subtitle: Text(_settingsController.config.auth),
                    trailing: IconButton(
                        onPressed: () async {
                          var s = await _showDialogInput(
                              type: TextInputType.url,
                              defaultValue: _settingsController.config.auth);
                          if (s?.isNotEmpty == true) {
                            await _settingsController.updateConfig(
                                _settingsController.config.copyWith(auth: s!));
                          }
                        },
                        icon: const Icon(Icons.edit))),
                ListTile(
                    leading: const ImageIcon(
                        AssetImage('assets/images/direction.png')),
                    title: Text(AppLocalizations.of(context)!.connectType),
                    subtitle: Text(_settingsController.useProxy
                        ? AppLocalizations.of(context)!.proxy
                        : AppLocalizations.of(context)!.direct),
                    trailing: Switch.adaptive(
                        value: _settingsController.useProxy,
                        onChanged: (b) => setState(() {
                              _settingsController.switchConn(b);
                            }))),
                ListTile(
                    leading: const ImageIcon(
                        AssetImage('assets/images/database.png')),
                    title: Text(AppLocalizations.of(context)!.updateDatabase),
                    trailing: IconButton(
                        onPressed: () async {
                          setState(() {
                            netLoading = true;
                          });
                          await _settingsController.manager
                              .parseCommandAndRun('-u')
                              .then((value) => setState(() {
                                    netLoading = false;
                                    showSnackBar(context,
                                        AppLocalizations.of(context)!.success);
                                  }));
                        },
                        icon: const ImageIcon(
                            AssetImage('assets/images/refresh.png')))),
                ListTile(
                    leading: const ImageIcon(
                        AssetImage('assets/images/open-folder.png')),
                    title: Text(AppLocalizations.of(context)!.savePath),
                    subtitle: Text(_settingsController.config.output),
                    trailing: IconButton(
                        onPressed: () async {
                          var initDir = await getExternalStorageDirectory()
                              .catchError(
                                  (e) => getApplicationSupportDirectory(),
                                  test: (error) => true)
                              .then((value) async =>
                                  value ??
                                  await getApplicationSupportDirectory());
                          var path = await FilePicker.platform
                              .getDirectoryPath(initialDirectory: initDir.path);
                          if (path?.isNotEmpty == true) {
                            await testWriteble(path!)
                                .then((value) => _settingsController
                                    .updateConfig(_settingsController.config
                                        .copyWith(output: path)))
                                .catchError(
                                    (e) => _settingsController.updateConfig(
                                        _settingsController.config
                                            .copyWith(output: initDir.path)),
                                    test: (error) => true)
                                .then((value) => setState(() {}));
                          }
                        },
                        icon: const Icon(Icons.edit))),
              ]),
              if (netLoading)
                Container(
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator()),
            ])));
  }
}
