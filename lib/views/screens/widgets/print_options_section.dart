import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../utils/app_colors.dart';

class PrintOptionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> customParameters;
  final Map<String, dynamic> customValues;
  final ValueChanged<Map<String, dynamic>> onValuesChanged;

  // Standard Xerox parameters
  final int copies;
  final ValueChanged<int> onCopiesChanged;
  final bool isColor;
  final ValueChanged<bool> onColorChanged;
  final bool isPortrait;
  final ValueChanged<bool> onOrientationChanged;
  final bool isDoubleSided;
  final ValueChanged<bool> onDoubleSidedChanged;
  final String selectedPaperSize;
  final List<String> supportedPaperSizes;
  final ValueChanged<String> onPaperSizeChanged;
  
  final bool showStandardOptions; // If Xerox, or if we want standard options enabled

  const PrintOptionsSection({
    super.key,
    required this.customParameters,
    required this.customValues,
    required this.onValuesChanged,
    required this.copies,
    required this.onCopiesChanged,
    required this.isColor,
    required this.onColorChanged,
    required this.isPortrait,
    required this.onOrientationChanged,
    required this.isDoubleSided,
    required this.onDoubleSidedChanged,
    required this.selectedPaperSize,
    required this.supportedPaperSizes,
    required this.onPaperSizeChanged,
    this.showStandardOptions = true,
  });

  @override
  Widget build(BuildContext context) {
    final divider = Divider(color: AppColors.border.withValues(alpha: 0.4), height: 32);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showStandardOptions) ...[
            Text(
              'Print Configurations',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Number of copies
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Number of copies', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('How many prints of this document', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: copies > 1 ? () => onCopiesChanged(copies - 1) : null,
                      ),
                      Text('$copies', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => onCopiesChanged(copies + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            divider,

            // Color Mode
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose color mode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Black & White')),
                        selected: !isColor,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          if (val) onColorChanged(false);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Coloured')),
                        selected: isColor,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          if (val) onColorChanged(true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            divider,

            // Orientation
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose orientation', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Portrait')),
                        selected: isPortrait,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          if (val) onOrientationChanged(true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Landscape')),
                        selected: !isPortrait,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          if (val) onOrientationChanged(false);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            divider,

            // Paper Size (hidden if 1 or 0 paper sizes)
            if (supportedPaperSizes.length > 1) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose paper size', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: supportedPaperSizes.map((size) {
                      final isSelected = selectedPaperSize == size;
                      return ChoiceChip(
                        label: Text(size),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                        checkmarkColor: AppColors.primaryBlue,
                        onSelected: (val) {
                          if (val) onPaperSizeChanged(size);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              divider,
            ],

            // Double Sided
            SwitchListTile.adaptive(
              title: Text('Double sided print', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Print on both sides of paper', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              value: isDoubleSided,
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primaryBlue,
              activeThumbColor: Colors.white,
              onChanged: onDoubleSidedChanged,
            ),
          ],

          // Render Dynamic Custom Parameters
          if (customParameters.isNotEmpty) ...[
            if (showStandardOptions) divider,
            Text(
              'Service Configuration',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customParameters.length,
              separatorBuilder: (_, _b) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final cp = customParameters[index];
                final String name = cp['name'] ?? '';
                final String type = cp['inputType'] ?? 'text';
                final List<String> options = List<String>.from(cp['options'] ?? []);
                final bool isRequired = cp['isRequired'] as bool? ?? false;

                if (type == 'dropdown') {
                  return DropdownButtonFormField<String>(
                    initialValue: customValues[name] as String?,
                    decoration: InputDecoration(
                      labelText: name + (isRequired ? ' *' : ''),
                      border: const OutlineInputBorder(),
                    ),
                    items: options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final updated = Map<String, dynamic>.from(customValues)..[name] = val;
                      onValuesChanged(updated);
                    },
                    validator: (val) {
                      if (isRequired && (val == null || val.isEmpty)) {
                        return '$name is required';
                      }
                      return null;
                    },
                  );
                } else if (type == 'radio') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name + (isRequired ? ' *' : ''), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: options.map((opt) {
                          final isSelected = customValues[name] == opt;
                          return ChoiceChip(
                            label: Text(opt),
                            selected: isSelected,
                            selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                            checkmarkColor: AppColors.primaryBlue,
                            onSelected: (val) {
                              if (val) {
                                final updated = Map<String, dynamic>.from(customValues)..[name] = opt;
                                onValuesChanged(updated);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                } else if (type == 'checkbox') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name + (isRequired ? ' *' : ''), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: options.map((opt) {
                          final List<String> list = List<String>.from(customValues[name] ?? []);
                          final isChecked = list.contains(opt);
                          return FilterChip(
                            label: Text(opt),
                            selected: isChecked,
                            selectedColor: AppColors.primaryBlue.withValues(alpha: 0.05),
                            checkmarkColor: AppColors.primaryBlue,
                            onSelected: (val) {
                              if (val) {
                                list.add(opt);
                              } else {
                                list.remove(opt);
                              }
                              final updated = Map<String, dynamic>.from(customValues)..[name] = list;
                              onValuesChanged(updated);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                } else if (type == 'switch') {
                  return SwitchListTile.adaptive(
                    title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    value: customValues[name] as bool? ?? false,
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppColors.primaryBlue,
                    activeThumbColor: Colors.white,
                    onChanged: (val) {
                      final updated = Map<String, dynamic>.from(customValues)..[name] = val;
                      onValuesChanged(updated);
                    },
                  );
                } else if (type == 'counter') {
                  final int count = customValues[name] as int? ?? 1;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: count > 1 ? () {
                                final updated = Map<String, dynamic>.from(customValues)..[name] = count - 1;
                                onValuesChanged(updated);
                              } : null,
                            ),
                            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: () {
                                final updated = Map<String, dynamic>.from(customValues)..[name] = count + 1;
                                onValuesChanged(updated);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else if (type == 'file') {
                  final String fileName = customValues[name] as String? ?? 'No file selected';
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name + (isRequired ? ' *' : ''), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(fileName, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Choose File'),
                        onPressed: () async {
                          final pickerResult = await FilePicker.platform.pickFiles();
                          if (pickerResult != null && pickerResult.files.isNotEmpty) {
                            final updated = Map<String, dynamic>.from(customValues)..[name] = pickerResult.files.first.name;
                            onValuesChanged(updated);
                          }
                        },
                      ),
                    ],
                  );
                } else if (type == 'number') {
                  return TextFormField(
                    initialValue: customValues[name] as String? ?? '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: name + (isRequired ? ' *' : ''),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final updated = Map<String, dynamic>.from(customValues)..[name] = val;
                      onValuesChanged(updated);
                    },
                    validator: (val) {
                      if (isRequired && (val == null || val.isEmpty)) {
                        return '$name is required';
                      }
                      return null;
                    },
                  );
                } else {
                  return TextFormField(
                    initialValue: customValues[name] as String? ?? '',
                    decoration: InputDecoration(
                      labelText: name + (isRequired ? ' *' : ''),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final updated = Map<String, dynamic>.from(customValues)..[name] = val;
                      onValuesChanged(updated);
                    },
                    validator: (val) {
                      if (isRequired && (val == null || val.isEmpty)) {
                        return '$name is required';
                      }
                      return null;
                    },
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
