import 'package:fractional_indexing/fractional_indexing.dart' as fi;

class FractionalIndexer {
  const FractionalIndexer._();

  static String between(String? before, String? after) {
    return fi.FractionalIndexer.generateKeyBetween(before, after) ?? fi.FractionalIndexer.integerZero;
  }
}
