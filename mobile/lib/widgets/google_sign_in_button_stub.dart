import 'package:flutter/material.dart';

Widget buildGoogleSignInPlatformButton({
  required double size,
  required VoidCallback onPressed,
  required Widget child,
}) {
  return InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(size / 2),
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    ),
  );
}
