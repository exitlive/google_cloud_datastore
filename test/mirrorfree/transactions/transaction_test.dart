library mirrorfree.transactions.transaction_test;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';
import 'package:google_cloud_datastore/src/common.dart';

import '../../logging.dart';
import 'mock_connection.dart';

void main() {
  initLogging();

  group("transactions", () {
    MockConnection connection;
    TransactionScheduler transactionScheduler;

    setUp(() {
      connection = new MockConnection();
      transactionScheduler = new TransactionScheduler(connection)
          ..logger = new Logger('transaction_scheduler');
    });

    test("should be able to run a transaction from start to finish", () {
      return transactionScheduler.begin().then((transaction) {
        print('ID: ${transaction.id}');
        return transactionScheduler.commit(transaction);
      }).then((transaction) {
        expect(transaction.isCommitted, isTrue);
        expect(transaction.isRolledBack, isFalse);
        return transactionScheduler.rollback(transaction);
      }).then((transaction) {
        expect(transaction.isCommitted, isTrue);
        expect(transaction.isRolledBack, isTrue);
      });

    });

    test("should be able to recover from a failed commit", () {
      connection.failCommit = true;
      return transactionScheduler.begin().then((transaction) {
        print('ID: ${transaction.id}');
        return transactionScheduler.commit(transaction);
      }).then((transaction) {
        expect(transaction.isCommitted, isTrue);
        expect(transaction.isRolledBack, isFalse);
        return transactionScheduler.rollback(transaction);
      }).then((transaction) {
        expect(transaction.isCommitted, isTrue);
        expect(transaction.isRolledBack, isTrue);
      });
    });

    test("should be able to recover from a failed rollback", () {
      connection.failRollback = true;
      return transactionScheduler.begin().then((transaction) {
        print('ID: ${transaction.id}');
        return transactionScheduler.commit(transaction);
      }).then((transaction) {
        expect(transaction.isCommitted, isTrue);
        expect(transaction.isRolledBack, isFalse);
        return transactionScheduler.rollback(transaction);
      }).then((transaction) {
        expect(transaction.isCommitted, isTrue);
        expect(transaction.isRolledBack, isTrue);
      });
    });


    group('context', () {
      test('should be able to run a transactional context', () {
        transactionScheduler.withTransaction((transaction) => null).then((transaction) {
          expect(transaction.isCommitted, isTrue);
        });
      });
      test('should be able to throw a synchronous error in a transactional context', () {
        var transactionId;
        return transactionScheduler.withTransaction((transaction) {
          transactionId = transaction.id;
          throw 'hello world';
        }).then((transaction) {
          expect(transaction, isNot(anything), reason: 'With transaction should throw');
        }).catchError((err) {
          expect(err, 'hello world');
          var trans = connection.transactions[transactionId];
          expect(trans.isRolledBack, isTrue);
        });
      });

      test('should be able to return a future in a transactional context', () {
        transactionScheduler.withTransaction((transaction) => new Future.value()).then((transaction) {
          expect(transaction.isCommitted, isTrue);
        });
      });
      test('should be able to throw an asynchronous error in a transactional context', () {
        var transactionId;
        return transactionScheduler.withTransaction((transaction) {
          transactionId = transaction.id;
          return new Future.error('hello world');
        }).then((transaction) {
          expect(transaction, isNot(anything), reason: 'With transaction should throw');
        }).catchError((err) {
          expect(err, 'hello world');
          var trans = connection.transactions[transactionId];
          expect(trans.isRolledBack, isTrue);
        });
      });
    });
  });


}