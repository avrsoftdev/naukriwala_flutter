import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:developer' as dev;

import '../services/admob_service_new.dart';

class PersistentBannerAd extends StatefulWidget {
  const PersistentBannerAd({super.key});

  @override
  State<PersistentBannerAd> createState() => _PersistentBannerAdState();
}

class _PersistentBannerAdState extends State<PersistentBannerAd> {
  final AdMobService _adMobService = AdMobService();
  final AdSize _adSize = AdSize.banner;
  bool _isLoaded = false;
  bool _hasLoggedLoaded = false;
  bool _hasLoggedFailed = false;

  @override
  void initState() {
    super.initState();
    _adMobService.createBannerAd(
      adSize: _adSize,
      onAdFailedToLoad: (ad) {
        if (!mounted) return;
        if (!_hasLoggedFailed) {
          _hasLoggedFailed = true;
          dev.log('AdMob banner failed to load', name: 'AdMob');
        }
        setState(() => _isLoaded = false);
      },
      onAdLoaded: (ad) {
        if (!mounted) return;
        if (!_hasLoggedLoaded) {
          _hasLoggedLoaded = true;
          // One-time log to confirm actual ad load in release logs.
          // ignore: avoid_print
          print('AdMob banner loaded');
        }
        setState(() => _isLoaded = true);
      },
    );
  }

  @override
  void dispose() {
    _adMobService.disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adWidget = _adMobService.getBannerAdWidget();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      alignment: Alignment.center,
      child: (_isLoaded && adWidget != null)
          ? SizedBox(
              width: _adSize.width.toDouble(),
              height: _adSize.height.toDouble(),
              child: adWidget,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return _ShimmerBox(
                  width: width,
                  height: _adSize.height.toDouble(),
                );
              },
            ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFFE6E6E6);
    const highlightColor = Color(0xFFF5F5F5);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx = (widget.width * 2) * _controller.value - widget.width;
              return ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: const [baseColor, highlightColor, baseColor],
                    stops: const [0.1, 0.5, 0.9],
                    transform: _SlidingGradientTransform(Offset(dx, 0)),
                  ).createShader(rect);
                },
                blendMode: BlendMode.srcATop,
                child: child,
              );
            },
            child: Container(
              width: widget.width,
              height: widget.height,
              color: baseColor,
            ),
          ),
          Text(
            'Loading Ad...',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.translate);

  final Offset translate;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(translate.dx, translate.dy, 0.0);
  }
}
