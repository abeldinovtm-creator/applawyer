import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Заглушка: раздел статистики для юристов, адвокатов и ЧСИ.
// Будет наполнен после перехода на модель оплаты через эскроу-счёт и комиссию.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('lawyer.statistics_menu'.tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'lawyer.statistics_coming_soon'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
