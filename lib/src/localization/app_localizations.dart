import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// The title of the application
  ///
  /// In zh, this message translates to:
  /// **'ayaka'**
  String get appTitle;

  /// 系统设置
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get setting;

  /// No description provided for @systemTheme.
  ///
  /// In zh, this message translates to:
  /// **'系统主题'**
  String get systemTheme;

  /// No description provided for @darkTheme.
  ///
  /// In zh, this message translates to:
  /// **'夜间模式'**
  String get darkTheme;

  /// No description provided for @dayTheme.
  ///
  /// In zh, this message translates to:
  /// **'白天模式'**
  String get dayTheme;

  /// No description provided for @artist.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get artist;

  /// No description provided for @series.
  ///
  /// In zh, this message translates to:
  /// **'作品'**
  String get series;

  /// No description provided for @character.
  ///
  /// In zh, this message translates to:
  /// **'人物'**
  String get character;

  /// No description provided for @group.
  ///
  /// In zh, this message translates to:
  /// **'社团'**
  String get group;

  /// No description provided for @type.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get type;

  /// No description provided for @remoteAddr.
  ///
  /// In zh, this message translates to:
  /// **'远程地址'**
  String get remoteAddr;

  /// No description provided for @emptyContent.
  ///
  /// In zh, this message translates to:
  /// **'内容为空'**
  String get emptyContent;

  /// No description provided for @wrongHttp.
  ///
  /// In zh, this message translates to:
  /// **'错误的地址'**
  String get wrongHttp;

  /// No description provided for @read.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get read;

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get downloaded;

  /// No description provided for @collect.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get collect;

  /// No description provided for @like.
  ///
  /// In zh, this message translates to:
  /// **'喜欢'**
  String get like;

  /// No description provided for @proxyAddr.
  ///
  /// In zh, this message translates to:
  /// **'代理地址，格式 127.0.0.1:8080'**
  String get proxyAddr;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @alreadySelected.
  ///
  /// In zh, this message translates to:
  /// **'已选'**
  String get alreadySelected;

  /// No description provided for @exclude.
  ///
  /// In zh, this message translates to:
  /// **'排除'**
  String get exclude;

  /// No description provided for @include.
  ///
  /// In zh, this message translates to:
  /// **'包含'**
  String get include;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @searchLocal.
  ///
  /// In zh, this message translates to:
  /// **'搜索本地'**
  String get searchLocal;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @endOfPage.
  ///
  /// In zh, this message translates to:
  /// **'已经到最后一页'**
  String get endOfPage;

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @addTaskSuccess.
  ///
  /// In zh, this message translates to:
  /// **'添加下载任务成功'**
  String get addTaskSuccess;

  /// No description provided for @doujinshi.
  ///
  /// In zh, this message translates to:
  /// **'同人志'**
  String get doujinshi;

  /// No description provided for @manga.
  ///
  /// In zh, this message translates to:
  /// **'漫画'**
  String get manga;

  /// No description provided for @artistcg.
  ///
  /// In zh, this message translates to:
  /// **'画师CG'**
  String get artistcg;

  /// No description provided for @gamecg.
  ///
  /// In zh, this message translates to:
  /// **'游戏CG'**
  String get gamecg;

  /// No description provided for @imageset.
  ///
  /// In zh, this message translates to:
  /// **'图集'**
  String get imageset;

  /// No description provided for @anime.
  ///
  /// In zh, this message translates to:
  /// **'动画'**
  String get anime;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @japanese.
  ///
  /// In zh, this message translates to:
  /// **'日语'**
  String get japanese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get english;

  /// No description provided for @female.
  ///
  /// In zh, this message translates to:
  /// **'女性'**
  String get female;

  /// No description provided for @male.
  ///
  /// In zh, this message translates to:
  /// **'男性'**
  String get male;

  /// No description provided for @network.
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get network;

  /// No description provided for @local.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get local;

  /// No description provided for @findSimiler.
  ///
  /// In zh, this message translates to:
  /// **'查找类似'**
  String get findSimiler;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @updateDatabase.
  ///
  /// In zh, this message translates to:
  /// **'标签翻译数据库'**
  String get updateDatabase;

  /// No description provided for @select.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get select;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @connectType.
  ///
  /// In zh, this message translates to:
  /// **'连接方式'**
  String get connectType;

  /// No description provided for @direct.
  ///
  /// In zh, this message translates to:
  /// **'本地直连'**
  String get direct;

  /// No description provided for @proxy.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get proxy;

  /// No description provided for @mode.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get mode;

  /// No description provided for @runningTask.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get runningTask;

  /// No description provided for @pendingTask.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get pendingTask;

  /// No description provided for @queryTask.
  ///
  /// In zh, this message translates to:
  /// **'查询任务'**
  String get queryTask;

  /// No description provided for @incompleteTask.
  ///
  /// In zh, this message translates to:
  /// **'未完成任务'**
  String get incompleteTask;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @authToken.
  ///
  /// In zh, this message translates to:
  /// **'校验码'**
  String get authToken;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索,以逗号分割'**
  String get searchHint;

  /// No description provided for @inputHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入内容'**
  String get inputHint;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @savePath.
  ///
  /// In zh, this message translates to:
  /// **'保存目录'**
  String get savePath;

  /// No description provided for @dateDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get dateDefault;

  /// No description provided for @idAsc.
  ///
  /// In zh, this message translates to:
  /// **'从旧到新'**
  String get idAsc;

  /// No description provided for @addTime.
  ///
  /// In zh, this message translates to:
  /// **'最近添加'**
  String get addTime;

  /// No description provided for @blockTag.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽TAG'**
  String get blockTag;

  /// No description provided for @pullToRefresh.
  ///
  /// In zh, this message translates to:
  /// **'下拉刷新'**
  String get pullToRefresh;

  /// No description provided for @releaseReady.
  ///
  /// In zh, this message translates to:
  /// **'释放开始'**
  String get releaseReady;

  /// No description provided for @refreshing.
  ///
  /// In zh, this message translates to:
  /// **'刷新中...'**
  String get refreshing;

  /// No description provided for @noMore.
  ///
  /// In zh, this message translates to:
  /// **'没有更多'**
  String get noMore;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败了'**
  String get failed;

  /// No description provided for @lastUpdatedAt.
  ///
  /// In zh, this message translates to:
  /// **'最后更新于'**
  String get lastUpdatedAt;

  /// No description provided for @pullToLoad.
  ///
  /// In zh, this message translates to:
  /// **'上拉加载'**
  String get pullToLoad;

  /// No description provided for @exitConfirm.
  ///
  /// In zh, this message translates to:
  /// **'再次点击后退退出'**
  String get exitConfirm;

  /// No description provided for @thumb.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get thumb;

  /// No description provided for @origin.
  ///
  /// In zh, this message translates to:
  /// **'原图'**
  String get origin;

  /// No description provided for @wrongId.
  ///
  /// In zh, this message translates to:
  /// **'错误ID'**
  String get wrongId;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get networkError;

  /// No description provided for @makeGif.
  ///
  /// In zh, this message translates to:
  /// **'生成动图'**
  String get makeGif;

  /// No description provided for @runServer.
  ///
  /// In zh, this message translates to:
  /// **'运行服务器'**
  String get runServer;

  /// No description provided for @closed.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get closed;

  /// No description provided for @gallery.
  ///
  /// In zh, this message translates to:
  /// **'画廊'**
  String get gallery;

  /// No description provided for @profile.
  ///
  /// In zh, this message translates to:
  /// **'个人中心'**
  String get profile;

  /// No description provided for @readHistory.
  ///
  /// In zh, this message translates to:
  /// **'阅读历史'**
  String get readHistory;

  /// No description provided for @clearDataWarn.
  ///
  /// In zh, this message translates to:
  /// **'确认清空数据?'**
  String get clearDataWarn;

  /// No description provided for @markAdImg.
  ///
  /// In zh, this message translates to:
  /// **'标记广告图'**
  String get markAdImg;

  /// No description provided for @pageJumpHint.
  ///
  /// In zh, this message translates to:
  /// **'输入跳转页码'**
  String get pageJumpHint;

  /// No description provided for @gallerySorce.
  ///
  /// In zh, this message translates to:
  /// **'图片仓库'**
  String get gallerySorce;

  /// No description provided for @remote.
  ///
  /// In zh, this message translates to:
  /// **'远程'**
  String get remote;

  /// No description provided for @update.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get update;

  /// No description provided for @adImage.
  ///
  /// In zh, this message translates to:
  /// **'广告图'**
  String get adImage;

  /// No description provided for @readLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后阅读'**
  String get readLater;

  /// No description provided for @fix.
  ///
  /// In zh, this message translates to:
  /// **'修复'**
  String get fix;

  /// No description provided for @suggest.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get suggest;

  /// No description provided for @syncData.
  ///
  /// In zh, this message translates to:
  /// **'同步数据'**
  String get syncData;

  /// No description provided for @fixDb.
  ///
  /// In zh, this message translates to:
  /// **'修复数据库'**
  String get fixDb;

  /// No description provided for @tag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tag;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
