import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? suffixIcon;
  final Widget? bottom;
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
    this.autofocus = false,
    this.keyboardType,
    this.maxLength,
    this.suffixIcon,
    this.bottom,
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
      radius: 50.0,
      gradient: false,
      padding: EdgeInsets.symmetric(
        horizontal: 15.0,
        vertical: 5.0,
      ),
      color: context.adaptiveDisabled.withValues(alpha: 0.08),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 50, // Hauteur minimale du champ
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    autofocus: widget.autofocus,
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
                    style: GoogleFonts.inter(
                      color: widget.enabled ? context.adaptiveTextPrimary : context.adaptiveDisabled,
                      fontWeight: FontWeight.w500,
                      fontSize: 17,
                    ),
                    onChanged: widget.onChanged,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      border: InputBorder.none,
                      suffixText: widget.suffixText,
                      hintStyle: GoogleFonts.inter(
                        color: widget.enabled ? context.adaptiveDisabled : context.adaptiveTextSecondary,
                        fontWeight: FontWeight.w500,
                      fontSize: 17,
                      ),
                      errorStyle: context.bodySmall?.copyWith(
                        color: Colors.red.shade300,
                        fontSize: 12,
                      ),
                      errorMaxLines: 2,
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
                        icon: Icon(
                          HugeIcons.solidRoundedView,
                          color: context.adaptiveDisabled,
                        ),
                      )
                    : IconButton(onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                        icon: Icon(
                          HugeIcons.solidRoundedViewOff,
                          color: context.adaptiveDisabled,
                        ),
                      )
              ],
            ),
          ),
          if (widget.bottom != null)
            widget.bottom!,
        ],
      ),
    );
  }
}