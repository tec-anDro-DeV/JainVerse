import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/CountryModel.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';

class CountryPresenter extends BasePresenter {
  CountryPresenter() : super();

  Future<List<Country>> getCountries(BuildContext context) async {
    try {
      log('🌍 Fetching countries from API...');

      Response<String> response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_GET_COUNTRY,
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        log('✅ Countries API response received');

        CountryModel countryModel = CountryModel.fromJson(parsed);

        if (countryModel.status && countryModel.data.isNotEmpty) {
          log('📋 Successfully loaded ${countryModel.data.length} countries');
          return countryModel.data;
        } else {
          log('⚠️ API returned empty country list or failed status');
          return _getFallbackCountries();
        }
      } else {
        log('❌ Countries API failed with status: ${response.statusCode}');
        return _getFallbackCountries();
      }
    } catch (e) {
      log('💥 Error fetching countries: $e');
      return _getFallbackCountries();
    }
  }

  // Fallback countries in case API fails - using old static list format
  List<Country> _getFallbackCountries() {
    log('🔄 Using fallback country list');
    return [
      Country(
        id: 1,
        iso: 'US',
        name: 'UNITED STATES',
        nicename: 'United States',
        iso3: 'USA',
        numcode: 840,
        phonecode: 1,
      ),
      Country(
        id: 2,
        iso: 'CA',
        name: 'CANADA',
        nicename: 'Canada',
        iso3: 'CAN',
        numcode: 124,
        phonecode: 1,
      ),
      Country(
        id: 3,
        iso: 'GB',
        name: 'UNITED KINGDOM',
        nicename: 'United Kingdom',
        iso3: 'GBR',
        numcode: 826,
        phonecode: 44,
      ),
      Country(
        id: 4,
        iso: 'AU',
        name: 'AUSTRALIA',
        nicename: 'Australia',
        iso3: 'AUS',
        numcode: 36,
        phonecode: 61,
      ),
      Country(
        id: 5,
        iso: 'IN',
        name: 'INDIA',
        nicename: 'India',
        iso3: 'IND',
        numcode: 356,
        phonecode: 91,
      ),
      Country(
        id: 999,
        iso: 'OT',
        name: 'OTHER',
        nicename: 'Other',
        iso3: 'OTH',
        numcode: 999,
        phonecode: 0,
      ),
    ];
  }

  // Helper method to find country by old string value (for backward compatibility)
  Country? findCountryByOldValue(List<Country> countries, String oldValue) {
    // Map old static values to new country IDs/names
    switch (oldValue.toLowerCase()) {
      case 'united states':
        return countries.firstWhere(
          (c) =>
              c.nicename.toLowerCase().contains('united states') ||
              c.iso == 'US',
          orElse: () => countries.first,
        );
      case 'canada':
        return countries.firstWhere(
          (c) => c.nicename.toLowerCase().contains('canada') || c.iso == 'CA',
          orElse: () => countries.first,
        );
      case 'united kingdom':
        return countries.firstWhere(
          (c) =>
              c.nicename.toLowerCase().contains('united kingdom') ||
              c.iso == 'GB',
          orElse: () => countries.first,
        );
      case 'australia':
        return countries.firstWhere(
          (c) =>
              c.nicename.toLowerCase().contains('australia') || c.iso == 'AU',
          orElse: () => countries.first,
        );
      case 'india':
        return countries.firstWhere(
          (c) => c.nicename.toLowerCase().contains('india') || c.iso == 'IN',
          orElse: () => countries.first,
        );
      case 'other':
        return countries.firstWhere(
          (c) => c.nicename.toLowerCase().contains('other') || c.id == 999,
          orElse: () => countries.last,
        );
      default:
        // Try to find by partial name match
        return countries.firstWhere(
          (c) => c.nicename.toLowerCase().contains(oldValue.toLowerCase()),
          orElse: () => countries.first,
        );
    }
  }

  // Helper method to find country by ID (for new format)
  Country? findCountryById(List<Country> countries, int countryId) {
    try {
      return countries.firstWhere((c) => c.id == countryId);
    } catch (e) {
      log('⚠️ Country not found for ID: $countryId');
      return null;
    }
  }
}
