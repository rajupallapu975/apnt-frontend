import 'package:rxdart/rxdart.dart';
import '../models/print_order_model.dart';
import '../services/firestore_service.dart';

class OrderRepository {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<List<PrintOrderModel>> getActiveOrders() {
    return Rx.combineLatest2<List<PrintOrderModel>, List<PrintOrderModel>, List<PrintOrderModel>>(
      _firestoreService.getActiveOrders(),
      _firestoreService.getActiveXeroxOrders(),
      (orders, xeroxOrders) {
        final merged = [...orders, ...xeroxOrders];
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return merged;
      },
    );
  }

  Future<List<PrintOrderModel>> getArchivedOrders() {
    return _firestoreService.getArchivedOrders();
  }

  Future<void> createOrder(PrintOrderModel order) {
    // This part should be in OrderService or handled via a proper endpoint
    // For now, mapping it to firestore_service logic if it exists
    return Future.value(); 
  }

  Future<void> attachFiles({
    required String orderId,
    required List<String> fileUrls,
    required List<String> publicIds,
    required List<String> localFilePaths,
  }) {
    return _firestoreService.attachFilesToOrder(
      orderId: orderId,
      fileUrls: fileUrls,
      publicIds: publicIds,
      localFilePaths: localFilePaths,
    );
  }
}
