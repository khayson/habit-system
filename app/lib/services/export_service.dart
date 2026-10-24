import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../config/api_config.dart';
import '../core/exceptions/app_exception.dart';
import '../core/network/api_client.dart';
import '../models/export_job.dart';

/// Phase 6.1 (A48): export jobs and the download. Explicit network actions; nothing here is
/// written to the app's database.
class ExportService {
  final ApiClient _api;

  const ExportService(this._api);

  /// POST /exports {format}: the new job, or the one already being prepared.
  Future<ExportJob> request(String format) async =>
      (await _api.post(ApiConfig.exports, _job, data: {'format': format})).data;

  /// GET /exports: the 5 newest, newest first.
  Future<List<ExportJob>> list() async => (await _api.get(ApiConfig.exports, (data) {
    try {
      return [for (final j in data as List) ExportJob.fromJson((j as Map).cast())];
    } on Object {
      throw _unexpected;
    }
  })).data;

  Future<ExportJob> get(String id) async => (await _api.get(ApiConfig.export(id), _job)).data;

  /// Streams a ready job's file into [folder] with the bearer token and returns it. The caller
  /// hands it to the share sheet and deletes it afterwards.
  Future<File> download(ExportJob job, String folder) async {
    final url = job.downloadUrl;
    if (url == null) throw _unexpected;
    final file = File(p.join(folder, 'habit-export.${job.format == 'csv' ? 'csv' : 'zip'}'));
    try {
      await _api.dio.download(url, file.path);
    } on DioException catch (e) {
      if (file.existsSync()) file.deleteSync();
      throw AppException.fromDioException(e);
    }
    return file;
  }

  static ExportJob _job(dynamic data) {
    try {
      return ExportJob.fromJson((data as Map).cast<String, dynamic>());
    } on Object {
      throw _unexpected;
    }
  }

  static const _unexpected = AppException(
    kind: AppErrorKind.unexpected,
    code: 'unexpected_response',
    message: 'Something went wrong. Try again.',
  );
}
