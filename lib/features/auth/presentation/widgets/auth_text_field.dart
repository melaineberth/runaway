import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      height: 60,
      color: Colors.white10,
      radius: 30,
      padding: EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 5.0,
      ),
      child: TextFormField(
        validator: validator,
        obscureText: obscureText,
        onTapOutside: (event) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        controller: controller,
        style: context.bodySmall?.copyWith(
          color: Colors.white,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: context.bodySmall?.copyWith(
            color: Colors.white30,
          ),
        ),
      ),
    );
  }
}