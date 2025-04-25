import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final formater = DateFormat('yyyy-MM-dd');
final smallText = TextButton.styleFrom(
  fixedSize: const Size.fromHeight(28),
  padding: const EdgeInsets.all(4),
  minimumSize: const Size(40, 28),
);

extension FlagHelper on int {
  bool isFlagSet(int flag) {
    return this & flag == flag;
  }

  int setMask(int flag) {
    return this | flag;
  }

  int unSetMask(int flag) {
    return this ^ flag;
  }
}

extension DateFormatHelper on DateFormat {
  String formatString(String date) {
    return format(parse(date));
  }
}
