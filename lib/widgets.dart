import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'services/unread_counts_service.dart';

enum SnackKind { success, error, warning }

void showAppSnackBar(BuildContext context, String message, {SnackKind kind = SnackKind.success}) {
  Color color;
  IconData icon;
  if (kind == SnackKind.error) {
    color = const Color(0xFFC62828);
    icon = Icons.error_outline_rounded;
  } else if (kind == SnackKind.warning) {
    color = const Color(0xFFE65100);
    icon = Icons.warning_amber_rounded;
  } else {
    color = const Color(0xFF2E7D32);
    icon = Icons.check_circle_outline_rounded;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
}

// Кнопка переключения языка — StatelessWidget со своим контекстом
class LanguageButton extends StatelessWidget {
  final String langCode;
  final String label;
  final bool isDarkAppBar;

  const LanguageButton({
    super.key,
    required this.langCode,
    required this.label,
    required this.isDarkAppBar,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.locale.languageCode == langCode;

    final selectedBg   = isDarkAppBar ? Colors.white : const Color(0xFFA6192E);
    final selectedText = isDarkAppBar ? const Color(0xFFA6192E) : Colors.white;
    final unselectedText = isDarkAppBar ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? selectedBg : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => context.setLocale(Locale(langCode)),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}

// Маленькая точка — точечный индикатор "здесь есть непрочитанное" на
// конкретной карточке заявки/отклика (без числа, в отличие от CountBadge).
class UnreadDot extends StatelessWidget {
  final bool show;

  const UnreadDot({super.key, required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}

// Маленький числовой бейдж — для пунктов меню и иконок.
class CountBadge extends StatelessWidget {
  final int count;

  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Интерактивный выбор оценки 1-5 звёзд (форма отзыва).
class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const StarRatingInput({super.key, required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return IconButton(
          onPressed: () => onChanged(starValue),
          icon: Icon(
            starValue <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFA6192E),
            size: 32,
          ),
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}

// Отображение оценки 1-5 звёзд, только для чтения (профиль юриста, карточки отзывов).
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;

  const StarRatingDisplay({super.key, required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        IconData icon;
        if (rating >= starValue) {
          icon = Icons.star_rounded;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, color: const Color(0xFFA6192E), size: size);
      }),
    );
  }
}

// Карточка с числом и подписью — сводная статистика (завершённые/активные
// дела, заработок и т.п.). Используется в профиле и на экране статистики.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatCard({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

// Диалог отказа с выбором причины (dropdown) — общий для отказа клиента от
// юриста и отказа юриста от заявки. Возвращает {'reason_code', 'reason_text'}
// или null при отмене. reason_text обязателен, только если выбрана причина
// с кодом 'other'.
Future<Map<String, String>?> showDeclineReasonDialog(
  BuildContext context, {
  required String title,
  required List<MapEntry<String, String>> reasons,
}) {
  String? selectedCode;
  final otherController = TextEditingController();

  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final isOther = selectedCode == 'other';
        final canSubmit = selectedCode != null && (!isOther || otherController.text.trim().isNotEmpty);
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCode,
                decoration: InputDecoration(
                  labelText: 'decline.reason_label'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: reasons
                    .map((r) => DropdownMenuItem(value: r.key, child: Text(r.value)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedCode = v),
              ),
              if (isOther) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: otherController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'decline.other_reason_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: canSubmit
                  ? () => Navigator.pop(ctx, {
                        'reason_code': selectedCode!,
                        'reason_text': otherController.text.trim(),
                      })
                  : null,
              child: Text('decline.confirm'.tr(), style: const TextStyle(color: Color(0xFFA6192E))),
            ),
          ],
        );
      },
    ),
  );
}

// Иконка открытия endDrawer с бейджем суммарного количества непрочитанного
// (уведомления + сообщения в чатах). Подписывается на UnreadCountsService.
class MenuIconWithBadge extends StatelessWidget {
  final Color? color;

  const MenuIconWithBadge({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => IconButton(
        icon: ValueListenableBuilder<int>(
          valueListenable: UnreadCountsService.instance.notifications,
          builder: (_, notifCount, __) => ValueListenableBuilder<int>(
            valueListenable: UnreadCountsService.instance.messagesAsClient,
            builder: (_, clientMsgCount, __) => ValueListenableBuilder<int>(
              valueListenable: UnreadCountsService.instance.messagesAsLawyer,
              builder: (_, lawyerMsgCount, __) {
                final total = notifCount + clientMsgCount + lawyerMsgCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.menu, color: color),
                    if (total > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: CountBadge(count: total),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        onPressed: () => Scaffold.of(ctx).openEndDrawer(),
      ),
    );
  }
}


