import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/lib.dart';

class HitomiImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'hitomiCacheKey';

  HitomiImageCacheManager(Hitomi hitomi)
      : super(Config(key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 20,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: ProxyImageServer(hitomi)));
}

class ProxyImageServer extends FileService {
  final Hitomi hitomi;

  ProxyImageServer(this.hitomi);

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    final streamController = StreamController<int>();
    final contentStream = StreamController<List<int>>();
    final size = ThumbnaiSize.values
            .firstWhereOrNull((s) => s.name == headers?['size']) ??
        ThumbnaiSize.medium;
    hitomi
        .fetchImageData(
      Image(
          hash: url,
          hasavif: 0,
          width: 0,
          haswebp: 0,
          name: headers!['name']!,
          height: 0),
      id: headers['id']?.toInt() ?? 0,
      size: size,
      refererUrl: headers['refererUrl'] ?? '',
      onProcess: (now, total) => streamController.add(total),
    )
        .then((d) {
      contentStream.add(d);
      contentStream.close();
      streamController.close();
    }).catchError((e) {
      debugPrint('error: $e');
      contentStream.addError(e);
      streamController.addError(e);
      contentStream.close();
      streamController.close();
    }, test: (error) => true);
    return HitomiFileServiceResponse(contentStream.stream, '$url(${size.name})',
        await streamController.stream.first);
  }
}

class HitomiFileServiceResponse extends FileServiceResponse {
  final DateTime _receivedTime = DateTime.now();
  final Stream<List<int>> data;
  final String url;
  final int length;
  HitomiFileServiceResponse(this.data, this.url, this.length);

  @override
  Stream<List<int>> get content => data;

  @override
  int? get contentLength => length;

  @override
  String? get eTag => url;

  @override
  String get fileExtension => '.jpg';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => _receivedTime.add(const Duration(days: 7));
}
