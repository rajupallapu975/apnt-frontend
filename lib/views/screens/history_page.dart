import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/print_order_model.dart';
import '../../services/firestore_service.dart';
import 'payment_processing_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  final FirestoreService _firestoreService =
      FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =================================================
  // UI
  // =================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Active',
              icon: Icon(Icons.local_printshop),
            ),
            Tab(
              text: 'History',
              icon: Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersStream(
              _firestoreService.getActiveOrders(),
              isActiveTab: true),
          _buildOrdersStream(
              _firestoreService.getUserOrders()),
        ],
      ),
    );
  }

  // =================================================
  // REUSABLE ORDER STREAM BUILDER
  // =================================================

  Widget _buildOrdersStream(
    Stream<List<PrintOrderModel>> stream, {
    bool isActiveTab = false,
  }) {
    return StreamBuilder<List<PrintOrderModel>>(
      stream: stream,
      builder: (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox,
            message: isActiveTab
                ? 'No active orders'
                : 'No orders found',
            subtitle:
                'Your print orders will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(
              orders[index],
              isActive: isActiveTab,
            );
          },
        );
      },
    );
  }

  // =================================================
  // ORDER CARD
  // =================================================

  Widget _buildOrderCard(
    PrintOrderModel order, {
    bool isActive = false,
  }) {
    final dateFormat =
        DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            // ID + Date
            Text(
              'ID: ${order.orderId.substring(0, 8)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(order.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 12),

            // Pickup Code
            Container(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "PICKUP CODE",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600),
                  ),
                  Text(
                    order.pickupCode ?? '----',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Pages + Price
            Text(
              '${order.totalPages} pages • ₹${order.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w500),
            ),

            // Reprint Button (only if not active)
            if (!isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _reprintOrder(order),
                  child: const Text("Reprint"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =================================================
  // REPRINT FLOW (Backend Controlled)
  // =================================================

  Future<void> _reprintOrder(
      PrintOrderModel order) async {

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reprint Order'),
        content: Text(
          'Pages: ${order.totalPages}\n'
          'Price: ₹${order.totalPrice.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentProcessingPage(
          selectedFiles: const [],
          selectedBytes: const [],
          printSettings: order.printSettings,
          expectedPages: order.totalPages,
          expectedPrice: order.totalPrice,
        ),
      ),
    );
  }

  // =================================================
  // EMPTY STATE
  // =================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 70,
              color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
