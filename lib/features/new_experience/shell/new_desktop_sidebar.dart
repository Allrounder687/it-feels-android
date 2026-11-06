import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/profile_screen.dart';
import '../theme/new_experience_tokens.dart';

class NewDesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const NewDesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final width = isCollapsed ? 76.0 : 230.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: NewExperienceTokens.obsidianBackground,
        border: Border(
          right: BorderSide(color: NewExperienceTokens.specularBorder, width: 1),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            // Header / App Logo
            // Header / App Logo
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 12 : 16,
                vertical: 20,
              ),
              child: isCollapsed
                  ? InkWell(
                      onTap: onToggleCollapse,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              NewExperienceTokens.accentViolet,
                              NewExperienceTokens.accentCyan,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: NewExperienceTokens.accentViolet.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      NewExperienceTokens.accentViolet,
                                      NewExperienceTokens.accentCyan,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: NewExperienceTokens.accentViolet.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'IT FEELS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: NewExperienceTokens.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(
                            Icons.menu_open_rounded,
                            color: NewExperienceTokens.textMuted,
                            size: 20,
                          ),
                          splashRadius: 16,
                          onPressed: onToggleCollapse,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12),
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.search_rounded,
                    label: 'Search',
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.library_music_rounded,
                    label: 'Library',
                  ),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.trending_up_rounded,
                    label: 'Hits & Discover',
                  ),

                  const SizedBox(height: 16),
                  if (!isCollapsed) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Text(
                        'TOOLS',
                        style: NewExperienceTokens.eyebrowLabel(
                          color: NewExperienceTokens.textMuted,
                        ),
                      ),
                    ),
                  ],

                  _buildNavItem(
                    index: 4,
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI Discovery',
                  ),
                  _buildNavItem(
                    index: 5,
                    icon: Icons.playlist_add_check_rounded,
                    label: 'Spotify Import',
                  ),

                  const SizedBox(height: 16),
                  if (!isCollapsed) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Text(
                        'SETTINGS',
                        style: NewExperienceTokens.eyebrowLabel(
                          color: NewExperienceTokens.textMuted,
                        ),
                      ),
                    ),
                  ],

                  _buildNavItem(
                    index: 6,
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                  ),
                ],
              ),
            ),

            // User Profile Section at bottom
            Consumer(
              builder: (context, ref, _) {
                final authState = ref.watch(authProvider);
                final user = authState.currentUser;

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 12 : 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: NewExperienceTokens.subtleDivider),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisAlignment: isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: NewExperienceTokens.midnightSurface,
                          backgroundImage:
                              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                          child: user?.photoURL == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: NewExperienceTokens.textSecondary,
                                )
                              : null,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user?.displayName ?? 'My Account',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NewExperienceTokens.bodySmall().copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  user?.email ?? 'Cloud Sync Active',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NewExperienceTokens.captionMuted(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: isCollapsed ? label : '',
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? NewExperienceTokens.accentViolet.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
              border: Border.all(
                color: isSelected
                    ? NewExperienceTokens.accentViolet.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? NewExperienceTokens.accentViolet
                          : NewExperienceTokens.textSecondary,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? NewExperienceTokens.accentViolet
                            : NewExperienceTokens.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NewExperienceTokens.bodyMedium(
                            color: isSelected
                                ? NewExperienceTokens.textPrimary
                                : NewExperienceTokens.textSecondary,
                          ).copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

          ),
        ),
      ),
    );
  }
}
