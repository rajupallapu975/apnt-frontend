import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../models/file_model.dart';
import 'package:path/path.dart' as path;
import '../../../../utils/file_validator.dart';

class FilePickerSheet extends StatelessWidget {
  final Function(List<FileModel>) onPickedFiles;

  const FilePickerSheet({super.key, required this.onPickedFiles});

  @override
  Widget build(BuildContext context) {
    final picker = ImagePicker();

    Future<void> pickCamera() async {
      try {
        final image = await picker.pickImage(source: ImageSource.camera);
        if (image == null) return;

        final rawBytes = await image.readAsBytes();
        final clonedBytes = Uint8List.fromList(rawBytes); // 🔥 CLONE IMMEDIATELY
        
        onPickedFiles([
          FileModel(
            id: DateTime.now().toString(),
            name: image.name,
            path: kIsWeb ? '' : image.path,
            file: kIsWeb ? null : File(image.path),
            bytes: clonedBytes,
            addedAt: DateTime.now(),
          )
        ]);
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint("Camera Error: $e");
      }
    }

    Future<void> pickGallery() async {
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;

      final List<FileModel> picked = [];
      final List<String> invalidExtensions = [];

      for (final img in images) {
        if (FileValidator.isValidFile(img.name)) {
          final raw = await img.readAsBytes();
          final cloned = Uint8List.fromList(raw); // 🔥 CLONE IMMEDIATELY
          
          picked.add(FileModel(
            id: DateTime.now().toString(),
            name: img.name,
            path: kIsWeb ? '' : img.path,
            file: kIsWeb ? null : File(img.path),
            bytes: cloned,
            addedAt: DateTime.now(),
          ));
        } else {
          invalidExtensions.add(path.extension(img.name));
        }
      }

      if (invalidExtensions.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Format mismatch: ${invalidExtensions.toSet().join(", ")} not accepted. Only PDF, JPG, JPEG, PNG, BMP, TIFF are allowed.')),
        );
      }

      if (picked.isNotEmpty) {
        onPickedFiles(picked);
        if (context.mounted) Navigator.pop(context);
      }
    }

    Future<void> pickFiles() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
        allowMultiple: true,
        withData: true, // Always fetch data for web & consistency
      );
      if (result == null) return;

      final List<FileModel> picked = [];
      final List<String> invalidExtensions = [];

      for (final f in result.files) {
        if (FileValidator.isValidFile(f.name)) {
          Uint8List? clonedBytes;
          if (f.bytes != null) {
            clonedBytes = Uint8List.fromList(f.bytes!); // 🔥 CLONE IMMEDIATELY
          }

          picked.add(FileModel(
            id: DateTime.now().toString(),
            name: f.name,
            path: f.path ?? '',
            file: f.path == null ? null : File(f.path!),
            bytes: clonedBytes,
            addedAt: DateTime.now(),
          ));
        } else {
          invalidExtensions.add(path.extension(f.name));
        }
      }

      if (invalidExtensions.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Format mismatch: ${invalidExtensions.toSet().join(", ")} not accepted. Only PDF, JPG, JPEG, PNG, BMP, TIFF are allowed.')),
        );
      }

      if (picked.isNotEmpty) {
        onPickedFiles(picked);
        if (context.mounted) Navigator.pop(context);
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Add More Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (kIsWeb) ...[
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
              title: const Text('Camera Scanner'),
              onTap: pickCamera,
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded, color: Colors.indigo),
              title: const Text('Media Picker'),
              onTap: pickFiles,
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.camera_enhance_rounded, color: Colors.pink),
              title: const Text('Camera'),
              onTap: pickCamera,
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.orange),
              title: const Text('Gallery'),
              onTap: pickGallery,
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: Colors.purple),
              title: const Text('Files'),
              onTap: pickFiles,
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
