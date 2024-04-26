import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_router/shelf_router.dart';

class ImageRequestHandler {
  const ImageRequestHandler(Db db) : _db = db;

  final Db _db;

  FutureOr<Response> router(Request request) {
    final Router router = Router();

    router.get('/all', _getAllImages);

    router.get('/<id>', getImageFromId);

    router.put('/upload/<name>', _uploadImage);

    return router(request);
  }

  Future<Response> _uploadImage(Request request, String name) async {
    try {
      final FormData formData =
          (await request.multipartFormData.toList()).first;

      final String newPath = 'storage/uploads/${formData.name}';

      File(newPath)
        ..createSync(recursive: true)
        ..writeAsBytes(await formData.part.readBytes(), mode: FileMode.append);

      final WriteResult result = await _db.collection('images').insertOne({
        'name': name,
        'path': newPath,
        'created_at': DateTime.now(),
      });

      if (result.isSuccess) {
        return Response(
          HttpStatus.ok,
          body: jsonEncode(
            {'message': 'Image: uploaded $name', 'id': result.id},
          ),
        );
      } else {
        return Response(HttpStatus.badRequest);
      }
    } catch (e, st) {
      print('exception: $e $st');
      return Response(HttpStatus.badRequest);
    }
  }

  Future<Response> getImageFromId(Request request, String id) async {
    final result = await _db.collection('images').findOne(
          where.eq('_id', ObjectId.fromHexString(id)),
        );

    if (result == null) {
      return Response.notFound('Image not found');
    }

    final File file = File(result['path']);
    final String mime = lookupMimeType(file.path) ?? 'application/octet-stream';
    final String extension = extensionFromMime(mime);
    String name = result['name'];
    if (!name.contains('.$extension')) {
      name = '$name.$extension';
    }
    return Response.ok(file.readAsBytesSync(), headers: {
      'Content-Type': mime,
      'Content-Disposition': 'attachment; filename="$name"',
    });
  }

  Future<Response> _getAllImages(Request request) async {
    final result = await _db.collection('images').find().toList();

    final List<Map<String, dynamic>> images = [];
    for (var i = 0; i < result.length; i++) {
      final String id = (result[i]['_id'] as ObjectId).oid;
      images.add({
        'id': id,
        'name': result[i]['name'],
        'url': 'http://0.0.0.0:8080/image/$id',
        'created_at': result[i]['created_at'].toString(),
      });
    }

    return Response.ok(jsonEncode(images), headers: {
      'Content-Type': 'application/json',
    });
  }
}
