import 'package:flutter/material.dart';

class EmailInputField extends StatelessWidget {
  const EmailInputField({
    required this.controller,
    super.key,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    autocorrect: false,
    onFieldSubmitted: onSubmitted,
    decoration: const InputDecoration(
      labelText: 'Email',
      hintText: 'you@example.com',
      prefixIcon: Icon(Icons.email_outlined),
    ),
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Email is required';
      }
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(value)) {
        return 'Enter a valid email address';
      }
      return null;
    },
  );
}
