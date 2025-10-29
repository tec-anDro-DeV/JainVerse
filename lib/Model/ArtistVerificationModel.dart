// Model for file upload response from backend
class FileUploadResponse {
  final String url;
  final String publicUrl;

  FileUploadResponse({required this.url, required this.publicUrl});

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      url: json['url'] ?? '',
      publicUrl: json['public_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'public_url': publicUrl};
  }
}

// Model for verification request data
class VerificationRequestData {
  final String document;
  final String certificate;

  VerificationRequestData({required this.document, required this.certificate});

  Map<String, dynamic> toJson() {
    return {'document': document, 'certificate': certificate};
  }
}

// Model for verification status response
class VerificationStatusResponse {
  final bool status;
  final String msg;
  final VerificationStatusData? data;

  VerificationStatusResponse({
    required this.status,
    required this.msg,
    this.data,
  });

  factory VerificationStatusResponse.fromJson(Map<String, dynamic> json) {
    return VerificationStatusResponse(
      status: json['status'] ?? false,
      msg: json['msg'] ?? '',
      data:
          json['data'] != null
              ? VerificationStatusData.fromJson(json['data'])
              : null,
    );
  }
}

// Model for verification status data
class VerificationStatusData {
  final String
  artistVerifyStatus; // normalized: pending, verified, rejected, not_uploaded
  final String
  originalStatus; // original value as received from API (e.g. "Pending")
  final String reason;
  final String? documentUrl;
  final String? certificateUrl;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  VerificationStatusData({
    required this.artistVerifyStatus,
    required this.originalStatus,
    required this.reason,
    this.documentUrl,
    this.certificateUrl,
    this.submittedAt,
    this.reviewedAt,
  });

  factory VerificationStatusData.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['artist_verify_status']?.toString() ?? '';
    final normalizedStatus = _normalizeStatus(rawStatus);

    return VerificationStatusData(
      artistVerifyStatus: normalizedStatus,
      originalStatus: rawStatus,
      reason: json['reason'] ?? '',
      documentUrl: json['document_url'],
      certificateUrl: json['certificate_url'],
      submittedAt:
          json['submitted_at'] != null
              ? DateTime.tryParse(json['submitted_at'])
              : null,
      reviewedAt:
          json['reviewed_at'] != null
              ? DateTime.tryParse(json['reviewed_at'])
              : null,
    );
  }

  String get statusDisplayText {
    switch (artistVerifyStatus) {
      case 'pending':
        return 'Pending Review';
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'not_uploaded':
        return 'Documents Not Uploaded';
      default:
        if (originalStatus.isNotEmpty) {
          return originalStatus;
        }
        return 'Unknown';
    }
  }

  bool get isPending => artistVerifyStatus == 'pending';
  bool get isVerified => artistVerifyStatus == 'verified';
  bool get isApproved => isVerified; // Backward compatibility naming
  bool get isRejected => artistVerifyStatus == 'rejected';
  bool get isNotUploaded => artistVerifyStatus == 'not_uploaded';

  // Legacy compatibility getters for backward compatibility
  String get verifyStatus {
    switch (artistVerifyStatus) {
      case 'pending':
        return 'P';
      case 'verified':
        return 'A';
      case 'rejected':
        return 'R';
      case 'not_uploaded':
        return 'N';
      default:
        return '';
    }
  }

  String? get rejectionReason => reason.isNotEmpty ? reason : null;
}

String _normalizeStatus(String status) {
  final value = status.trim().toLowerCase();

  switch (value) {
    case 'pending':
    case 'p':
      return 'pending';
    case 'verified':
    case 'approved':
    case 'a':
      return 'verified';
    case 'rejected':
    case 'r':
      return 'rejected';
    case 'not uploaded':
    case 'not_uploaded':
    case 'notuploaded':
    case 'n':
      return 'not_uploaded';
    default:
      return value;
  }
}

// Model for verification submission response
class VerificationSubmissionResponse {
  final bool status;
  final String message;

  VerificationSubmissionResponse({required this.status, required this.message});

  factory VerificationSubmissionResponse.fromJson(Map<String, dynamic> json) {
    return VerificationSubmissionResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
