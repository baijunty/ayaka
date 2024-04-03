import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';

class TaskController with ChangeNotifier {
  final TaskManager manager;
  final Set<int> _taskIds = {};
  TaskController({required this.manager});

  Future<void> addTask(Gallery gallery) async {
    await manager.downLoader.addTask(gallery, handle: (msg) async {
      if (msg is DownLoadFinished && msg.target is List) {
        _taskIds.remove(msg.id);
        if (_taskIds.isEmpty) {
          notifyListeners();
        }
      }
      return true;
    });
    _taskIds.add(gallery.id);
    notifyListeners();
  }

  Future<List<Gallery>> readPenddingTask() async {
    manager.helper
        .querySql('select id from Tasks where completed = ?', [0])
        .then((value) => value.map((element) => element['id'] as int))
        .then((value) => manager.getApiDirect(local: true));
  }

  Future<void> cancelTask(int id) async {
    await manager.downLoader
        .removeTask(id)
        .then((value) => _taskIds.remove(id));
    if (_taskIds.isEmpty) {
      notifyListeners();
    }
  }

  bool get emptyTask => _taskIds.isEmpty;
}
