import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

class RoundedTextField extends StatefulWidget {
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
  final TextCapitalization? textCapitalization;
  final int? maxLines;
  final String? suffixText;
  final String? initialValue;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  
  const RoundedTextField({
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
    this.focusNode,
    this.textCapitalization,
    this.maxLines = 1,
    this.suffixText,
    this.initialValue,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
  });

  @override
  State<RoundedTextField> createState() => _RoundedTextFieldState();
}

class _RoundedTextFieldState extends State<RoundedTextField> {
  bool hidePassword = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: widget.initialValue,
            textCapitalization: widget.textCapitalization ?? TextCapitalization.none,
            autocorrect: false,
            focusNode: widget.focusNode,
            validator: widget.validator,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText ? hidePassword : false,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            maxLength: widget.maxLength,
            onTapOutside: (event) {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            inputFormatters: widget.inputFormatters,
            textAlign: widget.textAlign,
            controller: widget.controller,
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 18,
              color: widget.enabled ? context.adaptiveTextPrimary : context.adaptiveDisabled,
            ),
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                vertical: 10,
              ),
              hintText: widget.hint,
              border: InputBorder.none,
              suffixText: widget.suffixText,
              hintStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 18,
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
    );
  }
}