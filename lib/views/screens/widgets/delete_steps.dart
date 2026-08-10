import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeleteStepsSection extends StatelessWidget {
  const DeleteStepsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'num': '1', 'title': 'Open the Zikrint App', 'icon': Icons.phone_android_rounded},
      {'num': '2', 'title': 'Sign in to your account', 'icon': Icons.login_rounded},
      {'num': '3', 'title': 'Go to Profile', 'icon': Icons.person_outline_rounded},
      {'num': '4', 'title': 'Tap Delete Account', 'icon': Icons.delete_outline_rounded},
      {'num': '5', 'title': 'Confirm the deletion', 'icon': Icons.check_circle_outline_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Delete Your Account',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F4BFF),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          steps[i]['num'].toString(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      steps[i]['icon'] as IconData,
                      size: 20,
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[i]['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 17, top: 8, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        height: 16,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Note: This webpage is for informational purposes only. Account deletion must be completed inside the Zikrint mobile application.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
