import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'delete_account_page.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  void initState() {
    super.initState();
    // 🌐 Web-compatible browser tab title setter
    SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
        label: 'Privacy Policy | Zikrint',
        primaryColor: 0xFF1F4BFF,
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@zikrint.com',
      queryParameters: {
        'subject': 'Zikrint Privacy Policy Inquiry',
      },
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Navigation: Back to Home ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, '/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF1F4BFF)),
                      label: Text(
                        'Back to Home',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F4BFF),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),

                  // ── Main Content Card ──
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header Branding & Title ──
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F4BFF).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.privacy_tip_rounded,
                                    size: 34,
                                    color: Color(0xFF1F4BFF),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Zikrint',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF1F4BFF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Privacy Policy',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Last Updated: August 2026',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Intro Statement ──
                          Text(
                            'This Privacy Policy explains how Zikrint collects, uses, stores, and protects your information when you use our web and mobile applications and printing services.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 1. Information We Collect ──
                          _buildSectionTitle('1. Information We Collect'),
                          const SizedBox(height: 10),
                          _buildSubHeading('Personal Information'),
                          _buildBulletPoint('Name and account profile information'),
                          _buildBulletPoint('Email address for authentication and notifications'),
                          _buildBulletPoint('Phone number for order verification and SMS updates'),
                          const SizedBox(height: 10),
                          _buildSubHeading('Uploaded Content'),
                          _buildBulletPoint('Photos and documents uploaded for print fulfillment'),
                          const SizedBox(height: 10),
                          _buildSubHeading('Order Information'),
                          _buildBulletPoint('Print settings, paper sizes, xerox shop selections, and payment transaction references'),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 2. Photos and Documents Access ──
                          _buildSectionTitle('2. Photos and Documents Access'),
                          const SizedBox(height: 10),
                          Text(
                            'Zikrint uses the Android system Photo Picker or Document Picker for users to select photos and documents.\n\nZikrint does not access, scan, or collect the user\'s entire photo gallery or media library.\n\nOnly the files that the user explicitly selects are accessed to provide the requested service.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 3. How We Use Your Information ──
                          _buildSectionTitle('3. How We Use Your Information'),
                          const SizedBox(height: 10),
                          _buildBulletPoint('Authenticate users and maintain secure accounts'),
                          _buildBulletPoint('Process and fulfill print and xerox order requests'),
                          _buildBulletPoint('Provide real-time order status tracking and customer support'),
                          _buildBulletPoint('Improve application performance and service reliability'),
                          _buildBulletPoint('Maintain system security and prevent fraudulent activity'),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 4. Third-Party Services ──
                          _buildSectionTitle('4. Third-Party Services'),
                          const SizedBox(height: 10),
                          Text(
                            'We utilize trusted third-party service providers strictly necessary to deliver our print operations. These providers process information only as required to perform their functions:',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),
                          const SizedBox(height: 10),
                          _buildBulletPoint('Firebase Authentication – Secure user identity & login management'),
                          _buildBulletPoint('Cloud Firestore – Real-time order status database'),
                          _buildBulletPoint('Cloudinary – Secure cloud file storage for print processing'),
                          _buildBulletPoint('Razorpay – PCI-DSS compliant payment processing'),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 5. Data Security ──
                          _buildSectionTitle('5. Data Security'),
                          const SizedBox(height: 10),
                          Text(
                            'Data is encrypted during transmission using secure HTTPS/TLS connections. We implement reasonable administrative and technical security controls to protect your information against unauthorized access, alteration, or disclosure. While we strive to maintain robust protection, no internet-based transmission system can guarantee absolute security.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 6. Data Retention ──
                          _buildSectionTitle('6. Data Retention'),
                          const SizedBox(height: 10),
                          Text(
                            'User account information and uploaded print files are retained while your account remains active. Upon receiving an account deletion request, your personal data and uploaded files are permanently removed, except for transaction or financial records retained only where required by applicable laws and regulations.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 7. Account Deletion ──
                          _buildSectionTitle('7. Account Deletion'),
                          const SizedBox(height: 10),
                          Text(
                            'Users can permanently delete their account and associated data directly inside the Zikrint mobile application.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
                              );
                            },
                            icon: const Icon(Icons.delete_forever_rounded, size: 18),
                            label: const Text('View Account Deletion Guide'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F4BFF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 8. Children\'s Privacy ──
                          _buildSectionTitle('8. Children\'s Privacy'),
                          const SizedBox(height: 10),
                          Text(
                            'Zikrint is not intended for children under the applicable minimum age in your jurisdiction, and we do not knowingly collect personal information from children.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 9. Your Rights ──
                          _buildSectionTitle('9. Your Rights'),
                          const SizedBox(height: 10),
                          _buildBulletPoint('Access your profile and order history at any time'),
                          _buildBulletPoint('Update or modify your profile details inside the application'),
                          _buildBulletPoint('Delete your account and personal data permanently'),
                          _buildBulletPoint('Contact our support team for privacy inquiries or assistance'),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 10. Changes to this Privacy Policy ──
                          _buildSectionTitle('10. Changes to this Privacy Policy'),
                          const SizedBox(height: 10),
                          Text(
                            'This Privacy Policy may be updated periodically to reflect changes in legal or operational practices. The latest revised version will always be accessible on this page with the updated revision date.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 20),

                          // ── 11. Contact Us ──
                          _buildSectionTitle('11. Contact Us'),
                          const SizedBox(height: 10),
                          Text(
                            'If you have any questions or concerns regarding this Privacy Policy, please contact us:',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _launchEmail,
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF1F4BFF)),
                                const SizedBox(width: 8),
                                Text(
                                  'support@zikrint.com',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F4BFF),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Footer Copyright ──
                          Center(
                            child: Text(
                              '© 2026 Zikrint. All rights reserved.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildSubHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF1F4BFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
