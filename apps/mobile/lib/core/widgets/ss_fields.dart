import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class SsTextField extends StatelessWidget {
  const SsTextField({
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    super.key,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class SsPasswordField extends StatefulWidget {
  const SsPasswordField({
    required this.label,
    this.controller,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<SsPasswordField> createState() => _SsPasswordFieldState();
}

class _SsPasswordFieldState extends State<SsPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscureText
              ? context.l10n.showPasswordAction
              : context.l10n.hidePasswordAction,
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
