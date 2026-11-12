import 'package:flutter_test/flutter_test.dart';
import '../example/bin/universal_store_example.dart' as store_example;

void main() {
  test('executes universal store example end-to-end without errors', () {
    expect(() => store_example.main(), returnsNormally);
  });
}
