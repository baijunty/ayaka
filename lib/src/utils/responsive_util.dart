import 'package:ayaka/src/settings/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:ayaka/src/settings/settings_service_native.dart'
    if (dart.library.html) 'package:ayaka/src/settings/settings_service_web.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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

Future<String> defaultSavePath() async {
  return platformSavePath();
}

Future<String?> localIp() async {
  return localIpAddress();
}

/// 后端鉴权请求（/sync、/delete 等）携带的 x-real-ip 头。
/// Web 端拿不到浏览器所在机器的局域网 IP（[localIp] 返回空串），空头没有意义，
/// 服务端会以真实连接对端地址兜底，此时干脆不发这个头。
Future<Map<String, String>> realIpHeader() async {
  final ip = await localIp();
  return (ip == null || ip.isEmpty) ? const {} : {'x-real-ip': ip};
}

Future<String> defaultRemoteAddress() {
  return defaultAddress();
}

CacheInfoRepository defaultCacheInfoRepository() {
  return initCacheInfoRepository();
}

enum DeviceInfo { deskTop, mobile, tablet }
