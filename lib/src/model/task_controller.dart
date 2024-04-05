import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';

class TaskController with ChangeNotifier {
  final TaskManager manager;
  TaskController({required this.manager});

  Future<void> addTask(Gallery gallery) async {
    await manager.parseCommandAndRun(gallery.id.toString());
    notifyListeners();
  }

  Future<void> cancelTask(int id) async {
    await manager.parseCommandAndRun('-p $id');
  }

  Future<void> deleteTask(int id) async {
    await manager.parseCommandAndRun('-d $id');
  }
}
