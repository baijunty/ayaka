import 'package:ayaka/src/settings/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:ayaka/src/settings/settings_service_native.dart'
    if (dart.library.html) 'package:ayaka/src/settings/settings_service_web.dart';

extension Responsive on BuildContext {
  DeviceInfo currentDevice() {
    var width = MediaQuery.of(this).size.width;
    if (width > 900) {
      return DeviceInfo.deskTop;
    }
    if (width > 600) {
      return DeviceInfo.tablet;
    }
    return DeviceInfo.mobile;
  }

  Orientation currentOrientation() {
    return MediaQuery.of(this).orientation;
  }
}

SettingsService initProxyService() {
  return initService();
}

enum DeviceInfo { deskTop, mobile, tablet }
