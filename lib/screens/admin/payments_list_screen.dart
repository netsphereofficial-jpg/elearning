import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/enrollment_model.dart';
import '../../services/admin_payment_service.dart';
import '../../services/admin_auth_service.dart';

class PaymentsListScreen extends StatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> with SingleTickerProviderStateMixin {
  final AdminPaymentService _paymentService = AdminPaymentService();
  final AdminAuthService _authService = AdminAuthService();

  late TabController _tabController;
  List<EnrollmentModel> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadPayments();
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      List<EnrollmentModel> payments;
      switch (_tabController.index) {
        case 0:
          payments = await _paymentService.getPendingPayments();
          break;
        case 1:
          payments = await _paymentService.getApprovedPayments();
          break;
        case 2:
          payments = await _paymentService.getRejectedPayments();
          break;
        default:
          payments = [];
      }
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approvePayment(EnrollmentModel enrollment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payment'),
        content: Text('Approve payment for ${enrollment.userEmail}?\nCourse: ${enrollment.courseTitle}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final adminId = _authService.currentUser?.uid ?? '';
      final success = await _paymentService.approvePayment(enrollment.id, adminId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment approved'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadPayments();
      }
    }
  }

  Future<void> _rejectPayment(EnrollmentModel enrollment) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject payment for ${enrollment.userEmail}?'),
            const SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final adminId = _authService.currentUser?.uid ?? '';
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a reason')),
        );
        return;
      }

      final success = await _paymentService.rejectPayment(enrollment.id, adminId, reason);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        _loadPayments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _payments.isEmpty
                  ? const Center(child: Text('No payments'))
                  : _buildPaymentsList(),
        ),
      ],
    );
  }

  Widget _buildPaymentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          child: ExpansionTile(
            leading: _buildStatusIcon(payment.status),
            title: Text(payment.userEmail),
            subtitle: Text('${payment.courseTitle} • ₹${payment.amount}'),
            trailing: Text(_formatDate(payment.enrolledAt)),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Transaction ID', payment.transactionId),
                    _buildInfoRow('Amount', '₹${payment.amount}'),
                    _buildInfoRow('Date', _formatDateTime(payment.enrolledAt)),
                    if (payment.validUntil != null)
                      _buildInfoRow('Valid Until', _formatDate(payment.validUntil!)),
                    if (payment.rejectionReason != null)
                      _buildInfoRow('Reason', payment.rejectionReason!),
                    if (payment.status == 'pending') ...[
                      const SizedBox(height: AppTheme.spacingMD),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approvePayment(payment),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectPayment(payment),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.pending, color: AppTheme.warningColor);
      case 'approved':
        return const Icon(Icons.check_circle, color: AppTheme.successColor);
      case 'rejected':
        return const Icon(Icons.cancel, color: AppTheme.errorColor);
      default:
        return const Icon(Icons.help);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMD,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
