import 'package:flutter/material.dart';
import 'package:junko_bodie/config/constants.dart';

class PrivateTournamentAvatar extends StatelessWidget {
  final String avatar;
  final double size;
  const PrivateTournamentAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(avatar);
    final network =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    final url = network
        ? avatar
        : avatar.startsWith('/')
        ? '$apiBaseUrl$avatar'
        : null;
    final icon = switch (avatar) {
      'crown' => Icons.workspace_premium,
      'diamond' => Icons.diamond_outlined,
      'star' => Icons.star,
      'heart' => Icons.favorite,
      'spade' => Icons.spa,
      'club' => Icons.filter_vintage,
      'dice' => Icons.casino,
      'trophy' => Icons.emoji_events_outlined,
      'bolt' => Icons.bolt,
      'chip' => Icons.radio_button_checked,
      _ => Icons.person,
    };
    final fallback = Icon(
      icon,
      size: size * .5,
      color: const Color(0xFFC9A44C),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF183A2A),
        border: Border.all(color: const Color(0x99C9A44C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, error, stack) => fallback,
            ),
    );
  }
}
