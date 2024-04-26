import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:cli/commands/upload_file.dart';
import 'package:cli/utils/logger.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class UpdateCommand extends Command<int> {
  @override
  final String name = 'update';
  @override
  final String description = 'Update the image with the provided logo.';

  UpdateCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'logo',
        abbr: 'l',
        valueHelp: '/path/to/output',
        help: 'Logo to be added on the images.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        valueHelp: '/path/to/output',
        help: 'Output file path.',
      )
      ..addFlag(
        'upload',
        negatable: true,
        defaultsTo: true,
        help: 'Upload the file to a server.',
      );
  }

  final Logger _logger;

  @override
  FutureOr<int>? run() async {
    Directory currentDirectory = Directory.current;

    Directory outputDirectory =
        Directory(path.join(currentDirectory.path, 'generated_images'));

    File logoFile;
    bool upload = argResults?['upload'] ?? true;

    if (!(argResults?.wasParsed('logo') ?? false)) {
      _logger.error('Logo path is not provided. Please provide a path.');
      String? path = stdin.readLineSync();
      if (path != null) {
        logoFile = File(path);
      } else {
        return 0;
      }
    } else {
      logoFile = File(argResults?['logo']);
    }

    if (!logoFile.existsSync()) {
      _logger.error('Logo does not exist.');
      return 0;
    }

    if (!(argResults?.wasParsed('output') ?? false)) {
      _logger.log(
          'Output path is not provided, the current directory will be used as the output path');
    } else {
      outputDirectory = Directory(argResults?['output']);
    }

    _logger.verbose('Output file path: ${outputDirectory.path}');
    if (!outputDirectory.existsSync()) {
      _logger.error(
        'Output directory does not exist. The directory will be created.',
      );
    }

    if (upload) {
      _logger.log(
          'The file will be uploaded to a server. Use --no-upload to disable the auto-upload.');
    } else {
      _logger.log('The file will not be uploaded to a server.');
    }

    final List<FileSystemEntity> filesTOBeUsed = currentDirectory
        .listSync()
        .where((element) => _isImageFile(element))
        .toList();

    _logger.verbose('Total images found: ${filesTOBeUsed.length}');

    if (filesTOBeUsed.isEmpty) {
      _logger.error('No images found in the current directory.');
      return 0;
    }

    final Progress progress = _logger.progress(
      description: 'Adding Logo to ${filesTOBeUsed.length} images...',
      onDoneMessage: 'Adding Logo completed',
      beforeStartMessage: 'Adding Logo started',
      suffixMessage: 'images',
      total: filesTOBeUsed.length,
    );

    for (int i = 0; i < filesTOBeUsed.length; i++) {
      final FileSystemEntity file = filesTOBeUsed[i];
      _logger.verbose(file.path);
      String filename = path.basename(file.path);
      final imageWithWatermark = await Isolate.run(
        () => addLogoToImage(
          originalImageBytes: File(file.path).readAsBytesSync(),
          watermarkImageBytes: logoFile.readAsBytesSync(),
        ),
      );
      outputDirectory.createSync(recursive: true);

      final imageWithLogoFile =
          File(path.join(outputDirectory.path, "updated_$filename"));

      imageWithLogoFile
        ..createSync(recursive: true)
        ..writeAsBytesSync(imageWithWatermark);

      progress.update(((i + 1) / filesTOBeUsed.length) * 100, completed: i + 1);

      _logger.verbose('Image with logo saved to: ${imageWithLogoFile.path}');
    }

    /// Upload files to server
    if (upload) {
      await _uploadFilesToServer(outputDirectory);
    }

    return 1;
  }

  Future<void> _uploadFilesToServer(Directory outputDirectory) async {
    final List<FileSystemEntity> filesToUpload = outputDirectory.listSync();
    for (int i = 0; i < filesToUpload.length; i++) {
      final File file = File(filesToUpload[i].path);

      final int total = (file.readAsBytesSync().length / 1000).ceil();

      final Completer completer = Completer();
      final Progress progress = _logger.progress(
        description: 'Uploading file no: ${(i + 1)}...',
        onDoneMessage: 'Uploading completed',
        beforeStartMessage: 'Uploading started for ${file.path}',
        suffixMessage: 'KB',
        total: total,
      );

      _logger.verbose('Uploading file: ${file.path}');

      await UploadFile(file).start(
        onUploadProgress: (sentBytes, totalBytes) {
          _logger.verbose(
            'Uploading file: Percentage ${sentBytes / totalBytes * 100}, Remaining: ${((total - sentBytes) / 1000).ceil()} KB',
          );

          final double percentage = sentBytes / totalBytes * 100;

          progress.update(
            percentage == 100 ? 99.9 : percentage,
            completed: (sentBytes / 1000).ceil(),
          );
        },
        onUploadComplete: (time, message) async {
          progress.update(
            100,
            completed: total,
            additionalMessage: '$time ms',
          );
          _logger.verbose('Uploaded file: $message in $time ms');
          await Future.delayed(const Duration(seconds: 1));
          completer.complete();
        },
        onUploadError: (error) async {
          _logger.error('Error uploading file: ${error.toString()}');
          progress.cancel();
          await Future.delayed(const Duration(seconds: 1));
          completer.complete();
        },
      );

      await completer.future;
    }
  }

  Future<Uint8List> addLogoToImage({
    required Uint8List originalImageBytes,
    required Uint8List watermarkImageBytes,
  }) async {
    ///Original Image
    final img.Image original = img.decodeImage(originalImageBytes)!;

    ///Watermark Image
    final img.Image logo = img.decodeImage(watermarkImageBytes)!;

    final double logoAspectRatio = logo.width / logo.height;

    // add logo over originalImage
    // initialize width and height of logo image
    final img.Image image = img.Image(
      height: (original.width / logoAspectRatio).ceil(),
      width: original.width,
    );

    /// mix logo image and the newly created image
    img.compositeImage(image, logo);

    // add the created logo image over the original image
    img.compositeImage(
      original,
      image,
      dstX: 0,
      dstY: original.height - image.height,
    );

    ///Encode image to PNG
    final wmImage = img.encodePng(original);

    ///Get the result
    final result = Uint8List.fromList(wmImage);

    return result;
  }

  bool _isImageFile(FileSystemEntity file) =>
      (lookupMimeType(file.path) ?? '').startsWith('image/');
}
