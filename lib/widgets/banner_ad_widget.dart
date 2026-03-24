import 'package:flutter/material.dart';

class SimpleBannerAdWidget extends StatelessWidget {
  const SimpleBannerAdWidget({
    super.key,
    this.adUnitId,
    this.placeholder,
  });

  final String? adUnitId;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    // Simple placeholder widget for banner ads
    return placeholder ?? 
      Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Ad Banner Placeholder',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      );
  }
}
