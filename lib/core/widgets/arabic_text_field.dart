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
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;

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
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

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
    );
  }
}
