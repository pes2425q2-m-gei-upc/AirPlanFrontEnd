import 'package:flutter/material.dart';
import 'dart:async';

/// Servicio de notificaciones que muestra mensajes por encima del contenido
/// sin desplazar la pantalla usando Overlay
class NotificationService {
  /// Muestra una notificación de éxito (verde)
  void showSuccess(BuildContext context, String message) {
    _showNotification(
      context: context,
      message: message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  /// Muestra una notificación de error (roja)
  void showError(BuildContext context, String message) {
    _showNotification(
      context: context,
      message: message,
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  }

  /// Muestra una notificación de información (azul)
  void showInfo(BuildContext context, String message) {
    _showNotification(
      context: context,
      message: message,
      backgroundColor: Colors.blue,
      icon: Icons.info,
    );
  }

  /// Muestra una notificación de advertencia (amarilla)
  static void showWarning(BuildContext context, String message) {
    _showNotification(
      context: context,
      message: message,
      backgroundColor: Colors.amber,
      icon: Icons.warning,
    );
  }

  /// Método privado para mostrar la notificación con Overlay
  static void _showNotification({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlayKey = GlobalKey<_NotificationOverlayState>();
    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => _NotificationOverlay(
            key: overlayKey,
            message: message,
            backgroundColor: backgroundColor,
            icon: icon,
            onDismiss: () {
              overlayEntry.remove();
            },
            duration: duration,
          ),
    );

    overlay.insert(overlayEntry);
  }
}

/// Widget para mostrar la notificación usando Overlay
class _NotificationOverlay extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onDismiss;
  final Duration duration;

  const _NotificationOverlay({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onDismiss,
    required this.duration,
  });

  @override
  _NotificationOverlayState createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Configurar animaciones para entrada
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    // Auto-dismiss after duration
    _timer = Timer(widget.duration, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        // Cancel auto-dismiss and remove overlay immediately
                        _timer?.cancel();
                        widget.onDismiss();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
