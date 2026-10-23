import 'package:flutter/material.dart';
import 'package:rotina_comercial/api/client.dart';
import 'package:rotina_comercial/api/endpoints.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/types.dart';

/// Fotos das lojas de um book (tratamentos), com filtro por loja.
class BookTreatmentsScreen extends StatefulWidget {
  final BookStatus book;

  const BookTreatmentsScreen({super.key, required this.book});

  @override
  State<BookTreatmentsScreen> createState() => _BookTreatmentsScreenState();
}

class _BookTreatmentsScreenState extends State<BookTreatmentsScreen> {
  static const int _limit = 50;
  final _storeController = TextEditingController();
  List<String> _regions = [];
  List<StoreDistrict> _districts = [];
  String? _region;
  String? _district;
  bool _loading = true;
  String? _error;
  List<BookTreatment> _treatments = [];
  int _total = 0;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _carregarFiltros();
    _load(reset: true);
  }

  Future<void> _carregarFiltros() async {
    try {
      final results = await Future.wait([getRegions(), getDistricts()]);
      if (mounted) {
        setState(() {
          _regions = results[0] as List<String>;
          _districts = results[1] as List<StoreDistrict>;
        });
      }
    } catch (_) {}
  }

  List<StoreDistrict> get _distritosVisiveis {
    if (_region == null) return _districts;
    return _districts.where((d) => d.zone == _region).toList();
  }

  InputDecoration _filtroDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, fontFamily: 'Open Sans'),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  void _aplicar() {
    setState(() => _offset = 0);
    _load();
  }

  @override
  void dispose() {
    _storeController.dispose();
    super.dispose();
  }

  Map<String, String>? get _headers {
    final token = getAuthToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _offset = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await getBookTreatments(
        widget.book.bookId,
        limit: _limit,
        offset: _offset,
        store: _storeController.text.trim(),
        region: _region,
        district: _district,
      );
      if (mounted) {
        setState(() {
          _treatments = page.treatments;
          _total = page.totalCount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar as fotos.';
          _loading = false;
        });
      }
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'notexecuted':
        return 'Não enviado';
      case 'processing':
        return 'Em análise';
      case 'executed':
        return 'Enviado';
      case 'approved':
        return 'Aprovado';
      case 'notapproved':
      case 'not_approved':
        return 'Não aprovado';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'notexecuted':
        return Colors.amber[700]!;
      case 'processing':
        return const Color(0xFF1565C0);
      case 'executed':
        return const Color(0xFF2E7D32);
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'notapproved':
      case 'not_approved':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _limit).ceil();
  }

  int get _page => (_offset / _limit).floor() + 1;

  void _verImagem(String url, String store) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('Foto da loja $store'),
        ),
        body: InteractiveViewer(
          child: Center(
            child: Image.network(
              url,
              headers: _headers,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Não foi possível carregar a imagem',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fotos das lojas',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Open Sans')),
            Text(
              widget.book.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFamily: 'Open Sans'),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh, color: AppColors.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _region ?? '',
                          isExpanded: true,
                          decoration: _filtroDecoration('Região'),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('Todas as regiões')),
                            ..._regions.map((r) => DropdownMenuItem(
                                value: r, child: Text(r))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _region =
                                  (v == null || v.isEmpty) ? null : v;
                              _district = null;
                            });
                            _aplicar();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _district ?? '',
                          isExpanded: true,
                          decoration: _filtroDecoration('Distrito'),
                          items: [
                            const DropdownMenuItem(
                                value: '',
                                child: Text('Todos os distritos')),
                            ..._distritosVisiveis.map((d) => DropdownMenuItem(
                                  value: d.code,
                                  child: Text('${d.code} - ${d.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _district =
                                (v == null || v.isEmpty) ? null : v);
                            _aplicar();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _storeController,
                          onSubmitted: (_) => _aplicar(),
                          style: const TextStyle(
                              fontSize: 14, fontFamily: 'Open Sans'),
                          decoration:
                              _filtroDecoration('Loja (ex.: L998)').copyWith(
                            prefixIcon:
                                const Icon(Icons.storefront, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              onPressed: _aplicar,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _region = null;
                            _district = null;
                            _storeController.clear();
                          });
                          _aplicar();
                        },
                        child: const Text(
                          'LIMPAR',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'Open Sans',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style: const TextStyle(
                                      fontFamily: 'Open Sans')),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => _load(reset: true),
                                child: const Text('TENTAR NOVAMENTE'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => _load(),
                        child: _treatments.isEmpty
                            ? ListView(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text('Nenhuma loja encontrada',
                                          style: TextStyle(
                                              color: AppColors.textHint,
                                              fontFamily: 'Open Sans')),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _treatments.length,
                                itemBuilder: (_, i) =>
                                    _card(_treatments[i]),
                              ),
                      ),
          ),
          if (!_loading && _error == null && _total > _limit)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _offset > 0
                        ? () {
                            _offset = (_offset - _limit).clamp(0, _total);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    color:
                        _offset > 0 ? AppColors.primary : AppColors.textHint,
                  ),
                  Text(
                    '$_page / $_totalPages',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Open Sans'),
                  ),
                  IconButton(
                    onPressed: _offset + _limit < _total
                        ? () {
                            _offset += _limit;
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    color: _offset + _limit < _total
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(BookTreatment t) {
    final statusColor = _statusColor(t.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Loja ${t.store}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Open Sans'),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    _statusLabel(t.status),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontFamily: 'Open Sans'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!t.temFotos)
              const Text(
                'Sem fotos anexadas',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'Open Sans'),
              )
            else ...[
              Text(
                '${t.filenames.length} foto(s)',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Open Sans'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: t.filenames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url =
                        bookTreatmentImageUrl(t.id, t.filenames[i]);
                    return GestureDetector(
                      onTap: () => _verImagem(url, t.store),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          headers: _headers,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 96,
                              height: 96,
                              color: const Color(0xFFF0F0F0),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: const Color(0xFFF0F0F0),
                            child: const Icon(Icons.broken_image,
                                color: AppColors.textHint),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
