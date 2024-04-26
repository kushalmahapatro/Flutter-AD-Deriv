import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

typedef OnUploadProgressCallback = void Function(int sentBytes, int totalBytes);
typedef OnUploadComplete = void Function(int time, dynamic message);
typedef OnUploadError = void Function(dynamic error);

class UploadFile {
  const UploadFile(this.file);

  final File file;

  Future<void> start({
    OnUploadProgressCallback? onUploadProgress,
    OnUploadComplete? onUploadComplete,
    OnUploadError? onUploadError,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    http.Response response;

    try {
      final String filename = path.basename(file.path);
      final String mime =
          lookupMimeType(file.path) ?? 'application/octet-stream';
      final Uri uri = Uri.parse('http://0.0.0.0:8080/image/upload/$filename');

      final MultipartRequest request = MultipartRequest(
        'PUT',
        uri,
        onUploadProgress: onUploadProgress,
      );

      final http.MultipartFile multipartFile =
          await http.MultipartFile.fromPath(
        filename,
        file.path,
      );

      request.headers.addAll({HttpHeaders.contentTypeHeader: mime});

      request.files.add(multipartFile);

      response = await request.send().then(http.Response.fromStream);
    } on http.ClientException catch (e) {
      onUploadError?.call(e);
      throw Exception('Error uploading file: $e');
    } on SocketException catch (e) {
      onUploadError?.call(e);

      throw Exception('Error uploading file: $e');
    } catch (e) {
      onUploadError?.call(e);

      throw Exception('Error uploading file: $e');
    } finally {
      stopwatch.stop();
    }

    if (response.statusCode == 200) {
      onUploadComplete?.call(stopwatch.elapsedMilliseconds, response.body);
    } else {
      onUploadError?.call('Error uploading file: ${response.statusCode}');
    }
  }
}

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(super.method, super.url, {this.onUploadProgress});

  final OnUploadProgressCallback? onUploadProgress;

  @override
  http.ByteStream finalize() {
    final http.ByteStream byteStream = super.finalize();

    final int totalBytes = contentLength;
    int sentBytes = 0;

    final StreamTransformer<List<int>, List<int>> streamTransformer =
        StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        const int chunkSize = 1024;
        final int iterations = data.length ~/ chunkSize;
        final chunkReader = ChunkReader(data, chunkSize);

        if (iterations > 1) {
          while (chunkReader.hasNextChunk()) {
            final chunk = chunkReader.readNextChunk();
            if (chunk.isEmpty) break;

            sentBytes += chunk.length;
            onUploadProgress!(sentBytes, totalBytes);
            sink.add(chunk);
          }
        } else {
          sentBytes += data.length;
          onUploadProgress!(sentBytes, totalBytes);
          sink.add(data);
        }
      },
      handleError: (Object error, StackTrace stack, EventSink<List<int>> sink) {
        sink.addError(error, stack);
        sink.close();
      },
      handleDone: (EventSink<List<int>> sink) {
        sink.close();
      },
    );

    return http.ByteStream(
      byteStream.transform(streamTransformer),
    );
  }
}

class ChunkReader {
  final List<int> data;
  final int chunkSize;
  int currentIndex = 0;

  ChunkReader(this.data, this.chunkSize);

  bool hasNextChunk() {
    return currentIndex < data.length;
  }

  List<int> readNextChunk() {
    if (currentIndex >= data.length) {
      return [];
    }

    final end = (currentIndex + chunkSize) > data.length
        ? data.length
        : currentIndex + chunkSize;
    final chunk = data.sublist(currentIndex, end);
    currentIndex = end;
    return chunk;
  }
}
