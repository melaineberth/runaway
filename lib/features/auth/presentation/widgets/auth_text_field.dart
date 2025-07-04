import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? suffixIcon;
  final TextCapitalization? textCapitalization;
  final int? maxLines;
  final String? suffixText;
  final String? initialValue;
  
  const AuthTextField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.obscureText = false,
    this.validator,
    this.enabled = true,
    this.keyboardType,
    this.maxLength,
    this.suffixIcon,
    this.textCapitalization,
    this.maxLines = 1,
    this.suffixText,
    this.initialValue,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool hidePassword = true;

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      height: 60,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      radius: 30,
      padding: EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 5.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: widget.initialValue,
              textCapitalization: widget.textCapitalization ?? TextCapitalization.none,
              autocorrect: false,
              validator: widget.validator,
              obscureText: widget.obscureText ? hidePassword : false,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              maxLength: widget.maxLength,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              controller: widget.controller,
              style: context.bodySmall?.copyWith(
                color: widget.enabled ? context.adaptiveTextPrimary : context.adaptiveDisabled,
              ),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: InputBorder.none,
                suffixText: widget.suffixText,
                hintStyle: context.bodySmall?.copyWith(
                  color: widget.enabled ? context.adaptiveDisabled : context.adaptiveTextSecondary,
                ),
                errorStyle: context.bodySmall?.copyWith(
                  color: Colors.red.shade300,
                  fontSize: 12,
                ),
              ),
              maxLines: widget.maxLines,
            ),
          ),
          if(widget.suffixIcon != null) 
            widget.suffixIcon!,
          if (widget.obscureText)
            hidePassword 
              ? IconButton(onPressed: () {
                    setState(() {
                      hidePassword = !hidePassword;
                    });
                  },
                  icon: Icon(HugeIcons.solidRoundedView),
                )
              : IconButton(onPressed: () {
                    setState(() {
                      hidePassword = !hidePassword;
                    });
                  },
                  icon: Icon(HugeIcons.solidRoundedViewOff),
                )
        ],
      ),
    );
  }
}