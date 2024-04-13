import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../settings/settings_controller.dart';

class TaskController with ChangeNotifier {
  final SettingsController controller;
  TaskController({required this.controller});

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
}
