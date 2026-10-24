import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/models/export_job.dart';
import 'package:habit/services/export_service.dart';
import 'package:path/path.dart' as p;

import '../core/api_client_test.dart' show CannedAdapter, MemoryTokenStore;
import '../support/contract_fixtures.dart';

/// Phase 6.1 (A48): export jobs on the app, decoded from contract-fixtures/exports/export_job.json.
void main() {
  final fixture = contractFixture('exports/export_job.json');
  final jobs = (fixture['jobs'] as Map).cast<String, dynamic>();

  Map<String, dynamic> envelope(Object? data) => {
    'data': data,
    'meta': {'api_version': '1', 'server_time': '2026-05-28T17:22:00Z', 'request_id': 'r1'},
  };

  (ExportService, CannedAdapter) service(Object body, {int status = 200}) {
    final adapter = CannedAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;
    return (ExportService(ApiClient.withDio(dio, MemoryTokenStore('t'))), adapter);
  }

  test('export_job declares the Dart suite', () => expect(fixture['suites'], contains('dart')));

  for (final status in ['queued', 'running', 'ready', 'failed', 'expired']) {
    test('decodes a $status job', () async {
      final wire = materialize(jobs[status]) as Map<String, dynamic>;
      final (exports, adapter) = service(envelope(wire));

      final job = await exports.get('0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f');

      expect(adapter.lastRequest!.path, '/exports/0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f');
      expect(
        (job.id, job.format, job.status, job.errorCode),
        (wire['id'], 'json', ExportStatus.from(status), wire['error_code']),
      );
      expect(job.requestedAt, DateTime.utc(2026, 5, 28, 17, 22));
      expect(job.downloadUrl, wire['download_url']);
      expect(job.expiresAt == null, wire['expires_at'] == null);
    });
  }

  test('lists jobs newest first as sent', () async {
    final list = materialize(fixture['list']) as Map<String, dynamic>;
    final (exports, adapter) = service(envelope(list['data']));

    final got = await exports.list();

    expect(adapter.lastRequest!.path, '/exports');
    expect(got.map((j) => j.status), [ExportStatus.ready, ExportStatus.failed]);
  });

  test('requests a job with its format', () async {
    final (exports, adapter) = service(envelope(materialize(jobs['queued'])), status: 202);

    final job = await exports.request('csv');

    expect(adapter.lastRequest!.method, 'POST');
    expect(adapter.lastRequest!.data, {'format': 'csv'});
    expect(job.status, ExportStatus.queued);
  });

  test('an unknown status word is kept as unknown, never a crash', () async {
    final wire = {...materialize(jobs['queued']) as Map<String, dynamic>, 'status': 'archived'};
    final job = await service(envelope(wire)).$1.get('x');
    expect(job.status, ExportStatus.unknown);
  });

  test('a missing id is unexpected_response', () async {
    final wire = Map<String, dynamic>.from(materialize(jobs['queued']) as Map)..remove('id');
    await expectLater(
      service(envelope(wire)).$1.get('x'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'unexpected_response')),
    );
  });

  test('downloads into the given folder with the bearer token', () async {
    final adapter = _BytesAdapter([80, 75, 3, 4]);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;
    final dir = Directory.systemTemp.createTempSync('export_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final exports = ExportService(ApiClient.withDio(dio, MemoryTokenStore('t')));
    const job = ExportJob(
      id: 'j1',
      format: 'json',
      status: ExportStatus.ready,
      requestedAt: null,
      downloadUrl: 'http://api.test/api/v1/exports/j1/download?expires=1&signature=s',
    );

    final file = await exports.download(job, dir.path);

    expect(p.basename(file.path), 'habit-export.zip');
    expect(file.readAsBytesSync(), [80, 75, 3, 4]);
    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer t');
  });
}

class _BytesAdapter implements HttpClientAdapter {
  final List<int> bytes;
  RequestOptions? lastRequest;

  _BytesAdapter(this.bytes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}
