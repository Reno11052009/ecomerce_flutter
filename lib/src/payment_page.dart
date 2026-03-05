import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_service.dart';
import 'invoice.dart';

class PaymentPage extends StatefulWidget {
  final String invoiceNumber;
  final int paymentId;
  final String snapToken;
  final String productName;
  final int quantity;
  final double totalPrice;
  final String? clientKey; // Add client key parameter

  const PaymentPage({
    required this.invoiceNumber,
    required this.paymentId,
    required this.snapToken,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    this.clientKey, // Optional for now
    super.key,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.description}')),
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check if payment is completed
            if (request.url.contains('success') ||
                request.url.contains('finish')) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => InvoicePage(
                    productName: widget.productName,
                    quantity: widget.quantity,
                    totalPrice: widget.totalPrice,
                    purchaseDate: DateTime.now(),
                    invoiceNumber: widget.invoiceNumber,
                  ),
                ),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_buildMidtransHtml(widget.snapToken));
  }

  String _buildMidtransHtml(String snapToken) {
    // Use client key if provided, otherwise use sandbox default
    final clientKey = widget.clientKey ?? 'Mid-client-sToh7I8pNKq2miJp';
    final snapUrl = 'https://app.sandbox.midtrans.com/snap/snap.js';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Pembayaran</title>
        <script src="$snapUrl" data-client-key="$clientKey"></script>
        <style>
            body {
                margin: 0;
                padding: 20px;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background-color: #f5f5f5;
            }
            .container {
                max-width: 600px;
                margin: 0 auto;
                background: white;
                padding: 40px;
                border-radius: 12px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                text-align: center;
            }
            h1 {
                color: #333;
                margin-bottom: 20px;
            }
            .loading {
                display: inline-block;
                width: 20px;
                height: 20px;
                border: 3px solid #f3f3f3;
                border-top: 3px solid #16a34a;
                border-radius: 50%;
                animation: spin 1s linear infinite;
            }
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            .info {
                color: #666;
                margin-top: 20px;
                font-size: 14px;
            }
            #pay-button {
                background-color: #16a34a;
                color: white;
                border: none;
                padding: 12px 32px;
                border-radius: 8px;
                font-size: 16px;
                font-weight: 600;
                cursor: pointer;
                margin-top: 20px;
                transition: background-color 0.3s;
            }
            #pay-button:hover {
                background-color: #15803d;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Pembayaran Pesanan</h1>
            <div class="loading"></div>
            <p class="info">Mempersiapkan halaman pembayaran...</p>
            <button id="pay-button">Lanjutkan ke Pembayaran</button>
        </div>

        <script>
            var snapToken = '$snapToken';
            
            document.getElementById('pay-button').addEventListener('click', function() {
                snap.pay(snapToken, {
                    onSuccess: function(result) {
                        // Pembayaran berhasil
                        window.location.href = 'success?order_id=${widget.invoiceNumber}';
                    },
                    onPending: function(result) {
                        // Pembayaran pending
                        alert('Pembayaran pending. Silakan selesaikan pembayaran Anda.');
                    },
                    onError: function(result) {
                        // Ada error
                        alert('Pembayaran gagal!');
                    },
                    onClose: function() {
                        // Pengguna menutup popup tanpa menyelesaikan pembayaran
                        alert('Anda menutup popup pembayaran.');
                    }
                });
            });

            // Auto-trigger payment
            document.getElementById('pay-button').click();
        </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pembayaran'),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showCancelDialog(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Batalkan Pembayaran?'),
          content: const Text(
            'Apakah Anda yakin ingin membatalkan proses pembayaran?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Lanjut Bayar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Batalkan',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
