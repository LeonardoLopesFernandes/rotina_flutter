import 'package:flutter/material.dart';
import 'package:rotina_comercial/api/endpoints.dart';
import 'package:rotina_comercial/components/special_answers_modal.dart';
import 'package:rotina_comercial/components/special_product_card.dart';
import 'package:rotina_comercial/storage/session.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/types.dart';
import 'package:rotina_comercial/utils/time.dart';
import 'package:rotina_comercial/utils/toast.dart';

class SpecialItemsScreen extends StatefulWidget {
  const SpecialItemsScreen({super.key});

  @override
  State<SpecialItemsScreen> createState() => _SpecialItemsScreenState();
}

class _SpecialItemsScreenState extends State<SpecialItemsScreen> {
  List<DepartmentGroup> _groups = [];
  bool _refreshing = false;
  late bool _blocked;
  bool _showMenu = false;
  final Map<String, List<SpecialAnswer>> _answersCache = {};
  SpecialItem? _answerItem;
  List<SpecialAnswer> _answerList = [];
  SpecialItem? _badgeItem;
  String _badgeUserName = '';

  String _itemType = 'unsold';

  @override
  void initState() {
    super.initState();
    _blocked = isBlocked();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && _itemType != args['itemType']) {
      _itemType = args['itemType'] as String;
      _groups = [];
      _loadItems();
    } else if (_groups.isEmpty) {
      _loadItems();
    }
    Session.getUserName().then((name) => setState(() => _badgeUserName = name));
  }

  Future<void> _loadItems() async {
    setState(() => _refreshing = true);
    try {
      final items = _itemType == 'unsold'
          ? await getUnsoldItems()
          : await getNoSalesHistoryItems();
      final map = <String, DepartmentGroup>{};
      for (final item in items) {
        final key = '${item.department.code}::${item.department.name}';
        map.putIfAbsent(
            key,
            () => DepartmentGroup(
                department: item.department, items: [])).items.add(item);
      }
      setState(() {
        _groups = map.values.toList();
        _groups.sort((a, b) => a.department.code.compareTo(b.department.code));
      });
    } catch (e) {
      showToast('Erro ao carregar itens: $e', isError: true);
    } finally {
      setState(() => _refreshing = false);
    }
  }

  Future<void> _showAnswersDialog(SpecialItem item) async {
    final deptCode = item.department.code;
    if (!_answersCache.containsKey(deptCode)) {
      try {
        final answers = _itemType == 'unsold'
            ? await getUnsoldItemAnswers(deptCode)
            : await getNoSalesHistoryItemAnswers(deptCode);
        _answersCache[deptCode] = answers;
      } catch (_) {
        _answersCache[deptCode] = [];
      }
    }
    setState(() {
      _answerList = _answersCache[deptCode] ?? [];
      _answerItem = item;
    });
  }

  Future<void> _saveAnswer(SpecialItem item, String question, bool answer) async {
    try {
      final request = SpecialAnswerRequest(
        store: store,
        ean: item.ean,
        question: question,
        answer: answer,
      );
      if (_itemType == 'unsold') {
        await saveUnsoldItemAnswer(request);
      } else {
        await saveNoSalesHistoryItemAnswer(request);
      }
      // Atualiza o item local com quem tratou e quando, pois a API não retorna
      // o treatedBy/treatedDate na lista. O badge "Tratado por" precisa disso.
      final now = DateTime.now();
      final treatedBy = await Session.getUserName() ?? _badgeUserName;
      setState(() {
        for (final group in _groups) {
          final idx = group.items.indexWhere((i) => i.id == item.id);
          if (idx >= 0) {
            group.items[idx] = item.copyWith(
              treatedBy: treatedBy,
              treatedDate: now.toIso8601String(),
            );
          }
        }
      });
      showToast('Resposta registrada!');
      await _loadItems();
    } catch (e) {
      showToast('Erro ao salvar: $e', isError: true);
    }
  }

  void _handleMenuOption(String target) {
    setState(() => _showMenu = false);
    if (target == _itemType) return;
    Navigator.of(context).pushReplacementNamed('SpecialItems',
        arguments: {'itemType': target});
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _itemType == 'unsold' ? 'Itens sem venda' : 'Itens sem histórico de venda';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _toolbar(title),
              if (_blocked)
                Container(
                  color: const Color(0xFFFEE2E2),
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  child: Text('Tratamento bloqueado',  // ignore: use_full_hex_values_for_flutter_colors
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Open Sans')),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      final total = group.items.length;
                      final treatedCount =
                          group.items.where((i) => i.isTreated).length;
                      final allTreated = total > 0 && treatedCount == total;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${group.department.code} - ${group.department.name}',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Open Sans'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (allTreated)
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.5),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.check, color: Colors.white, size: 14),
                                          ),
                                        )
                                      else if (_blocked)
                                        Image.asset('assets/ic_block.png', width: 22, height: 22),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(
                                      minWidth: 22, minHeight: 22),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Center(
                                    child: Text('$total',
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Open Sans')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...group.items.map((special) => SpecialProductCard(
                                key: ValueKey('${special.id}-${special.ean}'),
                                item: special,
                                blocked: _blocked,
                                onUntreatedClick: _showAnswersDialog,
                                onTreatedClick: (i) =>
                                    setState(() => _badgeItem = i),
                              )),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          SpecialAnswersModal(
            visible: _answerItem != null,
            item: _answerItem,
            answers: _answerList,
            onClose: () => setState(() => _answerItem = null),
            onSave: _saveAnswer,
          ),
          if (_badgeItem != null)
            Stack(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _badgeItem = null),
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
                        borderRadius: BorderRadius.circular(12),
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
                          _badgeRow('Tratado por:',
                              _badgeItem!.effectiveTreatedBy ?? _badgeUserName),
                          _badgeRow('Data/hora:',
                              _badgeItem!.formattedTreatedAt ?? '—'),
                          const Text('Respostas:',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textMuted, fontFamily: 'Open Sans')),
                          Flexible(
                            child: SingleChildScrollView(
                              child: _badgeItem!.question != null
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Text('✓',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(_badgeItem!.question!,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF3D3D3D),
                                                  fontFamily: 'Open Sans')),
                                        ),
                                      ],
                                    )
                                  : const Text('Detalhes indisponíveis',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textHint,
                                          fontFamily: 'Open Sans')),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => setState(() => _badgeItem = null),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text('Fechar',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        fontFamily: 'Open Sans')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_showMenu) _menuOverlay(context),
        ],
      ),
    );
  }

  Widget _toolbar(String title) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 12, right: 12),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'Open Sans'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: () async {
                showToast('Gerando PDF...');
                final result = _itemType == 'unsold'
                    ? await downloadUnsoldItemsPdf()
                    : await downloadNoSalesHistoryItemsPdf();
                showToast(result.message, isError: true);
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(Icons.print, color: AppColors.primary, size: 26),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _showMenu = true),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(Icons.menu, color: AppColors.primary, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuOverlay(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showMenu = false),
      child: Container(
        color: const Color(0x33000000),
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 60, right: 12),
            width: 290,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      fontFamily: 'Open Sans',
                    ),
                  ),
                ),
                _menuItem(Icons.today, 'Rotina do dia', () {
                  setState(() => _showMenu = false);
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      'Main', (route) => false);
                }),
                _menuItem(Icons.remove_shopping_cart, 'Itens sem venda', () => _handleMenuOption('unsold')),
                _menuItem(Icons.history, 'Itens sem histórico de venda',
                    () => _handleMenuOption('no_sales_history')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Open Sans')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Open Sans')),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF3D3D3D), fontWeight: FontWeight.w600, fontFamily: 'Open Sans')),
          ),
        ],
      ),
    );
  }
}
