import 'package:collection/collection.dart';
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

  @override
  Future<FileInfo> downloadFile(String url,
      {String? key,
      Map<String, String>? authHeaders,
      bool force = false}) async {
    return super
        .downloadFile(url, key: key, authHeaders: authHeaders, force: force);
  }
}

class ProxyImageServer extends FileService {
  final Hitomi hitomi;

  ProxyImageServer(this.hitomi);

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    var resp = await hitomi.fetchImageData(
      Image(hash: url, hasavif: 0, width: 0, haswebp: 0, name: '', height: 0),
      id: headers?['id']?.toInt() ?? 0,
      size: ThumbnaiSize.values
              .firstWhereOrNull((s) => s.name == headers?['size']) ??
          ThumbnaiSize.medium,
      refererUrl: headers?['refererUrl'] ?? '',
    );
    return HitomiFileServiceResponse(resp, url);
  }
}

class HitomiFileServiceResponse extends FileServiceResponse {
  final DateTime _receivedTime = DateTime.now();

  final List<int> data;
  final String url;
  HitomiFileServiceResponse(this.data, this.url);

  @override
  Stream<List<int>> get content => throw UnimplementedError();

  @override
  int? get contentLength => throw UnimplementedError();

  @override
  String? get eTag => url;

  @override
  String get fileExtension => '$url.jpg';

  @override
  int get statusCode => data.isEmpty ? 404 : 200;

  @override
  DateTime get validTill => _receivedTime.add(const Duration(days: 7));
}
