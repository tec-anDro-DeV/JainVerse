/// Model for video report options
class ReportOption {
  final int id;
  final String reportType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReportOption({
    required this.id,
    required this.reportType,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportOption.fromJson(Map<String, dynamic> json) {
    return ReportOption(
      id: json['id'] as int,
      reportType: json['report_type'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_type': reportType,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
