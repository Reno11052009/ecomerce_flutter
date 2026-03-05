import 'package:flutter/material.dart';
import 'cart_service.dart';
import 'invoice.dart';
import 'payment_service.dart';
import 'payment_page.dart';

class KeranjangPage extends StatefulWidget {
  const KeranjangPage({super.key});

  @override
  State<KeranjangPage> createState() => _KeranjangPageState();
}

class _KeranjangPageState extends State<KeranjangPage> {
  void _showCheckoutDialog(
    CartService cartService,
    double totalPrice,
    int itemCount,
  ) {
    final tax = totalPrice * 0.1;
    final shippingCost = 25000.0;
    final grandTotal = totalPrice + tax + shippingCost;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Konfirmasi Checkout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal ($itemCount item)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    'Rp ${totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PPN 10%',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    'Rp ${tax.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Biaya Pengiriman',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    'Rp ${shippingCost.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp ${grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _processPayment(cartService, totalPrice, itemCount);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Bayar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processPayment(
    CartService cartService,
    double totalPrice,
    int itemCount,
  ) async {
    late BuildContext loadingContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingContext = ctx;
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(width: 16),
              const Expanded(child: Text('Memproses pembayaran...')),
            ],
          ),
        );
      },
    );

    bool dialogClosed = false;
    void closeLoading() {
      if (!dialogClosed && Navigator.of(loadingContext).canPop()) {
        Navigator.of(loadingContext).pop();
        dialogClosed = true;
      }
    }

    try {
      final items = cartService.items;
      final itemsData = items
          .map(
            (item) => CartItemData(
              id: item.id,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
            ),
          )
          .toList();

      final paymentResponse = await PaymentService.createCheckout(
        items: itemsData,
        customerName: 'Customer',
        customerEmail: 'customer@example.com',
        customerPhone: '08000000000',
      );

      if (!mounted) {
        closeLoading();
        return;
      }
      closeLoading();

      String itemNames = items.map((item) => item.name).join(', ');
      int totalQty = items.fold(0, (sum, item) => sum + item.quantity);

      if (paymentResponse.data.snapToken != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentPage(
              invoiceNumber: paymentResponse.data.invoiceNumber,
              paymentId: paymentResponse.data.paymentId,
              snapToken: paymentResponse.data.snapToken!,
              clientKey: paymentResponse.data.clientKey,
              productName: itemNames,
              quantity: totalQty,
              totalPrice: paymentResponse.data.total,
            ),
          ),
        );
        cartService.clearCart();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Midtrans belum dikonfigurasi, menampilkan invoice...',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InvoicePage(
              productName: itemNames,
              quantity: totalQty,
              totalPrice: paymentResponse.data.total,
              purchaseDate: DateTime.now(),
              invoiceNumber: paymentResponse.data.invoiceNumber,
            ),
          ),
        );
        cartService.clearCart();
      }
    } catch (e) {
      closeLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('Keranjang'), elevation: 1),
      body: AnimatedBuilder(
        animation: cartService,
        builder: (context, child) {
          final cartItems = cartService.items;
          final totalHarga = cartService.totalPrice;
          final totalItems = cartService.itemCount;

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keranjang Kosong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambahkan produk dari daftar',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Belanja Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // List keranjang
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 28,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${item.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      cartService.removeItem(index),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Quantity controller
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => cartService.updateQuantity(
                                    index,
                                    item.quantity - 1,
                                  ),
                                  icon: const Icon(Icons.remove),
                                  iconSize: 20,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => cartService.updateQuantity(
                                    index,
                                    item.quantity + 1,
                                  ),
                                  icon: const Icon(Icons.add),
                                  iconSize: 20,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Rp ${(item.price * item.quantity).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Summary & checkout
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total ($totalItems item)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Rp ${totalHarga.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showCheckoutDialog(
                          cartService,
                          totalHarga,
                          totalItems,
                        ),
                        child: const Text(
                          'Checkout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
