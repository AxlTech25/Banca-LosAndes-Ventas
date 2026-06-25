import 'package:flutter/material.dart';

abstract final class AppAssets {
  static const logo = 'assets/images/logo_banco_los_andes.png';
  static const logoLegacy = 'assets/images/los_andes_logo.png';
}

class BancoLosAndesLogo extends StatelessWidget {
  const BancoLosAndesLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.onDarkBackground = false,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      AppAssets.logo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          AppAssets.logoLegacy,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              width: width ?? 48,
              height: height ?? 48,
              child: Icon(
                Icons.account_balance,
                color: onDarkBackground ? Colors.white : const Color(0xFF00C1F9),
              ),
            );
          },
        );
      },
    );

    if (onDarkBackground) {
      image = DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: image,
        ),
      );
    } else if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
