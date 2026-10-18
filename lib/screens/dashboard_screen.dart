import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:rotina_comercial/api/endpoints.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/types.dart';
import 'package:rotina_comercial/utils/time.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  CardsPercentageResponse? _cards;
  String _unsoldValue = '';
  List<RoutineStatusItem> _routineStatus = [];
  List<ByAnswerItem> _treatedByAnswers = [];
  List<ByAnswerItem> _unsoldAnswers = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final today = formatStorageDate(DateTime.now());
    try {
      final results = await Future.wait([
        getCardsPercentage(today),
        getUnsoldTreatedCard(),
        getRoutineStatusList(),
        getTreatedByAnswers(today),
        getUnsoldTreatedAnswers(),
      ]);
      setState(() {
        _cards = results[0] as CardsPercentageResponse;
        final unsold = results[1] as UnsoldTreatedCardResponse;
        _unsoldValue =
            '${unsold.unsoldTreatedItemsQuantity} (${unsold.unsoldTreatedItemsPercentage}%)';
        _routineStatus = results[2] as List<RoutineStatusItem>;
        _treatedByAnswers = results[3] as List<ByAnswerItem>;
        _unsoldAnswers = results[4] as List<ByAnswerItem>;
      });
    } catch (e) {
      // dashboard silencioso
    } finally {
      setState(() => _loading = false);
    }
  }

  String _routineValue(RoutineStatusItem item) =>
      '${item.days} dias (${item.percentage}%)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _toolbar(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _card(Icons.check_circle, 'Itens tratados',
                          _cards != null ? '${_cards!.treatedItemsQuantity} (${_cards!.treatedItemsPercentage}%)' : '—',
                          iconWidget: Lottie.asset(
                            'assets/lottie/check.json',
                            width: 36,
                            height: 36,
                            repeat: false,
                          )),
                      _card(Icons.business, 'Departamentos tratados',
                          _cards != null ? '${_cards!.treatedDepartmentsQuantity} (${_cards!.treatedDepartmentsPercentage}%)' : '—'),
                      _card(Icons.remove_shopping_cart, 'Itens sem venda tratados', _unsoldValue.isNotEmpty ? _unsoldValue : '—'),
                      _sectionTitle(Icons.calendar_today, 'Rotina da semana'),
                      const SizedBox(height: 8),
                      _cardColumn(
                        _routineStatus.isEmpty
                            ? [const Text('Sem dados',
                                style: TextStyle(fontSize: 14, color: AppColors.textHint, fontFamily: 'Open Sans'))]
                            : _routineStatus
                                .map((item) => _answerRow(
                                    item.status, _routineValue(item)))
                                .toList(),
                      ),
                      _sectionTitle(Icons.pie_chart, 'Tratamentos por resposta'),
                      const SizedBox(height: 8),
                      _cardColumn([
                        const Text('Hoje',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Open Sans')),
                        _answerList(_treatedByAnswers),
                      ]),
                      const SizedBox(height: 10),
                      _cardColumn([
                        const Text('Itens sem venda',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Open Sans')),
                        _answerList(_unsoldAnswers),
                      ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 12, right: 12),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(Icons.arrow_back, color: AppColors.primary, size: 28),
                ),
              ),
            ),
            const Expanded(
              child: Text('Painel de indicadores',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Open Sans')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Open Sans')),
        ],
      ),
    );
  }

  Widget _card(IconData icon, String title, String value,
      {Widget? iconWidget}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7C7C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconWidget ?? Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Open Sans', fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Open Sans')),
        ],
      ),
    );
  }

  Widget _cardColumn(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7C7C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _answerRow(String question, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(question,
                style: const TextStyle(fontSize: 14, color: Color(0xFF3D3D3D), fontFamily: 'Open Sans')),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600, fontFamily: 'Open Sans')),
        ],
      ),
    );
  }

  Widget _answerList(List<ByAnswerItem> items) {
    if (items.isEmpty) {
      return const Text('Sem respostas',
          style: TextStyle(fontSize: 14, color: AppColors.textHint, fontFamily: 'Open Sans'));
    }
    return Column(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        return Column(
          children: [
            _answerRow(item.question, '${item.items} (${item.percentage}%)'),
            if (e.key < items.length - 1)
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
          ],
        );
      }).toList(),
    );
  }
}
