import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'invoice_screen.dart'; // ← مهم

class SuccessPaymentScreen extends StatefulWidget {
  final String orderId;
  final double total;
  final String address;
  final String phone;
  final String paymentMethod;

  const SuccessPaymentScreen({
    super.key,
    required this.orderId,
    required this.total,
    required this.address,
    required this.phone,
    required this.paymentMethod,
  });

  @override
  _SuccessPaymentScreenState createState() => _SuccessPaymentScreenState();
}

class _SuccessPaymentScreenState extends State<SuccessPaymentScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this);
    _controller.duration = const Duration(seconds: 5);

    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(
            orderIds: [widget.orderId],
            total: widget.total,
            address: widget.address,
            phone: widget.phone,
            paymentMethod: widget.paymentMethod,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          "assets/lottie/card_success.json",
          controller: _controller,
          repeat: false,
          onLoaded: (c) => _controller.forward(),
        ),
      ),
    );
  }
}
