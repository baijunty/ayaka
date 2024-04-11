// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';
import 'package:hitomi/gallery/image.dart' as img;
import 'package:hitomi/lib.dart';

typedef _SimpleDecoderCallback = Future<ui.Codec> Function(
    ui.ImmutableBuffer buffer);

class ProxyNetworkImage extends ImageProvider<ProxyNetworkImage> {
  /// Creates an object that fetches the image at the given URL.
  const ProxyNetworkImage(this.id, this.image, this.api,
      {this.scale = 1.0, this.size = img.ThumbnaiSize.medium});
  final double scale;

  final img.Image image;

  final Hitomi api;

  final int id;

  final img.ThumbnaiSize size;
  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ProxyNetworkImage &&
        other.scale == scale &&
        other.size == size &&
        other.id == id &&
        other.image == image;
  }

  @override
  int get hashCode => Object.hash(image, id, size, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$image", scale: ${scale.toStringAsFixed(1)})';

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

      return await api
          .fetchImageData(image,
              id: id,
              size: size,
              refererUrl: 'https://hitomi.la/doujinshi/test-$id.html',
              onProcess: (count, total) => chunkEvents.add(ImageChunkEvent(
                    cumulativeBytesLoaded: count,
                    expectedTotalBytes: total,
                  )))
          .then((value) =>
              ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(value)))
          .then((value) => decode(value));
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
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
