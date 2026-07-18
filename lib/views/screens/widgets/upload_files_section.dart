import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../utils/app_colors.dart';
import '../../../models/file_model.dart';
import '../../../services/upload_service.dart';
// order_utils not used in this widget

class UploadFilesSection extends StatefulWidget {
  final String pickupCode;
  final List<FileModel> uploadedFiles;
  final ValueChanged<List<FileModel>> onFilesChanged;
  final ValueChanged<Map<String, String>> onUrlsCompleted; // Maps fileId to Cloudinary URL

  const UploadFilesSection({
    super.key,
    required this.pickupCode,
    required this.uploadedFiles,
    required this.onFilesChanged,
    required this.onUrlsCompleted,
  });

  @override
  State<UploadFilesSection> createState() => _UploadFilesSectionState();
}

class _UploadFilesSectionState extends State<UploadFilesSection> {
  final UploadService _uploadService = UploadService();
  final Map<String, double> _uploadProgress = {}; // Maps fileId to progress double (0.0 to 1.0)
  final Map<String, String?> _uploadErrors = {}; // Maps fileId to error message
  final Map<String, String> _uploadedUrls = {}; // Maps fileId to Cloudinary URL
  final Map<String, StreamSubscription<UploadProgress>?> _subscriptions = {};

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'bmp', 'tiff'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final List<FileModel> newFiles = List.from(widget.uploadedFiles);
      
      for (final file in result.files) {
        final fileModel = FileModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
          name: file.name,
          path: file.path ?? '',
          bytes: file.bytes,
          addedAt: DateTime.now(),
          size: file.size,
        );

        // Validate
        final error = _uploadService.validateFile(fileModel);
        if (error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File error (${file.name}): $error'), backgroundColor: Colors.redAccent),
            );
          }
          continue;
        }

        newFiles.add(fileModel);
        
        // Start immediate upload
        _startUpload(fileModel);
      }

      widget.onFilesChanged(newFiles);
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _startUpload(FileModel file) {
    setState(() {
      _uploadProgress[file.id] = 0.0;
      _uploadErrors[file.id] = null;
    });

    final stream = _uploadService.uploadFile(file, widget.pickupCode);
    
    _subscriptions[file.id]?.cancel();
    _subscriptions[file.id] = stream.listen(
      (progressEvent) {
        if (!mounted) return;
        setState(() {
          _uploadProgress[file.id] = progressEvent.progress;
          if (progressEvent.url != null) {
            _uploadedUrls[file.id] = progressEvent.url!;
            widget.onUrlsCompleted(Map.from(_uploadedUrls));
          }
          if (progressEvent.error != null) {
            _uploadErrors[file.id] = progressEvent.error;
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _uploadErrors[file.id] = err.toString();
        });
      },
    );
  }

  void _removeFile(int index) {
    final file = widget.uploadedFiles[index];
    _subscriptions[file.id]?.cancel();
    _subscriptions.remove(file.id);
    _uploadProgress.remove(file.id);
    _uploadErrors.remove(file.id);
    _uploadedUrls.remove(file.id);

    final updated = List<FileModel>.from(widget.uploadedFiles)..removeAt(index);
    widget.onFilesChanged(updated);
    widget.onUrlsCompleted(Map.from(_uploadedUrls));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Upload Documents',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (widget.uploadedFiles.isEmpty)
            GestureDetector(
              onTap: _pickFiles,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to pick and upload files',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, DOC, DOCX or Images (Max 10MB)',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.uploadedFiles.length,
              separatorBuilder: (_, _b) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final file = widget.uploadedFiles[index];
                final progress = _uploadProgress[file.id] ?? 0.0;
                final error = _uploadErrors[file.id];
                final isCompleted = _uploadedUrls.containsKey(file.id);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Icon type indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success.withValues(alpha: 0.05)
                              : (error != null ? Colors.red[50] : AppColors.primaryBlue.withValues(alpha: 0.05)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          file.name.toLowerCase().endsWith('.pdf')
                              ? Icons.picture_as_pdf_rounded
                              : (file.name.toLowerCase().endsWith('.doc') || file.name.toLowerCase().endsWith('.docx')
                                  ? Icons.article_rounded
                                  : Icons.image_rounded),
                          color: isCompleted
                              ? AppColors.success
                              : (error != null ? Colors.redAccent : AppColors.primaryBlue),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name and progress bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (error != null)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _startUpload(file),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              )
                            else if (isCompleted)
                              Text(
                                'Uploaded successfully',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                              )
                            else
                              Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Remove button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                        onPressed: () => _removeFile(index),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
