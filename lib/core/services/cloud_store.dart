import 'package:cloud_firestore/cloud_firestore.dart';

/// Where backups live. Documents are JSON text keyed `shared` or `lang_<id>`.
abstract interface class CloudStore {
  /// All documents for [uid], or an empty map when nothing is stored yet.
  Future<Map<String, String>> load(String uid);

  /// Writes (replaces) the given documents.
  Future<void> save(String uid, Map<String, String> documents);

  /// Removes one document, e.g. after a language reset.
  Future<void> delete(String uid, String documentId);

  /// Removes every document for [uid].
  Future<void> deleteAll(String uid);
}

/// Used when Firebase is missing.
class NoCloudStore implements CloudStore {
  const NoCloudStore();

  @override
  Future<Map<String, String>> load(String uid) async => {};

  @override
  Future<void> save(String uid, Map<String, String> documents) async {}

  @override
  Future<void> delete(String uid, String documentId) async {}

  @override
  Future<void> deleteAll(String uid) async {}
}

/// [CloudStore] on Cloud Firestore: `users/{uid}/backup/{documentId}`.
class FirestoreCloudStore implements CloudStore {
  FirestoreCloudStore([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('backup');

  @override
  Future<Map<String, String>> load(String uid) async {
    final snap = await _col(uid).get();
    return {
      for (final d in snap.docs)
        if (d.data()['json'] is String) d.id: d.data()['json'] as String,
    };
  }

  @override
  Future<void> save(String uid, Map<String, String> documents) async {
    final batch = _db.batch();
    for (final e in documents.entries) {
      batch.set(_col(uid).doc(e.key), {
        'json': e.value,
        'updated': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> delete(String uid, String documentId) =>
      _col(uid).doc(documentId).delete();

  @override
  Future<void> deleteAll(String uid) async {
    final snap = await _col(uid).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
