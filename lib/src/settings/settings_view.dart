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
  TextEditingController? remoteAddrCon;
  TextEditingController? proxyAddrCon;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  @override
  void dispose() {
    super.dispose();
    remoteAddrCon?.dispose();
    proxyAddrCon?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (remoteAddrCon == null) {
      controller = context.read<SettingsController>();
      remoteAddrCon =
          TextEditingController(text: controller.manager.config.remoteHttp);
      proxyAddrCon =
          TextEditingController(text: controller.manager.config.proxy);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      // Glue the SettingsController to the theme selection DropdownButton.
      //
      // When a user selects a theme from the dropdown list, the
      // SettingsController is updated, which rebuilds the MaterialApp.
      child: Column(children: [
        DropdownButton<ThemeMode>(
          // Read the selected themeMode from the controller
          value: controller.themeMode,
          // Call the updateThemeMode method any time the user selects a theme.
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
              TextButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      controller.updateConfig(controller.manager.config
                          .copyWith(
                              proxy: proxyAddrCon!.text,
                              remoteHttp: remoteAddrCon!.text));
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.confirm))
            ])),
      ]),
    );
  }
}
