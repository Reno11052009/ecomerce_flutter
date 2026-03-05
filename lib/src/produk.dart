import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'keranjang.dart';
import 'cart_service.dart';
import 'invoice.dart';
import 'payment_service.dart';
import 'payment_page.dart';

class Product {
  final int id;
  final String name;
  final String? description;
  final double? price;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.price,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    // API Laravel mengirim key "nama", bukan "name"
    name: (json['nama'] ?? json['name'] ?? '').toString(),
    // API Laravel mengirim key "deskripsi", bukan "description"
    description: (json['deskripsi'] ?? json['description'])?.toString(),
    // API Laravel mengirim key "harga", bukan "price"
    price: (json['harga'] ?? json['price']) != null
        ? double.tryParse((json['harga'] ?? json['price']).toString())
        : null,
    // gambar/url
    imageUrl: (json['gambar'] ?? json['image_url'])?.toString(),
  );
}

class ProdukPage extends StatefulWidget {
  const ProdukPage({super.key});

  @override
  State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> {
  // Untuk Android emulator: pakai 10.0.2.2 agar mengarah ke komputer host
  // Untuk device fisik/LAN: ganti ke IP LAN komputer kamu (mis. 192.168.x.x)
  static const String _baseUrl = 'http://192.168.100.13:8000';

  Future<List<Product>> fetchProducts() async {
    final uri = Uri.parse('$_baseUrl/api/products');
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      // Format API: { success: true, data: { items: [ ... ] } }
      final items = (decoded is Map<String, dynamic>)
          ? (decoded['data']?['items'] as List<dynamic>? ?? const [])
          : const <dynamic>[];

      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => Product.fromJson(e))
          .toList();
    } else {
      throw Exception('Gagal memuat produk');
    }
  }

  void _showPurchaseDialog(BuildContext context, Product product) {
    int quantity = 1;
    double totalPrice = (product.price ?? 0) * quantity;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // use dialogContext for closing the dialog only
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Konfirmasi Pembelian',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (product.price != null)
                    Text(
                      'Harga: Rp ${product.price!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jumlah:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (quantity > 1) {
                            setState(() {
                              quantity--;
                              totalPrice = (product.price ?? 0) * quantity;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove),
                        iconSize: 24,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            quantity++;
                            totalPrice = (product.price ?? 0) * quantity;
                          });
                        },
                        icon: const Icon(Icons.add),
                        iconSize: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rp ${totalPrice.toStringAsFixed(0)}',
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
                    // pass the original page context so loading/dialog works correctly
                    _processPurchase(context, product, quantity, totalPrice);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Beli',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processPurchase(
    BuildContext context,
    Product product,
    int quantity,
    double totalPrice,
  ) async {
    // We'll capture the dialog context so we can always close it later
    late BuildContext loadingContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingContext = ctx;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Memproses pembayaran...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu, sedang menghubungi server pembayaran',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    bool dialogClosed = false;
    void closeDialog() {
      if (!dialogClosed && Navigator.of(loadingContext).canPop()) {
        Navigator.of(loadingContext).pop();
        dialogClosed = true;
      }
    }

    try {
      final itemsData = [
        CartItemData(
          id: product.id,
          name: product.name,
          price: product.price ?? 0,
          quantity: quantity,
        ),
      ];

      final paymentResponse = await PaymentService.createCheckout(
        items: itemsData,
        customerName: 'Customer',
        customerEmail: 'customer@example.com',
        customerPhone: '08000000000',
      );

      if (!mounted) {
        closeDialog();
        return;
      }
      closeDialog();

      if (paymentResponse.data.snapToken != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentPage(
              invoiceNumber: paymentResponse.data.invoiceNumber,
              paymentId: paymentResponse.data.paymentId,
              snapToken: paymentResponse.data.snapToken!,
              clientKey: paymentResponse.data.clientKey,
              productName: product.name,
              quantity: quantity,
              totalPrice: paymentResponse.data.total,
            ),
          ),
        );
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
              productName: product.name,
              quantity: quantity,
              totalPrice: totalPrice,
              purchaseDate: DateTime.now(),
              invoiceNumber: paymentResponse.data.invoiceNumber,
            ),
          ),
        );
      }
    } catch (e) {
      closeDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Coba Lagi',
            textColor: Colors.white,
            onPressed: () =>
                _processPurchase(context, product, quantity, totalPrice),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Daftar Produk'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const KeranjangPage(),
                    ),
                  );
                },
                child: AnimatedBuilder(
                  animation: cartService,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 28),
                        if (cartService.itemCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                '${cartService.itemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('Tidak ada produk'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 8),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (p.price != null)
                                      Text(
                                        'Rp ${p.price!.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Deskripsi',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p.description?.isNotEmpty == true
                                          ? p.description!
                                          : 'Tidak ada deskripsi',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _showPurchaseDialog(context, p);
                                      },
                                      child: const Text(
                                        'Beli Sekarang',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        cartService.addItem(
                                          CartItem(
                                            id: p.id,
                                            name: p.name,
                                            price: p.price ?? 0,
                                            quantity: 1,
                                          ),
                                        );
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Produk ditambahkan ke keranjang',
                                            ),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Masukan Keranjang',
                                        style: TextStyle(
                                          color: Colors.green,
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
                        ),
                      );
                    },
                  );
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: p.imageUrl != null
                              ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (p.price != null)
                              Text(
                                'Rp ${p.price!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
