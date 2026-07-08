import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text field tuned for Arabic names and labels (RTL input).
class ArabicTextField extends StatelessWidget {
  const ArabicTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onFieldSubmitted,
    this.textInputAction,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      style: GoogleFonts.cairo(),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.text,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
    );
  }
}

/// Single-line field for numbers (LTR).
class NumberTextField extends StatelessWidget {
  const NumberTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      style: GoogleFonts.cairo(),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
    );
  }
}
