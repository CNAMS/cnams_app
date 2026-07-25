// The sync transport contract and its HTTP implementation.
//
// A batch of outbox records is POSTed to /v1/sync/batch and the server replies
// with a per-record status. The record's UUID is the idempotency key, so the
// server must treat a repeated record as a no-op (FR-SRV-2).
//
// See docs/PRODUCTION_ROADMAP.md — Phase P4 §4.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Per-record outcome, mapped from the server's per-record status.
enum RecordStatus {
  ok, // 2xx  -> confirmed, remove from outbox
  conflict, // 409  -> last-write-wins applied server-side, remove locally
  rejected, // other 4xx -> permanent, dead-letter
  retryLater, // 5xx / transport failure -> keep and back off
}

/// One record to submit, taken from an outbox row.
class SyncRecord {
  const SyncRecord({
    required this.outboxId,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
  });

  final int outboxId;
  final String entity;
  final String entityId;
  final String op;
  final String payload; // JSON snapshot

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'entity_id': entityId,
        'op': op,
        'payload': json.decode(payload),
      };
}

/// The server's outcome for one record.
class RecordResult {
  const RecordResult(this.entityId, this.status);
  final String entityId;
  final RecordStatus status;
}

abstract class SyncApi {
  /// Submit a batch. Throws on a transport failure (caller treats the whole
  /// batch as [RecordStatus.retryLater]).
  Future<List<RecordResult>> submit(List<SyncRecord> records);
}

/// Maps an HTTP-style status code to a [RecordStatus].
RecordStatus statusFromCode(int code) {
  if (code >= 200 && code < 300) return RecordStatus.ok;
  if (code == 409) return RecordStatus.conflict;
  if (code >= 400 && code < 500) return RecordStatus.rejected;
  return RecordStatus.retryLater; // 5xx and anything else
}

class HttpSyncApi implements SyncApi {
  HttpSyncApi({
    required this.baseUrl,
    http.Client? client,
    this.authToken,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String? authToken;
  final http.Client _client;

  @override
  Future<List<RecordResult>> submit(List<SyncRecord> records) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/sync/batch'),
      headers: {
        'content-type': 'application/json',
        if (authToken != null) 'authorization': 'Bearer $authToken',
      },
      body: json.encode({
        'records': [for (final r in records) r.toJson()],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The batch call itself failed; let the caller back the whole batch off.
      throw http.ClientException(
        'sync batch failed: HTTP ${response.statusCode}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final results =
        (body['results'] as List<dynamic>).cast<Map<String, dynamic>>();
    return [
      for (final r in results)
        RecordResult(
          r['entity_id'] as String,
          statusFromCode(r['status'] as int),
        ),
    ];
  }
}
