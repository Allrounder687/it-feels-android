import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_glass_container.dart';

class NewMobileNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const NewMobileNavDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: NewGlassContainer(
        borderRadius: NewExperienceTokens.radiusPill,
        blur: NewExperienceTokens.blurIntense,
        backgroundColor: NewExperienceTokens.cardSurface.withValues(alpha: 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(child: _buildDockItem(0, Icons.home_rounded, 'Home')),
            Expanded(child: _buildDockItem(1, Icons.search_rounded, 'Search')),
            Expanded(child: _buildDockItem(2, Icons.library_music_rounded, 'Library')),
            Expanded(child: _buildDockItem(3, Icons.trending_up_rounded, 'Hits')),
            Expanded(child: _buildDockItem(4, Icons.settings_outlined, 'Settings')),
          ],
        ),
      ),
    );
  }

  Widget _buildDockItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onDestinationSelected(index);
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NewExperienceTokens.accentViolet.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? NewExperienceTokens.accentViolet
                  : NewExperienceTokens.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NewExperienceTokens.captionMuted(
                color: isSelected
                    ? NewExperienceTokens.accentViolet
                    : NewExperienceTokens.textMuted,
              ).copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
