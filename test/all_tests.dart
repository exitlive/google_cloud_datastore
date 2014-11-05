library all_tests;

import 'connection/connection_test.dart' as connection;
import 'mirrorfree/all_tests.dart' as mirrorfree;
import 'reflective/all_tests.dart' as reflective;

void main() {
  connection.main();
  mirrorfree.main();
  reflective.main();
}