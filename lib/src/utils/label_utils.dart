import 'package:flutter/material.dart';
import 'package:ayaka/src/localization/app_localizations.dart';

MapEntry<String, Color> mapGalleryType(BuildContext context, String type) {
  switch (type) {
    case 'doujinshi':
      {
        return MapEntry(
          AppLocalizations.of(context)!.doujinshi,
          Colors.pinkAccent,
        );
      }
    case 'manga':
      {
        return MapEntry(AppLocalizations.of(context)!.manga, Colors.deepPurple);
      }
    case 'artistcg':
      {
        return MapEntry(
          AppLocalizations.of(context)!.artistcg,
          Colors.blueAccent,
        );
      }
    case 'gamecg':
      {
        return MapEntry(AppLocalizations.of(context)!.gamecg, Colors.blueGrey);
      }
    case 'imageset':
      {
        return MapEntry(
          AppLocalizations.of(context)!.imageset,
          Colors.orangeAccent,
        );
      }
    case 'anime':
      {
        return MapEntry(
          AppLocalizations.of(context)!.anime,
          Colors.greenAccent,
        );
      }
    default:
      return MapEntry('', Colors.transparent);
  }
}

String mapLangugeType(BuildContext context, String type) {
  String showType = type;
  switch (type) {
    case 'chinese':
      {
        showType = AppLocalizations.of(context)!.chinese;
      }
    case 'japanese':
      {
        showType = AppLocalizations.of(context)!.japanese;
      }
    case 'english':
      {
        showType = AppLocalizations.of(context)!.english;
      }
  }
  return showType;
}

/// `mapTagType` 支持的全部原始类型。
const tagTypes = <String>[
  'female',
  'male',
  'parody',
  'series',
  'artist',
  'character',
  'group',
  'type',
  'language',
  'tag',
];

/// 把搜索框里手写的类型前缀还原成原始 type。
///
/// 同时接受本地化文案（如 `画师`）与原始类型名（如 `artist`）。
/// 无法识别时返回 null，调用方应当把整段文字当作普通关键词处理。
String? reverseTagType(BuildContext context, String prefix) {
  var key = prefix.trim().toLowerCase();
  if (key.isEmpty) {
    return null;
  }
  if (tagTypes.contains(key)) {
    return key;
  }
  for (var type in tagTypes) {
    if (mapTagType(context, type).toLowerCase() == key) {
      return type;
    }
  }
  return null;
}

String mapTagType(BuildContext context, String type) {
  String showType = '';
  switch (type) {
    case 'female':
      {
        showType = AppLocalizations.of(context)!.female;
      }
    case 'male':
      {
        showType = AppLocalizations.of(context)!.male;
      }
    case 'parody':
    case 'series':
      {
        showType = AppLocalizations.of(context)!.series;
      }
    case 'artist':
      {
        showType = AppLocalizations.of(context)!.artist;
      }
    case 'character':
      {
        showType = AppLocalizations.of(context)!.character;
      }
    case 'group':
      {
        showType = AppLocalizations.of(context)!.group;
      }
    case 'type':
      {
        showType = AppLocalizations.of(context)!.type;
      }
    case 'language':
      {
        showType = AppLocalizations.of(context)!.language;
      }
    case 'tag':
      {
        showType = AppLocalizations.of(context)!.tag;
      }
  }
  return showType;
}
