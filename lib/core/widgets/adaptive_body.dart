import 'package:flutter/material.dart';

/// Limita el ancho del contenido a un máximo legible y lo centra.
///
/// Sigue la skill `flutter-build-responsive-layout`: en pantallas de
/// tablet/desktop, el contenido no se estira a todo el ancho.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
