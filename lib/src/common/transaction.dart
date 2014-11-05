part of datastore.common;

class Transaction {

  final Uint8List _id;

  /**
   * The datastore assigned id of the datastore id, encoded as a
   * hex string.
   */
  String get id => CryptoUtils.bytesToBase64(_id);

  bool _isCommitted = false;
  /**
   * `true` iff the transaction has been committed to the datastore.
   */
  bool get isCommitted => _isCommitted;

  bool _isRolledBack = false;
  /**
   * `true` iff the transaction has been committed and subsequently rolled back.
   */
  bool get isRolledBack => _isRolledBack;


  /**
   * A list of entities which will be inserted into the
   * datastore when the transaction is committed.
   */
  List<Entity> insert = new List<Entity>();

  /**
   * A list of entities which will be updated in the datastore
   * when the transaction is committed.
   */
  List<Entity> update = new List<Entity>();
  /**
   * A list of entities to upsert into the datastore when the
   * transaction is committed.
   *
   * An upserted entity is inserted into the datastore if no
   * entity with a matching key already exists, otherwise
   * the matching entity is updated.
   */
  List<Entity> upsert = new List<Entity>();
  /**
   * A list of keys to delete from the datastore when the
   * transaction is committed.
   */
  List<Key> delete = new List<Key>();

  Transaction._(Uint8List this._id);

  factory Transaction._cloneWithId(Transaction transaction, Uint8List id) {
    return new Transaction._(id)
        ..insert.addAll(transaction.insert)
        ..update.addAll(transaction.update)
        ..upsert.addAll(transaction.upsert)
        ..delete.addAll(transaction.delete);
  }

  schema.Mutation _toSchemaMutation() {
    return new schema.Mutation()
      ..insert.addAll(insert.map((ent) => ent._toSchemaEntity()))
      ..upsert.addAll(upsert.map((ent) => ent._toSchemaEntity()))
      ..update.addAll(update.map((ent) => ent._toSchemaEntity()))
      ..delete.addAll(delete.map((k) => k._toSchemaKey()));
  }
}

/**
 * Represents a [Transaction] which is queued to run
 */
class PendingTransaction {
  Completer<Transaction> transaction;
  final int retryCount;
  final Transaction retryTransaction;

  PendingTransaction(this.retryTransaction, this.retryCount):
    this.transaction = new Completer<Transaction>();
}

/**
 * Schedules transactions so that no two transactions are concurrently
 * executed on the datastore.
 *
 * Also handles retrying commits which failed by rolling back the transaction
 * and creating a new, cloned transaction with exponential backoff.
 *
 * This is inefficient, but since the google cloud datastore can throw an
 * exception even if the transaction is committed, it's a small price to pay
 * for safety.
 */
class TransactionScheduler {
  //TODO: Implement serializable transactions (transactions which can run concurrently
  // if they do not touch the same entity groups).

  final _RANDOM = new math.Random();

  final DatastoreConnection connection;
  Queue<PendingTransaction> pendingTransactions;
  Logger logger;

  TransactionScheduler(this.connection, [Logger logger]):
    this.pendingTransactions = new Queue<PendingTransaction>();

  /**
   * Helper method for exectuting an action in a transactional context.
   * The transaction is automatically commited when the [:action:] finishes.
   *
   * If [:action:] completes with a [Future], the transaction will be commited
   * when the future completes, or rolled back if the [Future] completes with
   * an error and the error will be rethrown.
   *
   * Otherwise, the return value of [:action:] is ignored.
   *
   * Returns the transaction.
   */
  Future<Transaction> withTransaction(dynamic action(Transaction transaction)) {
    return begin().then((transaction) {
      var result;
      try {
        result = action(transaction);
      } catch (err) {
        result = new Future.error(err);
      }
      if (result is! Future) {
        result = new Future.value(result);
      }
      return result
        .catchError((err) {
          rollback(transaction);
          throw err;
        }).then((_) {
          logger.info('Committing transaction (${transaction.id})');
          return commit(transaction);
        });
    });
  }

  /**
   * Begins the transaction and adds a new [PendingTransaction] to the
   * queue.
   *
   * If the retry count is >= 0, a delay of `2^(retryCount - 1) + (random milliseconds)`
   * is inserted before beginning the transaction.
   */
  Future<Transaction> begin([Transaction retryTransaction, retryCount=0]) {

    var delay;
    if (retryCount <= 0) {
      retryCount = 0;
      delay = new Future.value();
    } else {
      var delayDuration = new Duration(
          seconds: math.pow(2, retryCount - 1).ceil(),
          milliseconds: _RANDOM.nextInt(1000)
      );
      delay = new Future.delayed(delayDuration);
    }

    var rollbackThenDelay;
    if (retryTransaction != null) {
      rollbackThenDelay = rollback(retryTransaction)
          .then((_) => delay)
          .catchError((err, stackTrace) => new Future.error(err, stackTrace));
    } else {
      rollbackThenDelay = delay;
    }

    return rollbackThenDelay.then((_) {
      var pending = new PendingTransaction(retryTransaction, retryCount);
      pendingTransactions.addLast(pending);
      _runNextTransaction();
      return pending.transaction.future;
    });
  }


  void _runNextTransaction() {
    if (pendingTransactions.isEmpty)
      return;
    var pendingTransaction = pendingTransactions.removeFirst();
    connection.beginTransaction(new schema.BeginTransactionRequest()).then((response) {
      if (pendingTransaction.retryCount <= 0) {
        pendingTransaction.transaction.complete(
            new Transaction._(response.transaction)
        );
      } else {
        var transaction = new Transaction._cloneWithId(
            pendingTransaction.retryTransaction,
            response.transaction
        );
        return commit(transaction, pendingTransaction.retryCount).then((transaction) {
          pendingTransaction.transaction.complete(transaction);
        });
      }
    })
    .catchError((err, stackTrace) {
      pendingTransaction.transaction.completeError(err, stackTrace);
    })
    .then((_) {
      _runNextTransaction();
    });
  }

  Future<Transaction> commit(Transaction transaction, [int retryCount=0]) {
    logger.info('Committing transaction ${transaction.id}');
    var request = new schema.CommitRequest()
        ..transaction = transaction._id
        ..mutation = transaction._toSchemaMutation();
    return connection.commit(request).then((response) {
      transaction._isCommitted = true;
      return transaction;
    }).catchError(
        (err) {
          logger.warning('Commit failed with status ${err.status}. Retrying...');
          return begin(transaction, ++retryCount);
        },
        test: (err) => err is RPCException &&
            retryCount < connection.maxRequestRetries &&
            connection.retryStatusCodes.contains(err.status)
    );
  }

  Future<Transaction> rollback(Transaction transaction, [int retryCount=0]) {
    logger.info('Rolling back transaction (ID: ${transaction.id})');
    var request = new schema.RollbackRequest()
        ..transaction = transaction._id;
    return connection.rollback(request)
    .then((_) => transaction.._isRolledBack = true)
    .catchError(
        (err) {
          logger.warning('Rollback failed with status ${err.status}. Retrying');
          return rollback(transaction, ++retryCount);
        },
        test: (err) => err is RPCException &&
            retryCount < connection.maxRequestRetries &&
            connection.retryStatusCodes.contains(err.status)
    );
  }
}