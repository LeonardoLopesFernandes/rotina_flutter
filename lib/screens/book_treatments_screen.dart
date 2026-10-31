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
  late BookStatus _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
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
          if (page.book != null && page.book!.filenames.isNotEmpty) {
            _book = page.book!;
          }
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

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _limit).ceil();
  }

  int get _page => (_offset / _limit).floor() + 1;

  List<_GridPhoto> get _gridPhotos {
    final items = <_GridPhoto>[];
    // A foto exemplo do book abre sempre como a primeira do grid.
    if (_offset == 0) {
      for (final filename in _book.filenames) {
        items.add(_GridPhoto(
          url: bookExampleImageUrl(_book.bookId, filename),
          label: 'EXEMPLO',
          exemplo: true,
        ));
      }
    }
    for (final t in _treatments) {
      for (final filename in t.filenames) {
        items.add(_GridPhoto(
          url: bookTreatmentImageUrl(t.id, filename),
          label: t.store.isEmpty ? '—' : t.store,
          exemplo: false,
        ));
      }
    }
    return items;
  }

  void _verImagem(String url, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title),
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
    final photos = _gridPhotos;
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
                        child: photos.isEmpty
                            ? ListView(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text('Nenhuma foto encontrada',
                                          style: TextStyle(
                                              color: AppColors.textHint,
                                              fontFamily: 'Open Sans')),
                                    ),
                                  ),
                                ],
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 12),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridColumns(context),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: photos.length,
                                itemBuilder: (_, i) =>
                                    _fotoGrid(photos[i]),
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

  int _gridColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  Widget _fotoGrid(_GridPhoto foto) {
    return GestureDetector(
      onTap: () => _verImagem(
        foto.url,
        foto.exemplo ? 'Foto exemplo' : 'Foto da loja ${foto.label}',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              foto.url,
              headers: _headers,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFFF0F0F0),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFF0F0F0),
                child: const Icon(Icons.broken_image,
                    color: AppColors.textHint, size: 32),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: foto.exemplo
                      ? Colors.black.withOpacity(0.78)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  foto.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Open Sans',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPhoto {
  final String url;
  final String label;
  final bool exemplo;

  const _GridPhoto({
    required this.url,
    required this.label,
    required this.exemplo,
  });
}
