import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerSheet extends StatelessWidget {
  final Function(List<File>) onPickedFiles;

  const FilePickerSheet({super.key, required this.onPickedFiles});

  @override
  Widget build(BuildContext context) {
    final picker = ImagePicker();

    Future<void> pickCamera() async {
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      onPickedFiles([File(image.path)]);
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> pickGallery() async {
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;

      onPickedFiles(images.map((e) => File(e.path)).toList());
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> pickFiles() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      if (result == null) return;

      onPickedFiles(
        result.paths.whereType<String>().map((p) => File(p)).toList(),
      );
      if (context.mounted) Navigator.pop(context);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: pickCamera,
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: pickGallery,
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Media picker'),
            onTap: pickFiles,
          ),
        ],
      ),
    );
  }
}
