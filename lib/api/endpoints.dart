import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:rotina_comercial/api/client.dart';
import 'package:rotina_comercial/types.dart';
import 'package:rotina_comercial/theme.dart';

Map<String, dynamic> _requestBody({String? date}) => {
      'store': store,
      'selectedRegions': [],
      'selectedDistricts': [],
      if (date != null) 'date': date,
    };

Future<List<Department>> getItems(String dateApi) async {
  final res = await apiClient.get<List<dynamic>>('rotina/items',
      queryParameters: {'store': store, 'date': dateApi});
  final data = res.data ?? [];
  return data
      .map((e) => Department.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<TreatedItemResponse> saveTreatedItem(TreatedItemRequest request) async {
  try {
    final res = await apiClient.post<Map<String, dynamic>>(
      'rotina/treated-items',
      data: request.toJson(),
    );
    if (res.statusCode != null &&
        res.statusCode! >= 200 &&
        res.statusCode! < 300) {
      if (res.data == null) {
        return TreatedItemResponse(success: true, message: null);
      }
      return TreatedItemResponse.fromJson(res.data!);
    }
    throw Exception('Erro ${res.statusCode}');
  } on DioException catch (e) {
    final msg = e.message ?? '';
    if (msg.contains('End of input') ||
        msg.contains('BEGIN_OBJECT') ||
        msg.contains('END_DOCUMENT') ||
        msg.contains('Unexpected end of JSON input')) {
      return TreatedItemResponse(success: true, message: null);
    }
    rethrow;
  }
}

Future<CardsPercentageResponse> getCardsPercentage(String date) async {
  final res = await apiClient.post<Map<String, dynamic>>(
    'rotina/treated-items/cards-quantity-percentage',
    data: _requestBody(date: date),
  );
  return CardsPercentageResponse.fromJson(res.data!);
}

Future<List<RoutineStatusItem>> getRoutineStatusList() async {
  final res = await apiClient.post<List<dynamic>>(
    'rotina/treated-items/routine-status',
    data: _requestBody(),
  );
  return (res.data ?? [])
      .map((e) => RoutineStatusItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<ByAnswerItem>> getTreatedByAnswers(String date) async {
  final res = await apiClient.post<List<dynamic>>(
    'rotina/treated-items/by-answers',
    data: _requestBody(date: date),
  );
  return (res.data ?? [])
      .map((e) => ByAnswerItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<ByAnswerItem>> getUnsoldTreatedAnswers() async {
  final res = await apiClient.post<List<dynamic>>(
    'rotina/unsold-items/treated-answers',
    data: _requestBody(),
  );
  return (res.data ?? [])
      .map((e) => ByAnswerItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<UnsoldTreatedCardResponse> getUnsoldTreatedCard() async {
  final res = await apiClient.post<Map<String, dynamic>>(
    'rotina/unsold-items/treated-card',
    data: _requestBody(),
  );
  return UnsoldTreatedCardResponse.fromJson(res.data!);
}

Future<List<SpecialItem>> getUnsoldItems() async {
  final res =
      await apiClient.get<List<dynamic>>('rotina/unsold-items/$store');
  return (res.data ?? [])
      .map((e) => SpecialItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<SpecialItem>> getNoSalesHistoryItems() async {
  final res = await apiClient
      .get<List<dynamic>>('rotina/no-sales-history-items/$store');
  return (res.data ?? [])
      .map((e) => SpecialItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<SpecialAnswer>> getUnsoldItemAnswers(String department) async {
  final res = await apiClient
      .get<Map<String, dynamic>>('rotina/unsold-items/answers/$department');
  final list = res.data?['unsoldAnswers'] as List<dynamic>? ?? [];
  return list.map((e) => SpecialAnswer.fromJson(e as Map<String, dynamic>)).toList();
}

Future<List<SpecialAnswer>> getNoSalesHistoryItemAnswers(
    String department) async {
  final res = await apiClient.get<Map<String, dynamic>>(
      'rotina/no-sales-history-items/answers/$department');
  final list = res.data?['noSalesHistoryAnswers'] as List<dynamic>? ?? [];
  return list.map((e) => SpecialAnswer.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> saveUnsoldItemAnswer(SpecialAnswerRequest request) async {
  await apiClient.post('rotina/unsold-items/answer', data: request.toJson());
}

Future<void> saveNoSalesHistoryItemAnswer(SpecialAnswerRequest request) async {
  await apiClient
      .post('rotina/no-sales-history-items/answer', data: request.toJson());
}

Future<({bool saved, String message})> _downloadPdf(
  String path,
  String fileName, {
  Map<String, dynamic>? queryParameters,
}) async {
  try {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'x-requested-with': 'com.rotina.rotina_comercial',
      'Origin': 'https://rotina-comercial.americanas.io',
      'Referer': 'https://rotina-comercial.americanas.io/',
    };
    if (getAuthToken() != null && getAuthToken()!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${getAuthToken()}';
      headers['Cookie'] = 'rc-newToken=${getAuthToken()}';
    }
    final res = await apiClient.get(
      path,
      queryParameters: queryParameters,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: (_, __) {},
    );
    final bytes = Uint8List.fromList(res.data as List<int>);
    await const MethodChannel('rotina/storage').invokeMethod<String>(
      'savePdf',
      {'bytes': bytes, 'fileName': fileName},
    );
    return (saved: true, message: 'PDF salvo na pasta Downloads: $fileName');
  } on PlatformException catch (e) {
    return (saved: false, message: 'Erro ao salvar PDF: ${e.message}');
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status != null && status >= 400) {
      return (saved: false, message: 'Erro $status');
    }
    return (saved: false, message: 'Erro ao baixar PDF: ${e.message}');
  } catch (e) {
    return (saved: false, message: 'Erro ao baixar PDF: $e');
  }
}

Future<({bool saved, String message})> downloadDaySchedulePdf(
    String dateApi) async {
  final fileName = 'Rotina_${dateApi.replaceAll('/', '_')}.pdf';
  return _downloadPdf(
    'rotina/pdf/generate-day-schedule',
    fileName,
    queryParameters: {'store': store, 'date': dateApi},
  );
}

Future<({bool saved, String message})> downloadUnsoldItemsPdf() =>
    _downloadPdf(
        'rotina/pdf/generate-unsold-items/$store', 'Itens_sem_venda.pdf');

Future<({bool saved, String message})> downloadNoSalesHistoryItemsPdf() =>
    _downloadPdf('rotina/pdf/generate-no-sales-history-items/$store',
        'Itens_sem_historico_venda.pdf');

/// Books/campanhas pendentes da loja (card da Rotina do dia e tela Books).
Future<List<BookStatus>> getBooks({String? loja}) async {
  final filtro = (loja == null || loja.trim().isEmpty) ? store : loja.trim();
  final res = await apiClient.get<List<dynamic>>('rotina/books/$filtro');
  final data = res.data ?? [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(BookStatus.fromJson)
      .toList();
}

/// Todos os books (histórico completo), percorrendo as páginas (10/página no site).
/// Quando [loja] é informada, filtra os books daquela loja.
Future<List<BookStatus>> getAllBooks({String? loja}) async {
  final filtro = loja?.trim() ?? '';
  final all = <BookStatus>[];
  var offset = 0;
  for (var i = 0; i < 30; i++) {
    final res = await apiClient.get<Map<String, dynamic>>(
      'rotina/books/paginated',
      queryParameters: {
        'limit': 100,
        'offset': offset,
        if (filtro.isNotEmpty) 'store': filtro,
      },
    );
    final data = (res.data?['data'] as List?) ?? [];
    all.addAll(data
        .whereType<Map<String, dynamic>>()
        .map(BookStatus.fromJson)
        .toList());
    final total = (res.data?['totalCount'] as num?)?.toInt() ?? 0;
    offset += data.length;
    if (data.isEmpty || offset >= total) break;
  }
  return all;
}

Future<List<String>> getRegions() async {
  final res = await apiClient.get<List<dynamic>>(
    'rotina/stores/regions',
    queryParameters: {'includeAll': true},
  );
  return (res.data ?? []).map((e) => e.toString()).toList();
}

Future<List<StoreDistrict>> getDistricts() async {
  final res = await apiClient.get<List<dynamic>>(
    'rotina/stores/districts',
    queryParameters: {'includeAll': true},
  );
  return (res.data ?? [])
      .whereType<Map<String, dynamic>>()
      .map(StoreDistrict.fromJson)
      .toList();
}

Future<BookTreatmentsPage> getBookTreatments(
  String bookId, {
  int limit = 50,
  int offset = 0,
  String? store,
  String? region,
  String? district,
}) async {
  final res = await apiClient.get<Map<String, dynamic>>(
    'rotina/books/books-treatments-paginated/$bookId',
    queryParameters: {
      'limit': limit,
      'offset': offset,
      if (store != null && store.isNotEmpty) 'store': store,
      if (region != null && region.isNotEmpty) 'region': region,
      if (district != null && district.isNotEmpty) 'district': district,
    },
  );
  final data = res.data?['data'];
  final raw = (data is Map ? data['treatments'] : null) as List? ?? [];
  return BookTreatmentsPage(
    treatments: raw
        .whereType<Map<String, dynamic>>()
        .map(BookTreatment.fromJson)
        .toList(),
    totalCount: (res.data?['totalCount'] as num?)?.toInt() ?? 0,
  );
}

/// Envia as fotos de um book (exatamente `filesQuantity` imagens) para a loja.
Future<void> uploadBookPhotos(
  String bookId,
  List<XFile> files, {
  String? loja,
}) async {
  final form = FormData();
  for (final file in files) {
    final name = file.name.isNotEmpty ? file.name : 'foto.jpg';
    form.files.add(MapEntry(
      'files',
      await MultipartFile.fromFile(
        file.path,
        filename: name,
        contentType: _imageMediaType(name),
      ),
    ));
  }
  await apiClient.post<void>(
    'rotina/books/treatments/upload-photo/$bookId',
    queryParameters: {
      'store': (loja == null || loja.trim().isEmpty) ? store : loja.trim(),
    },
    data: form,
  );
}

DioMediaType _imageMediaType(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return DioMediaType('image', 'png');
  if (n.endsWith('.webp')) return DioMediaType('image', 'webp');
  if (n.endsWith('.heic')) return DioMediaType('image', 'heic');
  return DioMediaType('image', 'jpeg');
}

String uploadErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    dynamic item = data;
    if (data is List && data.isNotEmpty) item = data.first;
    if (item is Map) {
      final msg = item['errorDetails'] ?? item['error'] ?? item['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    }
    final status = error.response?.statusCode;
    if (status != null) return 'Erro $status ao enviar as fotos.';
  }
  return 'Não foi possível enviar as fotos.';
}

String bookTreatmentImageUrl(String treatmentId, String filename) =>
    '${baseUrl}rotina/books/store-treatment/$treatmentId/image?filename=${Uri.encodeQueryComponent(filename)}';
