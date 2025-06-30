import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';

class ModalSheet extends StatefulWidget {
  final Widget? child;
  final double? height;

  const ModalSheet({super.key, this.child, this.height});

  @override
  State<ModalSheet> createState() => _ModalSheetState();
}

class _ModalSheetState extends State<ModalSheet> {
  double _deviceCornerRadius = 0.0;

  final double _outerPadding = 10.0;      

  @override
  void initState() {
    super.initState();
    // 1️⃣ on interroge le natif une seule fois
    getDeviceCornerRadius().then((r) {
      setState(() => _deviceCornerRadius = r);
    });
  }


  @override
  Widget build(BuildContext context) {
    // Inner R = max(0, Outer – Padding)
    final double innerRadius =
      (_deviceCornerRadius - _outerPadding).clamp(0.0, double.infinity);

    return Padding(
      padding: EdgeInsets.all(_outerPadding),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(innerRadius / 1.5),
            topRight: Radius.circular(innerRadius / 1.5),
            bottomLeft: Radius.circular(innerRadius),
            bottomRight: Radius.circular(innerRadius),
          ),
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.only(
            topLeft: Radius.circular(innerRadius / 1.5),
            topRight: Radius.circular(innerRadius / 1.5),
            bottomLeft: Radius.circular(innerRadius),
            bottomRight: Radius.circular(innerRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}