import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class BrandNavItem {
  const BrandNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barre de navigation flottante SN Devis : l'onglet actif s'élargit en pastille
/// vert clair et affiche son libellé.
class BrandNavBar extends StatelessWidget {
  const BrandNavBar({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<BrandNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  static const _duration = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  final BrandNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;

    final button = Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillAll,
            color: selected ? AppColors.accentSoft : AppColors.accentSoft.withValues(alpha: 0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: _duration,
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(selected ? item.selectedIcon : item.icon, key: ValueKey(selected), color: color, size: 24),
              ),
              // Libellé visible seulement sur l'onglet actif, déployé en douceur
              Flexible(
                child: AnimatedSize(
                  duration: _duration,
                  curve: _curve,
                  child:
                      selected
                          ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // Vert foncé : le vert SN manque de contraste sur le fond vert clair
                              style: const TextStyle(color: AppColors.accentHover, fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: .1),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // L'onglet actif prend la place nécessaire à son libellé, les autres restent compacts
    return selected ? Flexible(child: button) : Tooltip(message: item.label, child: button);
  }
}
