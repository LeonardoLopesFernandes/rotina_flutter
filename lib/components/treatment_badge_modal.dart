import 'package:flutter/material.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/types.dart';
import 'package:rotina_comercial/utils/time.dart';

class TreatmentBadgeModal extends StatelessWidget {
  final bool visible;
  final Item? item;
  final String userName;
  final VoidCallback onClose;

  const TreatmentBadgeModal({
    super.key,
    required this.visible,
    required this.item,
    required this.userName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || item == null) return const SizedBox.shrink();
    final it = item!;
    final treatedAt = it.formattedTreatedAt;
    final treatedBy = it.effectiveTreatedBy ?? userName;
    final answers = it.answers;

    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: const Color(0x66000000)),
        ),
        Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 340,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tratamento',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Open Sans')),
                  const SizedBox(height: 12),
                  _row('Tratado por:', treatedBy),
                  _row('Data/hora:', treatedAt ?? '—'),
                  const Text('Respostas:',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Open Sans')),
                  Flexible(
                    child: SingleChildScrollView(
                      child: answers != null
                          ? Column(
                              children: shortQuestions.asMap().entries.map((e) {
                                final answer = answers.firstWhere(
                                    (a) => a.number == e.key + 1,
                                    orElse: () => TreatedAnswer(
                                        question: '',
                                        number: e.key + 1,
                                        items: 0,
                                        percentage: 0));
                                final active = isTreatedAnswerActive(answer);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: active
                                              ? AppColors.success.withOpacity(0.15)
                                              : AppColors.danger.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            active ? '✓' : '×',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: active
                                                  ? AppColors.success
                                                  : AppColors.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${e.key + 1} - ${shortQuestions[e.key]}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF3D3D3D),
                                            fontFamily: 'Open Sans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          : const Text('Detalhes indisponíveis',
                              style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x47000000),
                            blurRadius: 3.6,
                            offset: Offset(0, 1.6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('Fechar',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Open Sans')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF333333), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
