import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_theme.dart';
import '../../services/admin_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AdminSettingsService _settingsService = AdminSettingsService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _qrCodeController;
  late TextEditingController _upiIdController;
  late TextEditingController _paymentNoteController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _qrCodeController = TextEditingController();
    _upiIdController = TextEditingController();
    _paymentNoteController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _qrCodeController.dispose();
    _upiIdController.dispose();
    _paymentNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final settings = await _settingsService.getPaymentSettings();

      if (mounted) {
        setState(() {
          _qrCodeController.text = settings['qrCodeImageUrl'] ?? '';
          _upiIdController.text = settings['upiId'] ?? '';
          _paymentNoteController.text = settings['paymentNote'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final success = await _settingsService.updatePaymentSettings(
        qrCodeImageUrl: _qrCodeController.text,
        upiId: _upiIdController.text,
        paymentNote: _paymentNoteController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update settings'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Payment Settings', style: AppTheme.headlineMD),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingLG,
                              vertical: AppTheme.spacingMD,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      'Configure payment QR code and UPI ID for course enrollments',
                      style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
                    ),
                    const Divider(height: AppTheme.spacingXL),

                    // QR Code Image URL
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.qr_code, color: AppTheme.primaryColor),
                                const SizedBox(width: AppTheme.spacingSM),
                                Text('QR Code Image', style: AppTheme.titleMD),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            TextFormField(
                              controller: _qrCodeController,
                              decoration: const InputDecoration(
                                labelText: 'QR Code Image URL',
                                hintText: 'https://example.com/qr-code.png',
                                helperText: 'Enter the URL of your payment QR code image',
                                prefixIcon: Icon(Icons.link),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'QR Code URL is required';
                                }
                                if (!v.startsWith('http://') && !v.startsWith('https://')) {
                                  return 'Please enter a valid URL';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.spacingMD),

                            // QR Code Preview
                            if (_qrCodeController.text.isNotEmpty) ...[
                              Text(
                                'Preview:',
                                style: AppTheme.bodySM.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingSM),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                  maxHeight: 300,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.borderColor),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  child: CachedNetworkImage(
                                    imageUrl: _qrCodeController.text,
                                    placeholder: (context, url) => const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      padding: const EdgeInsets.all(32),
                                      color: Colors.grey[200],
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                                          SizedBox(height: 8),
                                          Text('Invalid QR Code URL'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // UPI ID
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance, color: AppTheme.primaryColor),
                                const SizedBox(width: AppTheme.spacingSM),
                                Text('UPI Details', style: AppTheme.titleMD),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            TextFormField(
                              controller: _upiIdController,
                              decoration: const InputDecoration(
                                labelText: 'UPI ID',
                                hintText: 'example@paytm',
                                helperText: 'Enter your UPI ID for receiving payments',
                                prefixIcon: Icon(Icons.payment),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'UPI ID is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Please enter a valid UPI ID (e.g., username@bank)';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Payment Note
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.note, color: AppTheme.primaryColor),
                                const SizedBox(width: AppTheme.spacingSM),
                                Text('Payment Instructions', style: AppTheme.titleMD),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            TextFormField(
                              controller: _paymentNoteController,
                              decoration: const InputDecoration(
                                labelText: 'Payment Note',
                                hintText: 'Instructions for students...',
                                helperText: 'This note will be shown to students during payment',
                                prefixIcon: Icon(Icons.info_outline),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Payment note is required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: AppTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How to use:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '1. Upload your QR code image to a hosting service (e.g., Firebase Storage, Imgur)\n'
                                  '2. Copy the public URL and paste it in the QR Code field\n'
                                  '3. Enter your UPI ID for manual payments\n'
                                  '4. Add instructions for students in the Payment Note\n'
                                  '5. Click "Save Settings" to apply changes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
