library connection.connection_test;

import 'dart:async';
import 'dart:convert' show JSON;
import 'package:unittest/unittest.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:google_cloud_datastore/src/proto/schema_v1_pb2.dart';
import 'package:google_cloud_datastore/src/connection.dart';

import '../logging.dart';

void main() {
  initLogging();
  group('connection', () {
    group('retry', () {

      int numRetries;
      DatastoreConnection connection;

      setUp(() {
        numRetries = -1;
        Future<http.Response> sendRequest(http.Request request) {
          return new Future.sync(() {
            try {
              var beginTransactionRequest = new BeginTransactionRequest.fromBuffer(request.bodyBytes);
              if (numRetries++ >= 2) {
                var beginTransactionResponse = new BeginTransactionResponse()
                    ..transaction.addAll([1,2,3]);
                return new http.Response.bytes(
                    beginTransactionResponse.writeToBuffer(),
                    200
                );
              }
            } catch (err) {
              print(err);
              numRetries++;
            }
            return new http.Response(
                JSON.encode({"error": {"message": "invalid request"}}),
                400
            );
          });

        }

        var client = new MockClient(sendRequest);

        connection = new DatastoreConnection('test-project', client, 'http://example.com')
            ..retryStatusCodes = [400];
      });

      test("should retry the connection on failure", () {
        var beginTransactionRequest = new BeginTransactionRequest();
        connection.beginTransaction(beginTransactionRequest).then(expectAsync((response) {
          expect(response.transaction, [1,2,3]);
          expect(numRetries, 3);
        }));
      });

      test("should not retry the request if the status code is not one of the retry status codes", () {
        connection.retryStatusCodes = [401];
        var beginTransactionRequest = new BeginTransactionRequest();
        return connection.beginTransaction(beginTransactionRequest).then((response) {
          expect(response, isNot(anything), reason: 'request should fail');
        }).catchError((err) {
          expect(err, new isInstanceOf<RPCException>());
          expect(numRetries, 0);
        });
      });

      test("should retry the request a maximum of maxRetryRequest times", () {
        connection.maxRequestRetries = 1;
        var beginTransactionRequest = new BeginTransactionRequest();
        return connection.beginTransaction(beginTransactionRequest).then((response) {
          expect(response, isNot(anything), reason: 'request should fail');
        }).catchError((err) {
          expect(err, new isInstanceOf<RPCException>());
          expect(numRetries, 1);
        });
      });

      test("should not retry a commit request on failure", () {
        var commitRequest = new CommitRequest();
        return connection.commit(commitRequest).then((response) {
          expect(response, isNot(anything), reason: 'request should fail');
        }).catchError((err) {
          expect(err, new isInstanceOf<RPCException>());
          expect(numRetries, 0);
        });

      });

      test("should not retry a rollback request on failure", () {
        var rollbackRequest = new RollbackRequest();
        return connection.rollback(rollbackRequest).then((response) {
          expect(response, isNot(anything), reason: 'request should fail');
        }).catchError((err) {
          expect(err, new isInstanceOf<RPCException>());
          expect(numRetries, 0);
        });
      });
    });
  });
}