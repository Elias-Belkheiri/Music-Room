import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Primary circular button — 64–72px accent circle (play/pause).
class AcidPrimaryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool pulse;

  const AcidPrimaryButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 64,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.onAccent, size: size * 0.42),
      ),
    );
    if (!pulse) return btn;
    return _PulseWrapper(child: btn);
  }
}

/// Secondary circular button — surface-raised circle (skip/back).
class AcidSecondaryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const AcidSecondaryButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: size * 0.44),
      ),
    );
  }
}

/// Small white circular play badge used on feature cards.
class AcidPlayBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final bool useAccent;

  const AcidPlayBadge({super.key, this.onTap, this.size = 52, this.useAccent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: useAccent ? AppTheme.accent : Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: AppTheme.onAccent,
          size: size * 0.55,
        ),
      ),
    );
  }
}

class _PulseWrapper extends StatefulWidget {
  final Widget child;
  const _PulseWrapper({required this.child});

  @override
  State<_PulseWrapper> createState() => _PulseWrapperState();
}

class _PulseWrapperState extends State<_PulseWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return widget.child;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
