import 'package:flutter/material.dart';

class SsTextField extends StatelessWidget {
  const SsTextField({
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class SsPasswordField extends StatefulWidget {
  const SsPasswordField({required this.label, this.controller, super.key});

  final String label;
  final TextEditingController? controller;

  @override
  State<SsPasswordField> createState() => _SsPasswordFieldState();
}

class _SsPasswordFieldState extends State<SsPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
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
