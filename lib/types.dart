class DepartmentInfo {
  final String code;
  final String name;

  const DepartmentInfo({required this.code, required this.name});

  factory DepartmentInfo.fromJson(Map<String, dynamic> json) => DepartmentInfo(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

class TreatedAnswer {
  final String question;
  final String? shortQuestion;
  final bool? answer;
  final int number;
  final int items;
  final double percentage;
  final bool? active;

  TreatedAnswer({
    required this.question,
    this.shortQuestion,
    this.answer,
    required this.number,
    required this.items,
    required this.percentage,
    this.active,
  });

  factory TreatedAnswer.fromJson(Map<String, dynamic> json) => TreatedAnswer(
        question: json['question'] as String,
        shortQuestion: (json['shortQuestion'] ?? json['short_question']) as String?,
        answer: json['answer'] as bool?,
        number: json['number'] as int? ?? 0,
        items: (json['items'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
        active: json['active'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'shortQuestion': shortQuestion,
        'answer': answer,
        'number': number,
        'items': items,
        'percentage': percentage,
        'active': active,
      };
}

class Item {
  final String id;
  final String ean;
  final String sap;
  final String description;
  final int quantityStock;
  final int saleQuantityDay;
  final int saleQuantityMonth;
  final String grade;
  final bool treated;
  final List<TreatedAnswer>? answers;
  final String? treatedAt;
  final String? treatedBy;
  final String? departmentCode;

  Item({
    required this.id,
    required this.ean,
    required this.sap,
    required this.description,
    required this.quantityStock,
    required this.saleQuantityDay,
    required this.saleQuantityMonth,
    required this.grade,
    required this.treated,
    this.answers,
    this.treatedAt,
    this.treatedBy,
    this.departmentCode,
  });

factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String? ?? '',
        ean: json['ean'] as String? ?? '',
        sap: json['sap'] as String? ?? '',
        description: json['description'] as String? ?? '',
        quantityStock: (json['quantityStock'] as num?)?.toInt() ?? 0,
        saleQuantityDay: (json['quantityStock'] as num?)?.toInt() ?? 0,
        saleQuantityMonth: (json['saleQuantityMonth'] as num?)?.toInt() ?? 0,
        grade: json['grade'] as String? ?? '',
        treated: json['treated'] as bool? ?? false,
        answers: (json['answers'] as List<dynamic>?)
            ?.map((e) => TreatedAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
        treatedAt: (json['treatedAt'] ?? json['treated_at']) as String?,
        treatedBy: (json['treatedBy'] ?? json['treated_by']) as String?,
        departmentCode: json['departmentCode'] as String?,
      );

  Item copyWith({
    String? id,
    String? ean,
    String? sap,
    String? description,
    int? quantityStock,
    int? saleQuantityDay,
    int? saleQuantityMonth,
    String? grade,
    bool? treated,
    List<TreatedAnswer>? answers,
    String? treatedAt,
    String? treatedBy,
    String? departmentCode,
  }) =>
      Item(
        id: id ?? this.id,
        ean: ean ?? this.ean,
        sap: sap ?? this.sap,
        description: description ?? this.description,
        quantityStock: quantityStock ?? this.quantityStock,
        saleQuantityDay: saleQuantityDay ?? this.saleQuantityDay,
        saleQuantityMonth: saleQuantityMonth ?? this.saleQuantityMonth,
        grade: grade ?? this.grade,
        treated: treated ?? this.treated,
        answers: answers ?? this.answers,
        treatedAt: treatedAt ?? this.treatedAt,
        treatedBy: treatedBy ?? this.treatedBy,
        departmentCode: departmentCode ?? this.departmentCode,
      );
}

class Department {
  final DepartmentInfo department;
  final List<Item> items;

  Department({required this.department, required this.items});

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        department: DepartmentInfo.fromJson(json['department'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>)
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SpecialAnswer {
  final String question;
  final String shortQuestion;
  final bool answer;
  final int number;
  final bool active;

  SpecialAnswer({
    required this.question,
    required this.shortQuestion,
    required this.answer,
    required this.number,
    required this.active,
  });

  factory SpecialAnswer.fromJson(Map<String, dynamic> json) => SpecialAnswer(
        question: json['question'] as String? ?? '',
        shortQuestion: json['shortQuestion'] as String? ?? '',
        answer: json['answer'] as bool? ?? false,
        number: json['number'] as int? ?? 0,
        active: json['active'] as bool? ?? false,
      );
}

class SpecialItem {
  final String id;
  final String store;
  final DepartmentInfo department;
  final String ean;
  final String sap;
  final String description;
  final int stockQuantity;
  final double stockValue;
  final String grade;
  final String? daysWithoutSelling;
  final String? treatedBy;
  final String? treatedDate;
  final String? question;

  SpecialItem({
    required this.id,
    required this.store,
    required this.department,
    required this.ean,
    required this.sap,
    required this.description,
    required this.stockQuantity,
    required this.stockValue,
    required this.grade,
    this.daysWithoutSelling,
    this.treatedBy,
    this.treatedDate,
    this.question,
  });

  factory SpecialItem.fromJson(Map<String, dynamic> json) => SpecialItem(
        id: json['id'] as String? ?? '',
        store: json['store'] as String? ?? '',
        department: DepartmentInfo.fromJson(json['department'] as Map<String, dynamic>),
        ean: json['ean'] as String? ?? '',
        sap: json['sap'] as String? ?? '',
        description: json['description'] as String? ?? '',
        stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
        stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0,
        grade: json['grade'] as String? ?? '',
        daysWithoutSelling: json['daysWithoutSelling'] as String?,
        treatedBy: (json['treatedBy'] ?? json['treated_by']) as String?,
        treatedDate: (json['treatedDate'] ?? json['treated_date']) as String?,
        question: json['question'] as String?,
      );

  bool get isTreated => treatedBy != null && treatedBy!.isNotEmpty;

  SpecialItem copyWith({
    String? id,
    String? store,
    DepartmentInfo? department,
    String? ean,
    String? sap,
    String? description,
    int? stockQuantity,
    double? stockValue,
    String? grade,
    String? daysWithoutSelling,
    String? treatedBy,
    String? treatedDate,
    String? question,
  }) => SpecialItem(
    id: id ?? this.id,
    store: store ?? this.store,
    department: department ?? this.department,
    ean: ean ?? this.ean,
    sap: sap ?? this.sap,
    description: description ?? this.description,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    stockValue: stockValue ?? this.stockValue,
    grade: grade ?? this.grade,
    daysWithoutSelling: daysWithoutSelling ?? this.daysWithoutSelling,
    treatedBy: treatedBy ?? this.treatedBy,
    treatedDate: treatedDate ?? this.treatedDate,
    question: question ?? this.question,
  );
}

class ByAnswerItem {
  final String question;
  final int number;
  final int items;
  final double percentage;

  ByAnswerItem({
    required this.question,
    required this.number,
    required this.items,
    required this.percentage,
  });

  factory ByAnswerItem.fromJson(Map<String, dynamic> json) => ByAnswerItem(
        question: json['question'] as String,
        number: json['number'] as int? ?? 0,
        items: (json['items'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      );
}

class CardsPercentageResponse {
  final int treatedItemsQuantity;
  final double treatedItemsPercentage;
  final int treatedDepartmentsQuantity;
  final double treatedDepartmentsPercentage;

  CardsPercentageResponse({
    required this.treatedItemsQuantity,
    required this.treatedItemsPercentage,
    required this.treatedDepartmentsQuantity,
    required this.treatedDepartmentsPercentage,
  });

  factory CardsPercentageResponse.fromJson(Map<String, dynamic> json) =>
      CardsPercentageResponse(
        treatedItemsQuantity: (json['treatedItemsQuantity'] as num?)?.toInt() ?? 0,
        treatedItemsPercentage: (json['treatedItemsPercentage'] as num?)?.toDouble() ?? 0,
        treatedDepartmentsQuantity: (json['treatedDepartmentsQuantity'] as num?)?.toInt() ?? 0,
        treatedDepartmentsPercentage:
            (json['treatedDepartmentsPercentage'] as num?)?.toDouble() ?? 0,
      );
}

class RoutineStatusItem {
  final String status;
  final int days;
  final double percentage;

  RoutineStatusItem({
    required this.status,
    required this.days,
    required this.percentage,
  });

  factory RoutineStatusItem.fromJson(Map<String, dynamic> json) => RoutineStatusItem(
        status: json['status'] as String? ?? '',
        days: (json['days'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      );
}

class UnsoldTreatedCardResponse {
  final int unsoldTreatedItemsQuantity;
  final double unsoldTreatedItemsPercentage;

  UnsoldTreatedCardResponse({
    required this.unsoldTreatedItemsQuantity,
    required this.unsoldTreatedItemsPercentage,
  });

  factory UnsoldTreatedCardResponse.fromJson(Map<String, dynamic> json) =>
      UnsoldTreatedCardResponse(
        unsoldTreatedItemsQuantity:
            (json['unsoldTreatedItemsQuantity'] as num?)?.toInt() ?? 0,
        unsoldTreatedItemsPercentage:
            (json['unsoldTreatedItemsPercentage'] as num?)?.toDouble() ?? 0,
      );
}

class TreatedItemRequest {
  final String store;
  final String date;
  final String ean;
  final List<Map<String, dynamic>> answers;

  TreatedItemRequest({
    required this.store,
    required this.date,
    required this.ean,
    required this.answers,
  });

  Map<String, dynamic> toJson() => {
        'store': store,
        'date': date,
        'ean': ean,
        'answers': answers,
      };
}

class TreatedItemResponse {
  final bool success;
  final String? message;

  TreatedItemResponse({required this.success, this.message});

  factory TreatedItemResponse.fromJson(Map<String, dynamic> json) => TreatedItemResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
      );
}

class SpecialAnswerRequest {
  final String store;
  final String ean;
  final String question;
  final bool answer;

  SpecialAnswerRequest({
    required this.store,
    required this.ean,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
        'store': store,
        'ean': ean,
        'question': question,
        'answer': answer,
      };
}

class TreatmentRequest {
  final String store;
  final String? date;
  final List<String> selectedRegions;
  final List<String> selectedDistricts;

  TreatmentRequest({
    required this.store,
    this.date,
    required this.selectedRegions,
    required this.selectedDistricts,
  });

  Map<String, dynamic> toJson() => {
        'store': store,
        'date': date,
        'selectedRegions': selectedRegions,
        'selectedDistricts': selectedDistricts,
      };
}

class StoredTreatment {
  final bool treated;
  final String? treatedAt;
  final String? treatedBy;
  final List<TreatedAnswer>? answers;

  StoredTreatment({
    required this.treated,
    this.treatedAt,
    this.treatedBy,
    this.answers,
  });

  factory StoredTreatment.fromJson(Map<String, dynamic> json) => StoredTreatment(
        treated: json['treated'] as bool,
        treatedAt: json['treatedAt'] as String?,
        treatedBy: json['treatedBy'] as String?,
        answers: (json['answers'] as List<dynamic>?)
            ?.map((e) => TreatedAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'treated': treated,
        'treatedAt': treatedAt,
        'treatedBy': treatedBy,
        'answers': answers?.map((e) => e.toJson()).toList(),
      };
}

class DepartmentGroup {
  final DepartmentInfo department;
  final List<SpecialItem> items;

  DepartmentGroup({required this.department, required this.items});
}

const List<String> questions = [
  'Item próximo ao vencimento?',
  'Item mal precificado?',
  'Item sem reposição/grade do CD?',
  'Item com divergência de saldo?',
  'Item mal exposto/abastecido no salão de vendas?',
  'Preço acima da concorrência?',
];

const List<String> shortQuestions = [
  'Próximo ao vencimento',
  'Mal precificado',
  'Sem reposição/grade do CD',
  'Divergência de saldo',
  'Mal exposto/abastecido no salão de vendas',
  'Preço acima da concorrência',
];

// Departamentos que desabilitam a opção 1 ("Próximo ao vencimento")
const List<String> deptsDisableExpiry = [
  'D008',
  'D025',
  'D027',
  'D030',
  'D063',
  'D067'
];
