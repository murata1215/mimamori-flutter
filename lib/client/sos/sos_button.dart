import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sos_countdown_screen.dart';

/// SOS 大ボタン。誤操作防止のため長押し3秒で発動。
/// 押下中はプログレスリング＋バイブレーション。
class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _trigger();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    if (_controller.status == AnimationStatus.forward) {
      _controller.reset();
    }
  }

  void _trigger() {
    HapticFeedback.heavyImpact();
    _controller.reset();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SosCountdownScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD32F2F),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x55D32F2F),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('たすけて',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('3秒間 長押し',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
