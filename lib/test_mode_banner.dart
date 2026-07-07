import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Тонкий постоянный баннер "Тестовый режим" вверху главных экранов.
// Свёрнут по умолчанию — тап раскрывает/сворачивает подробный текст.
class TestModeBanner extends StatefulWidget {
  const TestModeBanner({super.key});

  @override
  State<TestModeBanner> createState() => _TestModeBannerState();
}

class _TestModeBannerState extends State<TestModeBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3CD),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_rounded, color: Color(0xFF8A6D3B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'test_mode.banner_label'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF8A6D3B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: const Color(0xFF8A6D3B),
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 6),
                Text(
                  'test_mode.body'.tr(),
                  style: const TextStyle(color: Color(0xFF8A6D3B), fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
