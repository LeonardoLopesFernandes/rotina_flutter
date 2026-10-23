import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Diálogo de anexar fotos do book (layout de referência).
class PhotoUploadDialog extends StatefulWidget {
  final int filesQuantity;
  final String bookName;

  const PhotoUploadDialog({
    super.key,
    required this.filesQuantity,
    this.bookName = '',
  });

  @override
  State<PhotoUploadDialog> createState() => _PhotoUploadDialogState();
}

class _PhotoUploadDialogState extends State<PhotoUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _fotos = [];

  int get _requerido => widget.filesQuantity > 0 ? widget.filesQuantity : 1;

  Future<void> _selecionar() async {
    final restante = _requerido - _fotos.length;
    if (restante <= 0) return;
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      limit: restante,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _fotos.addAll(picked.take(restante));
    });
  }

  @override
  Widget build(BuildContext context) {
    final completo = _fotos.length >= _requerido;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.black54, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _fotos.isEmpty
                        ? 'Selecione $_requerido ${_requerido == 1 ? 'foto' : 'fotos'} para envio'
                        : '${_fotos.length}/$_requerido fotos selecionada(s)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      fontFamily: 'Open Sans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_fotos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _fotos)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(f.path),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _fotos.remove(f)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!completo)
                    ElevatedButton.icon(
                      onPressed: _selecionar,
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.white, size: 18),
                      label: Text(
                        _fotos.isEmpty ? 'Selecionar fotos' : 'Adicionar fotos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Open Sans',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        completo ? () => Navigator.of(context).pop(_fotos) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF708A),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Submeter',
                      style: TextStyle(
                        color:
                            completo ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
