import 'package:ayaka/src/settings/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:ayaka/src/settings/settings_service_native.dart'
    if (dart.library.html) 'package:ayaka/src/settings/settings_service_web.dart';

DeviceInfo currentDevice(BuildContext context) {
  var width = MediaQuery.of(context).size.width;
  if (width > 900) {
    return DeviceInfo.deskTop;
  }
  if (width > 600) {
    return DeviceInfo.tablet;
  }
  return DeviceInfo.mobile;
}

Orientation currentOrientation(BuildContext context) {
  return MediaQuery.of(context).orientation;
}

SettingsService initProxyService() {
  return initService();
}

enum DeviceInfo { deskTop, mobile, tablet }
