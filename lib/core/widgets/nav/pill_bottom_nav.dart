import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  /// Outline glyph — inactive state.
  final IconData icon;

  /// Filled glyph — active state.
  final IconData activeIcon;
  final String label;
}

/// The floating 4-tab dock with a centre FAB — Home · Passport · [+] ·
/// Nutrition · Chat. See README § Navigation and § Radii ("nav pill 26 ·
/// FAB 31 (circle)").
class PillBottomNav extends StatelessWidget {
  const PillBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
  });

  /// Exactly 4 items — 2 render left of the FAB gap, 2 right.
  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabTap;

  static const double _barHeight = 64;
  static const double _fabPokeAbove = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 22),
      child: SizedBox(
        height: _barHeight + _fabPokeAbove,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: _Bar(items: items, currentIndex: currentIndex, onTap: onTap),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _Fab(onTap: onFabTap)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.items, required this.currentIndex, required this.onTap});
  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.sheet(brightness).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.hairline(brightness)),
            boxShadow: brightness == Brightness.light
                ? const [
                    BoxShadow(
                      color: AppColors.navShadowLight,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _NavIcon(item: items[0], isActive: currentIndex == 0, onTap: () => onTap(0)),
              _NavIcon(item: items[1], isActive: currentIndex == 1, onTap: () => onTap(1)),
              const SizedBox(width: 74),
              _NavIcon(item: items[2], isActive: currentIndex == 2, onTap: () => onTap(2)),
              _NavIcon(item: items[3], isActive: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.item, required this.isActive, required this.onTap});
  final PillNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = isActive ? AppColors.accentLight : AppColors.textTertiary(brightness);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: item.label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? item.activeIcon : item.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: AppTextStyles.chipLabel.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.champagne.withValues(alpha: 0.55)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accentDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentDeep.withValues(alpha: 0.5),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 26, color: Color(0xFFF5F4FF)),
        ),
      ),
    );
  }
}
