import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? suffixIcon;
  final TextCapitalization? textCapitalization;
  
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.obscureText = false,
    this.validator,
    this.enabled = true,
    this.keyboardType,
    this.maxLength,
    this.suffixIcon,
    this.textCapitalization,
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
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        autocorrect: false,
        validator: validator,
        obscureText: obscureText,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onTapOutside: (event) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        controller: controller,
        style: context.bodySmall?.copyWith(
          color: enabled ? Colors.white : Colors.white38,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          counterText: "", // Cache le compteur de caractères si maxLength est défini
          suffixIcon: suffixIcon,
          hintStyle: context.bodySmall?.copyWith(
            color: enabled ? Colors.white30 : Colors.white12,
          ),
          errorStyle: context.bodySmall?.copyWith(
            color: Colors.red.shade300,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}