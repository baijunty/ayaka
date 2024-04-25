import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hitomi/lib.dart';
import 'package:image/image.dart' as image show Command, PngEncoder;
import '../settings/settings_controller.dart';
import 'package:hitomi/gallery/image.dart' as img show Image, ThumbnaiSize;

class GalleryManager with ChangeNotifier {
  final SettingsController controller;
  GalleryManager({required this.controller});

  Future<void> addTask(String command) async {
    controller.useProxy
        ? await controller.manager.dio.post(
            '${controller.config.remoteHttp}/addTask',
            data:
                json.encode({'auth': controller.config.auth, 'task': command}),
            options: Options(headers: {
              'x-real-ip': await NetworkInterface.list().then((value) => value
                  .firstOrNull?.addresses
                  .firstWhereOrNull(
                      (element) => element.type == InternetAddressType.IPv4)
                  ?.address)
            }))
        : await controller.manager.parseCommandAndRun(command);
    notifyListeners();
  }

  Future<void> cancelTask(int id) async {
    controller.useProxy
        ? await controller.manager.dio.post(
            '${controller.config.remoteHttp}/cancel',
            data: json.encode({'auth': controller.config.auth, 'id': id}),
            options: Options(headers: {
              'x-real-ip': await NetworkInterface.list().then((value) => value
                  .firstOrNull?.addresses
                  .firstWhereOrNull(
                      (element) => element.type == InternetAddressType.IPv4)
                  ?.address)
            }))
        : await controller.manager.parseCommandAndRun('-p $id');
  }

  Future<void> deleteTask(int id) async {
    controller.useProxy
        ? await controller.manager.dio.post(
            '${controller.config.remoteHttp}/delete',
            data: json.encode({'auth': controller.config.auth, 'id': id}),
            options: Options(headers: {
              'x-real-ip': await NetworkInterface.list().then((value) => value
                  .firstOrNull?.addresses
                  .firstWhereOrNull(
                      (element) => element.type == InternetAddressType.IPv4)
                  ?.address)
            }))
        : await controller.manager.parseCommandAndRun('-d $id');
  }

  Future<Map<String, dynamic>> listTask() async {
    return controller.useProxy
        ? await controller.manager.dio
            .post<String>('${controller.config.remoteHttp}/listTask',
                data: json.encode({'auth': controller.config.auth}),
                options: Options(responseType: ResponseType.json))
            .then((value) {
            var result = json.decode(value.data!) as Map<String, dynamic>;
            result['pendingTask'] = (result['pendingTask'] as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList();
            result['runningTask'] = (result['runningTask'] as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList();
            return result;
          })
        : await controller.manager.parseCommandAndRun('-l');
  }

  Future<Map<String, dynamic>> checkExist(int id) async {
    return controller.useProxy
        ? controller.manager.dio
            .post<String>('${controller.config.remoteHttp}/checkId',
                data: json.encode({'auth': controller.config.auth, 'id': id}),
                options: Options(responseType: ResponseType.json))
            .then((value) => json.decode(value.data!) as Map<String, dynamic>)
            .catchError((e) => <String, dynamic>{}, test: (error) => true)
        : controller.manager
            .checkExistsId(id)
            .then((value) => {'id': id, 'value': value});
  }

  Future<bool> addAdImageHash(List<String> hashes) async {
    if (controller.useProxy) {
      await controller.manager.dio
          .post<String>('${controller.config.remoteHttp}/addAdMark',
              data:
                  json.encode({'mask': hashes, 'auth': controller.config.auth}),
              options: Options(responseType: ResponseType.json))
          .then((value) => json.decode(value.data!) as Map<String, dynamic>)
          .then((value) => value['success'] as bool)
          .catchError((e) => false, test: (error) => true);
    }
    return hashes
        .asStream()
        .asyncMap(
            (event) => controller.manager.parseCommandAndRun('--admark $event'))
        .fold(true, (previous, element) => previous && element);
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
              .catchError((e) {
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
