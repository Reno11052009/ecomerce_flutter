import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  // Untuk Android emulator: pakai 10.0.2.2 agar mengarah ke komputer host
  // Untuk device fisik/LAN: ganti ke IP LAN komputer kamu (mis. 192.168.x.x)
  static const String _baseUrl = 'http://192.168.100.13:8000';

  static Future<PaymentResponse> createCheckout({
    required List<CartItemData> items,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? token,
  }) async {
    try {
      final requestBody = {
        'items': items
            .map((item) => {'product_id': item.id, 'quantity': item.quantity})
            .toList(),
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
      };

      final client = http.Client();
      final response = await client
          .post(
            Uri.parse('$_baseUrl/api/checkout'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30)); // Add 30 second timeout

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return PaymentResponse.fromJson(decoded);
      } else {
        throw PaymentException(
          message: 'Gagal membuat checkout',
          statusCode: response.statusCode,
          response: response.body,
        );
      }
    } catch (e) {
      throw PaymentException(message: e.toString());
    }
  }

  static Future<PaymentStatusResponse> checkPaymentStatus(
    String invoiceNumber, {
    String? token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/invoices/$invoiceNumber'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return PaymentStatusResponse.fromJson(decoded);
      } else {
        throw PaymentException(
          message: 'Gagal mengecek status pembayaran',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw PaymentException(message: e.toString());
    }
  }
}

class CartItemData {
  final int id;
  final String name;
  final double price;
  final int quantity;

  CartItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });
}

class PaymentResponse {
  final bool success;
  final String message;
  final PaymentData data;

  PaymentResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: PaymentData.fromJson(json['data'] ?? {}),
    );
  }
}

class PaymentData {
  final String invoiceNumber;
  final int paymentId;
  final String status;
  final double subtotal;
  final double total;
  final String? snapToken;
  final String? clientKey; // Add client key
  final String? paymentUrl;
  final List<dynamic> items;
  final Map<String, dynamic> customer;
  final String createdAt;

  PaymentData({
    required this.invoiceNumber,
    required this.paymentId,
    required this.status,
    required this.subtotal,
    required this.total,
    required this.snapToken,
    required this.clientKey, // Add to constructor
    required this.paymentUrl,
    required this.items,
    required this.customer,
    required this.createdAt,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      invoiceNumber: json['invoice_number'] ?? '',
      paymentId: json['payment_id'] ?? 0,
      status: json['status'] ?? 'pending',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      snapToken: json['snap_token'],
      clientKey: json['client_key'], // Add client key parsing
      paymentUrl: json['payment_url'],
      items: json['items'] ?? [],
      customer: json['customer'] ?? {},
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PaymentStatusResponse {
  final bool success;
  final String message;
  final Map<String, dynamic> data;

  PaymentStatusResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] ?? {},
    );
  }

  String getStatus() {
    return data['status'] ?? 'unknown';
  }

  bool isPaid() {
    return getStatus() == 'settlement' || getStatus() == 'capture';
  }
}

class PaymentException implements Exception {
  final String message;
  final int? statusCode;
  final String? response;

  PaymentException({required this.message, this.statusCode, this.response});

  @override
  String toString() => 'PaymentException: $message';
}
