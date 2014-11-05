library mirrorfree_tests.datastore;

import 'package:unittest/unittest.dart';

import '../../lib/src/connection.dart';
import '../../lib/src/common.dart';

import '../connection_details.dart';

void main() {
  //Test sepeartely since we don't want to clear the kind cache
  group("datastore creation", () {
    //Do once, rather than on every time the datastore is set up
    Datastore.clearKindCache();
    DatastoreConnection connection;

    setUp(() {
      connection = DatastoreConnection.openSync(DATASET_ID, host: HOST);

    });

    //TODO: Test that datastore caches kinds.
  });
}