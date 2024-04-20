// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';

typedef _SimpleDecoderCallback = Future<ui.Codec> Function(
    ui.ImmutableBuffer buffer);

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
