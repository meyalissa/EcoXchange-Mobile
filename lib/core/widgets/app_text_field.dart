import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

enum AppTextFieldVariant {
  /// Login screen's bare underline field (icon + text, bottom border only).
  underline,

  /// The boxed/filled field used everywhere else (search bars, forms) —
  /// matches `.form-input`/`.search-bar`.
  boxed,
}

/// EcoXchange Mobile — the two text-field treatments from the HTML design.
/// Wraps a plain `TextFormField` so validation/controllers/focus behaviour
/// is unchanged — this only owns visual presentation.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.variant = AppTextFieldVariant.boxed,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final AppTextFieldVariant variant;

  @override
  Widget build(BuildContext context) {
    final isUnderline = variant == AppTextFieldVariant.underline;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: TextStyle(fontSize: 14, color: isUnderline ? AppColors.green900 : AppColors.n800),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: isUnderline ? AppColors.green400 : AppColors.n400, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: isUnderline ? AppColors.green600 : AppColors.n400) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: suffixIcon,
        filled: !isUnderline,
        fillColor: AppColors.n50,
        isDense: isUnderline,
        contentPadding: isUnderline ? const EdgeInsets.symmetric(vertical: 14) : const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: isUnderline
            ? const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green200, width: 1.5))
            : OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.r12), borderSide: const BorderSide(color: AppColors.n200, width: 1.5)),
        enabledBorder: isUnderline
            ? const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green200, width: 1.5))
            : OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.r12), borderSide: const BorderSide(color: AppColors.n200, width: 1.5)),
        focusedBorder: isUnderline
            ? const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green500, width: 1.5))
            : OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.r12), borderSide: const BorderSide(color: AppColors.green400, width: 1.5)),
        errorBorder: isUnderline
            ? const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.red, width: 1.5))
            : OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.r12), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
      ),
    );
  }
}
