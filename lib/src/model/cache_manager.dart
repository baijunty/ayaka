import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/lib.dart';
import 'package:path/path.dart';

import '../utils/responsive_util.dart';

class HitomiImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'hitomiCacheKey';

  HitomiImageCacheManager(Hitomi hitomi)
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 20,
          repo: defaultCacheInfoRepository(),
          fileService: ProxyImageServer(hitomi),
        ),
      );
}

class ProxyImageServer extends FileService {
  final Hitomi hitomi;

  ProxyImageServer(this.hitomi);

  /// 等待首个进度回调的最长时间。
  ///
  /// 数据总长只用于显示下载进度，拿不到时必须立刻放行：`get()` 一旦永远不返回，
  /// WebHelper 的并发槽位（默认 10 个）会被永久占满，之后所有缩略图请求都只会
  /// 堆在队列里、再也不会被发出（表现为图片一直转圈、请求卡住发不出去）。
  static const _progressTimeout = Duration(milliseconds: 500);

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final size =
        ThumbnaiSize.values.firstWhereOrNull(
          (s) => s.name == headers?['size'],
        ) ??
        ThumbnaiSize.medium;
    final length = Completer<int>();
    final contentStream = hitomi.fetchImageData(
      Image(
        hash: url,
        hasavif: 0,
        width: 0,
        name: headers!['name']!,
        height: 0,
      ),
      size: size,
      refererUrl: headers['refererUrl'] ?? '',
      onProcess: (now, total) {
        if (!length.isCompleted) {
          length.complete(total);
        }
      },
    );
    // 本地仓储读取缩略图、文件缺失等分支不会回调进度，这里必须兜底超时，
    // 否则 get() 永久挂起并拖垮整个缓存管理器的并发队列。
    final contentLength = await length.future.timeout(
      _progressTimeout,
      onTimeout: () => 0,
    );
    return HitomiFileServiceResponse(
      contentStream,
      url,
      // 长度未知时保持 null，交给 Framework 用不确定进度显示，
      // 避免 0 值导致进度条计算出现 NaN。
      contentLength > 0 ? contentLength : null,
      extension(headers['name']!),
    );
  }
}

class HitomiFileServiceResponse extends FileServiceResponse {
  final Stream<List<int>> data;
  final String url;
  final int? length;
  final String extension;
  HitomiFileServiceResponse(this.data, this.url, this.length, this.extension);

  @override
  Stream<List<int>> get content => data;

  @override
  int? get contentLength => length;

  @override
  String? get eTag => url;

  @override
  String get fileExtension => extension;

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 30));
}
