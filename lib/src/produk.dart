import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Product {
  final int id;
  final String name;
  final String? description;
  final double? price;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.price,
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
      );
}

class ProdukPage extends StatelessWidget {
  const ProdukPage({super.key});

  // Untuk Android emulator: pakai 10.0.2.2 agar mengarah ke komputer host
  // Untuk device fisik: ganti ke IP LAN komputer kamu (mis. 192.168.x.x)
  static const String _baseUrl = 'http://192.168.100.13:8000';

  Future<List<Product>> fetchProducts() async {
    final uri = Uri.parse('$_baseUrl/api/products');
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
    });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Produk'),
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
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.description ?? ''),
                  trailing: p.price != null
                      ? Text('\$${p.price!.toStringAsFixed(2)}')
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}