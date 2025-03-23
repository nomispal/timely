import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered title
          const Text(
            'Trackify Desktop',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Window controls aligned to the right
          Positioned(
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Minimize button
                  _WindowButton(
                    icon: Icons.minimize_rounded,
                    tooltip: 'Minimize',
                    onPressed: () async {
                      await windowManager.minimize();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Maximize/Restore button
                  _WindowButton(
                    icon: Icons.crop_square,
                    tooltip: 'Maximize',
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.restore();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Close button
                  _WindowButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () async {
                      await windowManager.hide();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

// Custom window button widget
class _WindowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            hoverColor: Colors.grey[300],
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                size: 20,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
