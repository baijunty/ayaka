import 'package:flutter/material.dart';
import 'package:ayaka/src/localization/app_localizations.dart';

MapEntry<String, Color> mapGalleryType(BuildContext context, String type) {
  String showType = '';
  Color color = Colors.transparent;
  switch (type) {
    case 'doujinshi':
      {
        showType = AppLocalizations.of(context)!.doujinshi;
        color = Colors.pinkAccent;
      }
    case 'manga':
      {
        showType = AppLocalizations.of(context)!.manga;
        color = Colors.deepPurpleAccent;
      }
    case 'artistcg':
      {
        showType = AppLocalizations.of(context)!.artistcg;
        color = Colors.blueAccent;
      }
    case 'gamecg':
      {
        showType = AppLocalizations.of(context)!.gamecg;
        color = Colors.teal;
      }
    case 'imageset':
      {
        showType = AppLocalizations.of(context)!.imageset;
        color = Colors.orangeAccent;
      }
    case 'anime':
      {
        showType = AppLocalizations.of(context)!.anime;
        color = Colors.purpleAccent;
      }
  }
  return MapEntry(showType, color);
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
