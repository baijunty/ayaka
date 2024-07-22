// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hitomi/gallery/image.dart' as img show ThumbnaiSize, Image;
import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';

typedef _SimpleDecoderCallback = Future<ui.Codec> Function(
    ui.ImmutableBuffer buffer);

class CacheImage extends ImageProvider<CacheImage> {
  final CacheManager manager;
  final img.Image image;
  final String id;
  final img.ThumbnaiSize size;
  final String refererUrl;
  final double scale;
  CacheImage(
      {required this.manager,
      required this.image,
      this.id = '',
      this.size = img.ThumbnaiSize.medium,
      this.refererUrl = 'https://hitomi.la/doujinshi/test.html',
      this.scale = 1.0});

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CacheImage &&
        other.scale == scale &&
        other.refererUrl == refererUrl &&
        other.size == size &&
        other.id == id &&
        other.image == image;
  }

  @override
  int get hashCode => Object.hash(image, id, size, scale, refererUrl);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CacheImage')}("$image", scale: ${scale.toStringAsFixed(1)})';

  @override
  Future<CacheImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CacheImage>(this);
  }

  Future<ui.Codec> _loadAsync(
    CacheImage key,
    StreamController<ImageChunkEvent> chunkEvents, {
    required _SimpleDecoderCallback decode,
  }) async {
    try {
      assert(key == this);
      await for (var element in manager.getFileStream(image.hash,
          headers: {
            'refererUrl': refererUrl,
            'size': size.name,
            'id': id,
            'name': image.name
          },
          key: image.hash,
          withProgress: true)) {
        if (element is DownloadProgress) {
          chunkEvents.add(ImageChunkEvent(
              cumulativeBytesLoaded: element.downloaded,
              expectedTotalBytes: element.totalSize));
        } else if (element is FileInfo) {
          return decode(await ui.ImmutableBuffer.fromUint8List(
              element.file.readAsBytesSync()));
        }
      }
      debugPrint('return null');
      return Future.error('empty date');
    } catch (e) {
      debugPrint('$e');
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  @override
  ImageStreamCompleter loadImage(CacheImage key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CacheImage>('Image key', key),
      ],
    );
  }

  @override
  ImageStreamCompleter loadBuffer(
      CacheImage key, DecoderBufferCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CacheImage>('Image key', key),
      ],
    );
  }
}

class ProxyNetworkImage extends ImageProvider<ProxyNetworkImage> {
  final double scale;

  final Future<List<int>> Function(
      StreamController<ImageChunkEvent> chunkEvents) dataStream;
  final dynamic key;
  ProxyNetworkImage({
    required this.dataStream,
    required this.key,
    this.scale = 1.0,
  });

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ProxyNetworkImage &&
        other.scale == scale &&
        other.key == key;
  }

  @override
  int get hashCode => Object.hash(key, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$key", scale: ${scale.toStringAsFixed(1)})';

  @override
  Future<ProxyNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ProxyNetworkImage>(this);
  }

  Future<ui.Codec> _loadAsync(
    ProxyNetworkImage key,
    StreamController<ImageChunkEvent> chunkEvents, {
    required _SimpleDecoderCallback decode,
  }) async {
    try {
      assert(key == this);

      return await dataStream(chunkEvents)
          .then((value) =>
              ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(value)))
          .then((value) => decode(value));
    } catch (e) {
      debugPrint('$e');
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  @override
  ImageStreamCompleter loadImage(
      ProxyNetworkImage key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<ProxyNetworkImage>('Image key', key),
      ],
    );
  }

  @override
  ImageStreamCompleter loadBuffer(
      ProxyNetworkImage key, DecoderBufferCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<ProxyNetworkImage>('Image key', key),
      ],
    );
  }
}
