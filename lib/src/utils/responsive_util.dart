import 'package:flutter/material.dart';


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
enum DeviceInfo { deskTop, mobile, tablet }
