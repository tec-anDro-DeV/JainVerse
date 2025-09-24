import 'dart:io';
import '../services/artist_service.dart';

abstract class ArtistRepository {
  Future<Map<String, dynamic>> submitArtistRequest({
    required String firstName,
    required String lastName,
    required String mobile,
    required String dateOfBirth,
    required String gender,
    required String token,
    File? profileImage,
  });

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    File? profileImage,
    String? firstName,
    String? lastName,
    String? mobile,
    String? dateOfBirth,
    String? gender,
  });
}

class ArtistRepositoryImpl implements ArtistRepository {
  final ArtistService _artistService;

  ArtistRepositoryImpl({ArtistService? artistService})
    : _artistService = artistService ?? ArtistService();

  @override
  Future<Map<String, dynamic>> submitArtistRequest({
    required String firstName,
    required String lastName,
    required String mobile,
    required String dateOfBirth,
    required String gender,
    required String token,
    File? profileImage,
  }) async {
    return await _artistService.submitArtistRequest(
      firstName: firstName,
      lastName: lastName,
      mobile: mobile,
      dateOfBirth: dateOfBirth,
      gender: gender,
      token: token,
      profileImage: profileImage,
    );
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String token,
    File? profileImage,
    String? firstName,
    String? lastName,
    String? mobile,
    String? dateOfBirth,
    String? gender,
  }) async {
    return await _artistService.updateProfile(
      token: token,
      profileImage: profileImage,
      firstName: firstName,
      lastName: lastName,
      mobile: mobile,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
  }
}
