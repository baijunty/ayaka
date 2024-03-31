import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  late TextEditingController remoteAddrCon;
  late TextEditingController proxyAddrCon;
  late TextEditingController authControl;
  bool netLoading = false;
  bool direct = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    remoteAddrCon = TextEditingController();
    proxyAddrCon = TextEditingController();
    authControl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = context.read<SettingsController>();
    remoteAddrCon.text = controller.config.remoteHttp;
    proxyAddrCon.text = controller.config.proxy;
    authControl.text = controller.config.auth;
  }

  @override
  void dispose() {
    super.dispose();
    remoteAddrCon.dispose();
    proxyAddrCon.dispose();
    authControl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(children: [
        Column(children: [
          DropdownButton<ThemeMode>(
            value: controller.themeMode,
            onChanged: controller.updateThemeMode,
            items: [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(AppLocalizations.of(context)!.systemTheme),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(AppLocalizations.of(context)!.dayTheme),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(AppLocalizations.of(context)!.darkTheme),
              )
            ],
          ),
          Form(
              key: _formKey,
              child: Column(children: [
                DropdownButton<bool>(
                  value: direct,
                  onChanged: (b) => setState(() {
                    direct = b == true;
                  }),
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text(AppLocalizations.of(context)!.direct),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text(AppLocalizations.of(context)!.proxy),
                    ),
                  ],
                ),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.remoteAddr,
                  ),
                  controller: remoteAddrCon,
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.emptyContent;
                    }
                    if (!value.startsWith('http')) {
                      return AppLocalizations.of(context)!.wrongHttp;
                    }
                    return null;
                  },
                  keyboardType: TextInputType.url,
                ),
                TextFormField(
                  controller: proxyAddrCon,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.proxyAddr,
                  ),
                  validator: (String? value) {
                    if (value == null) {
                      return AppLocalizations.of(context)!.emptyContent;
                    }
                    if (value.startsWith('http')) {
                      return AppLocalizations.of(context)!.wrongHttp;
                    }
                    return null;
                  },
                  keyboardType: TextInputType.url,
                ),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.remoteAddr,
                  ),
                  controller: authControl,
                  keyboardType: TextInputType.text,
                ),
                FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        controller.updateConfig(controller.config.copyWith(
                            proxy: proxyAddrCon.text,
                            auth: authControl.text,
                            remoteHttp: remoteAddrCon.text));
                        controller.useProxy = !direct;
                      }
                    },
                    style: Theme.of(context).elevatedButtonTheme.style,
                    child: Text(AppLocalizations.of(context)!.confirm))
              ])),
          const Divider(
            height: 8,
            color: Colors.transparent,
          ),
          FilledButton(
            onPressed: () async {
              setState(() {
                netLoading = true;
              });
              await controller.manager
                  .parseCommandAndRun('-u')
                  .then((value) => setState(() {
                        netLoading = false;
                      }));
            },
            child: Text(AppLocalizations.of(context)!.updateDatabase),
          ),
          Row(children: [
            Expanded(child: Text(controller.config.output)),
            FilledButton(
                onPressed: () async {
                  var path = await FilePicker.platform.getDirectoryPath();
                  if (path?.isNotEmpty == true) {
                    await controller.updateConfig(
                        controller.config.copyWith(output: path!));
                  }
                  setState(() {});
                },
                child: Text(AppLocalizations.of(context)!.select))
          ]),
        ]),
        if (netLoading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
