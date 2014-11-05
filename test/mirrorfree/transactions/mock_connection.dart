library mirrorfree.transactions.mock_connection;


import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show CryptoUtils;

import 'package:google_cloud_datastore/src/connection.dart';
import 'package:google_cloud_datastore/src/proto/schema_v1_pb2.dart' as schema;

/**
 * Mock connection for testing the transaction scheduler.
 *
 */
class MockConnection implements DatastoreConnection {
  Map<String, Transaction> transactions = new Map<String,Transaction>();

  Transaction lookupTransaction(Uint8List transactionId) {
    return transactions[CryptoUtils.bytesToBase64(transactionId)];
  }

  math.Random _random = new math.Random();

  Transaction createTransaction() {
    Uint8List id = new Uint8List(16);
    for (var i=0;i<16;i++) {
      id[i] = _random.nextInt(8);
    }
    if (lookupTransaction(id) != null)
      return createTransaction();
    var transaction = new Transaction(id);
    transactions[CryptoUtils.bytesToBase64(id)] = transaction;
    return transaction;
  }

  @override
  Future<schema.AllocateIdsResponse> allocateIds(schema.AllocateIdsRequest request) {
    throw new UnsupportedError('MockConnection.allocateIds');
  }

  @override
  Future<schema.BeginTransactionResponse> beginTransaction(schema.BeginTransactionRequest request) {
    return new Future.sync(() {
     var transaction = createTransaction();
      return new schema.BeginTransactionResponse()
          ..transaction = transaction.id;
    });
  }

  /**
   * If [:failCommit:] is `true`, then we should retry the transaction
   * three times without failing
   */
  bool failCommit = false;
  int commitRetries = 0;

  @override
  Future<schema.CommitResponse> commit(schema.CommitRequest request) {
    return new Future.sync(() {
      if (failCommit && commitRetries++ < 3)
        throw new RPCException(403, 'commit', 'Deliberate failure');
      var transaction = lookupTransaction(request.transaction);
      if (transaction == null) {
        throw new RPCException(400, 'commit', 'No current transaction');
      }
      if (transaction.isCommitted)
        throw new RPCException(400, 'commit', 'Transaction already committed');
      if (transaction.isRolledBack)
        throw new RPCException(400, 'commit', 'Transaction already rolled back');
      transaction.isCommitted = true;
      return new schema.CommitResponse()
          ..mutationResult = new schema.MutationResult();
    });
  }

  bool failRollback = false;
  int rollbackRetries = 0;

  @override
  Future<schema.RollbackResponse> rollback(schema.RollbackRequest request) {
    return new Future.sync(() {
      if (failRollback && rollbackRetries++ < 3)
        throw new RPCException(403, 'rollback', 'Deliberate failure');
      var transaction = lookupTransaction(request.transaction);
      if (transaction == null)
        throw new RPCException(400, 'rollback', 'No current transaction');
      if (transaction.isRolledBack)
        throw new RPCException(400, 'rollback', 'Transaction already rolled back');
      transaction.isRolledBack = true;
      return new schema.RollbackResponse();
    });
  }


  int maxRequestRetries = 5;
  List<int> retryStatusCodes = [403];

  @override
  String get datasetId => null;

  @override
  String get host => null;

  var logger;
  Duration timeoutDuration;

  @override
  Future<schema.LookupResponse> lookup(schema.LookupRequest request) {
    throw new UnsupportedError('MockConnection.lookup');
  }

  @override
  Future<schema.RunQueryResponse> runQuery(schema.RunQueryRequest request) {
    throw new UnsupportedError('MockConnection.runQuery');
  }

  @override
  Future sendRemoteShutdown() {
    throw new UnsupportedError('MockConnection.sendRemoteShutdown');
  }

}

class Transaction {
  Uint8List id;

  String get strId => CryptoUtils.bytesToBase64(id);

  bool isCommitted = false;
  bool isRolledBack = false;

  Transaction(this.id);
}