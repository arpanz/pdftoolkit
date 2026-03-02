import 'dart:io';

enum PdfOperation { merge, split, protect, unlock, imageToPdf }

extension PdfOperationExt on PdfOperation {
  String get label {
    switch (this) {
      case PdfOperation.merge:
        return 'Merged';
      case PdfOperation.split:
        return 'Split';
      case PdfOperation.protect:
        return 'Protected';
      case PdfOperation.unlock:
        return 'Unlocked';
      case PdfOperation.imageToPdf:
        return 'Image→PDF';
    }
  }

  String get icon {
    switch (this) {
      case PdfOperation.merge:
        return '🔀';
      case PdfOperation.split:
        return '✂️';
      case PdfOperation.protect:
        return '🔒';
      case PdfOperation.unlock:
        return '🔓';
      case PdfOperation.imageToPdf:
        return '🖼️';
    }
  }
}

class PdfFileModel {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final int pageCount;
  final PdfOperation operation;
  final DateTime createdAt;
  final int processingMs;

  PdfFileModel({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.pageCount,
    required this.operation,
    required this.createdAt,
    required this.processingMs,
  });

  double get sizeMb => sizeBytes / (1024 * 1024);

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${sizeMb.toStringAsFixed(2)}MB';
  }

  String get formattedProcessingTime {
    if (processingMs < 1000) return '${processingMs}ms';
    return '${(processingMs / 1000).toStringAsFixed(1)}s';
  }

  bool get fileExists => File(path).existsSync();

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'sizeBytes': sizeBytes,
    'pageCount': pageCount,
    'operation': operation.index,
    'createdAt': createdAt.toIso8601String(),
    'processingMs': processingMs,
  };

  factory PdfFileModel.fromJson(Map<String, dynamic> json) => PdfFileModel(
    id: json['id'] as String,
    path: json['path'] as String,
    name: json['name'] as String,
    sizeBytes: json['sizeBytes'] as int,
    pageCount: json['pageCount'] as int,
    operation: PdfOperation.values[json['operation'] as int],
    createdAt: DateTime.parse(json['createdAt'] as String),
    processingMs: json['processingMs'] as int,
  );
}

class ProcessingResult {
  final bool success;
  final String? outputPath;
  final String? error;
  final int pageCount;
  final int processingMs;

  const ProcessingResult({
    required this.success,
    this.outputPath,
    this.error,
    this.pageCount = 0,
    this.processingMs = 0,
  });
}
