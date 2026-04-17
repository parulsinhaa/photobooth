// lib/shared/widgets/gradient_button.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final Color? textColor;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.text,
    this.onTap,
    this.gradient,
    this.textColor,
    this.isLoading = false,
    this.height = 56,
    this.borderRadius = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: isLoading
            ? const LinearGradient(colors: [Color(0xFF444444), Color(0xFF333333)])
            : (gradient ?? AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isLoading ? null : [
            BoxShadow(
              color: AppColors.pink.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
        ),
      ),
    );
  }
}
