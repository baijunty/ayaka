import 'dart:io';

import 'package:ayaka/src/ui/common_view.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart' show ReadContext;
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
  late SettingsController controller;
  bool netLoading = false;
  bool useProxyConn = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.read<SettingsController>();
    useProxyConn = controller.useProxy;
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
    var controller = TextEditingController(text: defaultValue);
    return showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
                title: Text(AppLocalizations.of(context)!.inputHint),
                content: TextField(
                  controller: controller,
                  keyboardType: type,
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(controller.text);
                        controller.dispose();
                      },
                      child: Text(AppLocalizations.of(context)!.confirm)),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        controller.dispose();
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
                    leading: Icon(controller.themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.mode_night),
                    title: Text(AppLocalizations.of(context)!.themeMode),
                    subtitle: controller.themeMode == ThemeMode.light
                        ? Text(AppLocalizations.of(context)!.dayTheme)
                        : Text(AppLocalizations.of(context)!.darkTheme),
                    trailing: Switch.adaptive(
                        value: controller.themeMode == ThemeMode.light,
                        onChanged: (b) => setState(() {
                              controller.updateThemeMode(
                                  b ? ThemeMode.light : ThemeMode.dark);
                            }))),
                ListTile(
                    leading:
                        const ImageIcon(AssetImage('assets/images/vpn.png')),
                    title: Text(AppLocalizations.of(context)!.proxy),
                    subtitle: Text(controller.config.proxy),
                    trailing: IconButton(
                        onPressed: () async {
                          var s = await _showDialogInput(
                              type: TextInputType.url,
                              defaultValue: controller.config.proxy);
                          if (s?.isNotEmpty == true) {
                            await controller.updateConfig(
                                controller.config.copyWith(proxy: s!));
                          }
                        },
                        icon: const Icon(Icons.edit))),
                ListTile(
                    leading:
                        const ImageIcon(AssetImage('assets/images/url.png')),
                    title: Text(AppLocalizations.of(context)!.remoteAddr),
                    subtitle: Text(controller.config.remoteHttp),
                    trailing: IconButton(
                        onPressed: () async {
                          var s = await _showDialogInput(
                              type: TextInputType.url,
                              defaultValue: controller.config.remoteHttp);
                          if (s?.isNotEmpty == true) {
                            await controller.updateConfig(
                                controller.config.copyWith(remoteHttp: s!));
                          }
                        },
                        icon: const Icon(Icons.edit))),
                ListTile(
                    leading: const ImageIcon(
                        AssetImage('assets/images/user-authentication.png')),
                    title: Text(AppLocalizations.of(context)!.authToken),
                    subtitle: Text(controller.config.auth),
                    trailing: IconButton(
                        onPressed: () async {
                          var s = await _showDialogInput(
                              type: TextInputType.url,
                              defaultValue: controller.config.auth);
                          if (s?.isNotEmpty == true) {
                            await controller.updateConfig(
                                controller.config.copyWith(auth: s!));
                          }
                        },
                        icon: const Icon(Icons.edit))),
                ListTile(
                    leading: const ImageIcon(
                        AssetImage('assets/images/direction.png')),
                    title: Text(AppLocalizations.of(context)!.connectType),
                    subtitle: Text(useProxyConn
                        ? AppLocalizations.of(context)!.proxy
                        : AppLocalizations.of(context)!.direct),
                    trailing: Switch.adaptive(
                        value: useProxyConn,
                        onChanged: (b) => setState(() {
                              useProxyConn = b;
                              controller.switchConn(b);
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
                          await controller.manager
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
                    subtitle: Text(controller.config.output),
                    trailing: IconButton(
                        onPressed: () async {
                          var initDir = await getExternalStorageDirectory()
                              .catchError(
                                  (e) => getApplicationSupportDirectory(),
                                  test: (error) => true)
                              .then((value) async =>
                                  value ??
                                  await getApplicationSupportDirectory());
                          debugPrint(initDir.path);
                          var path = await FilePicker.platform
                              .getDirectoryPath(initialDirectory: initDir.path);
                          if (path?.isNotEmpty == true) {
                            await testWriteble(path!)
                                .then((value) => controller.updateConfig(
                                    controller.config.copyWith(output: path)))
                                .catchError(
                                    (e) => controller.updateConfig(controller
                                        .config
                                        .copyWith(output: initDir.path)),
                                    test: (error) => true)
                                .then((value) => setState(() {}));
                          }
                        },
                        icon: const Icon(Icons.edit))),
              ]),
              if (netLoading) const Center(child: CircularProgressIndicator()),
            ])));
  }
}
