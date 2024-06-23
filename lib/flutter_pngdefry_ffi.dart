import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ffi' as ffi;
import 'flutter_pngdefry_ffi_bindings_generated.dart';

import 'package:ffi/ffi.dart';

extension Utf8Pointer on String {
  ffi.Pointer<ffi.Char> toNativeUtf8Pointer() {
    return toNativeUtf8().cast<ffi.Char>();
  }
}

extension DartString on ffi.Pointer<ffi.Char> {
  String toDartString() {
    return cast<Utf8>().toDartString();
  }
}

Future<bool> isPhonePngAsync(String filePath) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextPhonePngRequestId++;
  final _IsPhonePngRequest request = _IsPhonePngRequest(requestId, filePath);
  final Completer<bool> completer = Completer<bool>();
  _IsPhonePngRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

Future<String> storePngAsync(String filePath, String outputPath) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextPhonePngRequestId++;
  final _StorePngRequest request =
      _StorePngRequest(requestId, filePath, outputPath);
  final Completer<String> completer = Completer<String>();
  _StorePngRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

const String _libName = 'flutter_pngdefry_ffi';

/// The dynamic library in which the symbols for [FlutterPngdefryFfiBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final FlutterPngdefryFfiBindings _bindings = FlutterPngdefryFfiBindings(_dylib);

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _IsPhonePngRequest {
  final int id;
  final String filePath;

  const _IsPhonePngRequest(this.id, this.filePath);
}

class _StorePngRequest {
  final int id;
  final String filePath;
  final String outputPath;

  const _StorePngRequest(this.id, this.filePath, this.outputPath);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _IsPhonePngResponse {
  final int id;
  final bool result;

  const _IsPhonePngResponse(this.id, this.result);
}

class _StorePngResponse {
  final int id;
  final String? result;

  const _StorePngResponse(this.id, this.result);
}

/// Counter to identify [_IsPhonePngRequest]s and [_IsPhonePngResponse]s.
int _nextSumRequestId = 0;
int _nextPhonePngRequestId = 0;

/// Mapping from [_IsPhonePngRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<bool>> _IsPhonePngRequests = <int, Completer<bool>>{};
final Map<int, Completer<String>> _StorePngRequests =
    <int, Completer<String>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _IsPhonePngResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<bool> completer = _IsPhonePngRequests[data.id]!;
        _IsPhonePngRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      if (data is _StorePngResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<String> completer = _StorePngRequests[data.id]!;
        _StorePngRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _IsPhonePngRequest) {
          var filePath = data.filePath.toNativeUtf8Pointer();
          try {
            final int result = _bindings.is_iphone_png(filePath);
            final _IsPhonePngResponse response =
                _IsPhonePngResponse(data.id, result == 1);
            sendPort.send(response);
          } finally {
            malloc.free(filePath);
          }
          return;
        }
        if (data is _StorePngRequest) {
          var filePath = data.filePath.toNativeUtf8Pointer();
          var outputPath = data.outputPath.toNativeUtf8Pointer();
          try {
            final ffi.Pointer<ffi.Char> result =
                _bindings.restore_png(filePath, outputPath);
            if (result == ffi.Pointer<ffi.Char>.fromAddress(0)) {
              final _StorePngResponse response =
                  _StorePngResponse(data.id, null);
              sendPort.send(response);
              return;
            }
            final String resultString = result.toDartString();
            final _StorePngResponse response =
                _StorePngResponse(data.id, resultString);
            sendPort.send(response);
          } finally {
            malloc.free(filePath);
            malloc.free(outputPath);
          }
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
