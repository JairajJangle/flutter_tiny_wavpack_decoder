import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'bytes_decode_runner.dart';

/// Message sent to the worker: one decode request.
extension type _WorkerRequest._(JSObject _) implements JSObject {
  external factory _WorkerRequest({
    required int id,
    required String glueUrl,
    required String wasmUrl,
    required JSUint8Array input,
    required int maxSamples,
    required int bitsPerSample,
  });
}

/// Message received from the worker: progress or the final result.
extension type _WorkerResponse._(JSObject _) implements JSObject {
  external int get id;
  external String get type; // 'progress' | 'result'
  external double? get value; // progress value
  external bool get success;
  external String get error;
  external JSArrayBuffer? get output;
}

final class _PendingDecode {
  _PendingDecode(this.completer, this.onProgress);

  final Completer<BytesDecodeResult> completer;
  final void Function(double progress) onProgress;
}

/// [BytesDecodeRunner] backed by the bundled C decoder compiled to WASM,
/// running inside a Web Worker so the UI thread never blocks.
///
/// The worker and WASM module are created lazily on the first decode and
/// reused afterwards. A single worker suffices: the C decoder keeps static
/// state and [TinyWavpackDecoder] serializes decodes anyway.
final class WasmDecodeRunner implements BytesDecodeRunner {
  WasmDecodeRunner._();

  /// The shared runner used by every [TinyWavpackDecoder] on the web.
  static final WasmDecodeRunner instance = WasmDecodeRunner._();

  /// Where flutter serves this package's bundled assets.
  static const String _assetBase =
      'assets/packages/flutter_tiny_wavpack_decoder/web_assets';

  web.Worker? _worker;
  int _nextId = 0;
  final Map<int, _PendingDecode> _pending = {};

  /// Resolves an asset path against the page URL so it stays valid inside
  /// the worker, whose relative URLs resolve against the worker script.
  static String _absoluteAssetUrl(String file) =>
      Uri.base.resolve('$_assetBase/$file').toString();

  web.Worker _ensureWorker() {
    final existing = _worker;
    if (existing != null) {
      return existing;
    }
    final worker = web.Worker(_absoluteAssetUrl('ftwd_worker.js').toJS);
    worker.onmessage = ((web.MessageEvent event) {
      _handleMessage(event);
    }).toJS;
    worker.onerror = ((web.Event event) {
      _failAll(
        'The decoder worker failed to start or crashed. Verify the '
        'flutter_tiny_wavpack_decoder web assets are bundled.',
      );
      worker.terminate();
      _worker = null;
    }).toJS;
    _worker = worker;
    return worker;
  }

  void _handleMessage(web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSObject>()) {
      return;
    }
    final response = data as _WorkerResponse;
    final pending = _pending[response.id];
    if (pending == null) {
      return;
    }
    switch (response.type) {
      case 'progress':
        pending.onProgress(response.value ?? 0);
      case 'result':
        _pending.remove(response.id);
        final output = response.output;
        pending.completer.complete(
          response.success && output != null
              ? BytesDecodeResult.success(output.toDart.asUint8List())
              : BytesDecodeResult.failure(response.error),
        );
    }
  }

  void _failAll(String message) {
    final failed = _pending.values.toList();
    _pending.clear();
    for (final pending in failed) {
      pending.completer.complete(BytesDecodeResult.failure(message));
    }
  }

  @override
  Future<BytesDecodeResult> run(
    BytesDecodeRequest request,
    void Function(double progress) onProgress,
  ) {
    final worker = _ensureWorker();
    final id = _nextId++;
    final completer = Completer<BytesDecodeResult>();
    _pending[id] = _PendingDecode(completer, onProgress);

    // Copy so structured cloning can never observe later mutations of the
    // caller's buffer mid-decode.
    final input = Uint8List.fromList(request.input);
    worker.postMessage(
      _WorkerRequest(
        id: id,
        glueUrl: _absoluteAssetUrl('ftwd.js'),
        wasmUrl: _absoluteAssetUrl('ftwd.wasm'),
        input: input.toJS,
        maxSamples: request.maxSamples,
        bitsPerSample: request.bitsPerSample,
      ),
    );
    return completer.future;
  }
}
