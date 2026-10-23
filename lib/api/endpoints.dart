import 'package:dio/dio.dart';
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
Future<List<BookStatus>> getBooks() async {
  final res =
      await apiClient.get<List<dynamic>>('rotina/books/$store');
  final data = res.data ?? [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(BookStatus.fromJson)
      .toList();
}
