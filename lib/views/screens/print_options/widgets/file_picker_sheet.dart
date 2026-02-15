import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../models/file_model.dart';

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

        final bytes = await image.readAsBytes();
        onPickedFiles([
          FileModel(
            id: DateTime.now().toString(),
            name: image.name,
            path: kIsWeb ? '' : image.path,
            file: kIsWeb ? null : File(image.path),
            bytes: bytes,
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
      for (final img in images) {
        picked.add(FileModel(
          id: DateTime.now().toString(),
          name: img.name,
          path: kIsWeb ? '' : img.path,
          file: kIsWeb ? null : File(img.path),
          bytes: await img.readAsBytes(),
          addedAt: DateTime.now(),
        ));
      }

      onPickedFiles(picked);
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> pickFiles() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true, // Always fetch data for web & consistency
      );
      if (result == null) return;

      final List<FileModel> picked = result.files.map((f) => FileModel(
        id: DateTime.now().toString(),
        name: f.name,
        path: f.path ?? '',
        file: f.path == null ? null : File(f.path!),
        bytes: f.bytes,
        addedAt: DateTime.now(),
      )).toList();

      onPickedFiles(picked);
      if (context.mounted) Navigator.pop(context);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Add More Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blue),
            title: const Text('Camera'),
            onTap: pickCamera,
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.orange),
            title: const Text('Gallery'),
            onTap: pickGallery,
          ),
          ListTile(
            leading: const Icon(Icons.folder, color: Colors.purple),
            title: const Text('Files'),
            onTap: pickFiles,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
