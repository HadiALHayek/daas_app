import '../../core/constants/strings_ar.dart';

String expenseCategoryLabel(String category) {
  switch (category) {
    case 'materials':
      return StringsAr.materials;
    case 'transport':
      return StringsAr.transport;
    case 'labor':
      return StringsAr.labor;
    default:
      return StringsAr.other;
  }
}

const expenseCategories = ['materials', 'transport', 'labor', 'other'];
