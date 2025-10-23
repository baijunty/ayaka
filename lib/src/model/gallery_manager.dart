import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hitomi/lib.dart';
import 'package:image/image.dart' as image show Command, PngEncoder;
import '../settings/settings_controller.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;

import '../utils/responsive_util.dart';

class GalleryManager with ChangeNotifier {
  final SettingsController controller;
  GalleryManager({required this.controller});

  Future<void> addTask(String command) async {
    controller.remoteLib
        ? await controller.manager.dio.post(
            '${controller.config.remoteHttp}/addTask',
            data:
                json.encode({'auth': controller.config.auth, 'task': command}),
            options: Options(headers: {
              'x-real-ip': await localIp(),
            }))
        : await controller.manager.parseCommandAndRun(command);
    notifyListeners();
  }

  Future<void> cancelTask(int id) async {
    controller.remoteLib
        ? await controller.manager.dio
            .post('${controller.config.remoteHttp}/cancel',
                data: json.encode({'auth': controller.config.auth, 'id': id}),
                options: Options(headers: {
                  'x-real-ip': await localIp(),
                }))
        : await controller.manager.parseCommandAndRun('-p $id');
  }

  Future<void> deleteTask(int id) async {
    controller.remoteLib
        ? await controller.manager.dio
            .post('${controller.config.remoteHttp}/delete',
                data: json.encode({'auth': controller.config.auth, 'id': id}),
                options: Options(headers: {
                  'x-real-ip': await localIp(),
                }))
        : await controller.manager.parseCommandAndRun('-d $id');
  }

  Future<Map<String, dynamic>> checkExist(List<dynamic> ids) async {
    return controller.remoteLib
        ? controller.manager.dio
            .post<String>('${controller.config.remoteHttp}/checkId',
                data: json.encode({'auth': controller.config.auth, 'ids': ids}),
                options: Options(responseType: ResponseType.json))
            .then((value) => json.decode(value.data!) as Map<String, dynamic>)
            .catchError((e) => <String, dynamic>{}, test: (error) => true)
        : controller.manager
            .checkExistsId(ids)
            .then((value) => {'success': true, 'value': value});
  }

  Future<bool> addAdImageHash(List<String> hashes) async {
    if (controller.remoteLib) {
      await controller.manager.dio
          .post('${controller.config.remoteHttp}/sync',
              options: Options(headers: {
                'Content-Type': 'application/json',
                'x-real-ip': await localIp()
              }, responseType: ResponseType.json),
              data: {
                'auth': controller.config.auth,
                'mark': admarkMask,
                'content': hashes
              })
          .then((value) => json.decode(value.data!) as Map<String, dynamic>)
          .then((map) => map['success'] as bool)
          .catchError((e) => false, test: (error) => true);
    }
    return controller.manager.addAdMark(hashes);
  }

  Future<Uint8List> makeAnimatedImage(List<img.Image> images, Hitomi api,
      {int id = 0,
      img.ThumbnaiSize size = img.ThumbnaiSize.medium,
      void Function(int index, int total)? onProgress}) async {
    return images
        .asStream()
        .asyncMap((event) {
          onProgress?.call(images.indexOf(event), images.length);
          return api
              .fetchImageData(event,
                  size: size,
                  id: id,
                  refererUrl: 'https://hitomi.la/imageset/test-$id.html')
              .fold(<int>[], (acc, l) => acc..addAll(l)).catchError((e) {
            debugPrint('${event.name} hash ${event.hash} occus $e');
            return <int>[];
          }, test: (error) => true);
        })
        .asyncMap((event) {
          var c = image.Command();
          c.decodeImage(Uint8List.fromList(event));
          return c
              .getImageThread()
              .then((value) => value?..frameDuration = 200);
        })
        .filterNonNull()
        .reduce((previous, element) => element.frames.fold(
            previous, (previousValue, element) => previous..addFrame(element)))
        .then((value) {
          debugPrint('encode length ${value.getBytes().length}');
          return image.PngEncoder(level: 6).encode(value);
        });
  }
}
