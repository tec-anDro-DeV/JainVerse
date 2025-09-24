class ModelSettings {
  bool status;
  String msg;
  ModelSettingsData data;
  PaymentGateWays payment_gateways;

  ModelSettings(this.status, this.msg, this.data, this.payment_gateways);

  factory ModelSettings.fromJson(Map<dynamic, dynamic> json) {
    return ModelSettings(
      json['status'],
      json['msg'],
      ModelSettingsData.fromJson(json['data']),
      PaymentGateWays.fromJson(json['payment_gateways']),
    );
  }
}

class PaymentGateWays {
  RazorpayDetails razorpay;
  StripeDetails stripe;
  PayStackDetails paystack;
  PaypalDetails paypal;

  PaymentGateWays(this.razorpay, this.stripe, this.paystack, this.paypal);

  factory PaymentGateWays.fromJson(Map<dynamic, dynamic> json) {
    return PaymentGateWays(
      RazorpayDetails.fromJson(json['razorpay']),
      StripeDetails.fromJson(json['stripe']),
      PayStackDetails.fromJson(json['paystack']),
      PaypalDetails.fromJson(json['paypal']),
    );
  }
}

class PaypalDetails {
  String paypal_client_id;
  String paypal_secret;
  String paypal_mode;

  PaypalDetails(this.paypal_client_id, this.paypal_secret, this.paypal_mode);

  factory PaypalDetails.fromJson(Map<dynamic, dynamic> json) {
    return PaypalDetails(
      json['paypal_client_id'] ?? '',
      json['paypal_secret'] ?? '',
      json['paypal_mode'] ?? '',
    );
  }
}

class RazorpayDetails {
  String razorpay_key;
  String razorpay_secret;

  RazorpayDetails(this.razorpay_key, this.razorpay_secret);

  factory RazorpayDetails.fromJson(Map<dynamic, dynamic> json) {
    return RazorpayDetails(
      json['razorpay_key'] ?? '',
      json['razorpay_secret'] ?? '',
    );
  }
}

class PayStackDetails {
  String paystack_public_key;
  String paystack_secret_key;
  String paystack_payment_key;

  PayStackDetails(
    this.paystack_public_key,
    this.paystack_secret_key,
    this.paystack_payment_key,
  );

  factory PayStackDetails.fromJson(Map<dynamic, dynamic> json) {
    return PayStackDetails(
      json['paystack_public_key'] ?? '',
      json['paystack_secret_key'] ?? '',
      json['paystack_payment_key'] ?? '',
    );
  }
}

class StripeDetails {
  String stripe_client_id;
  String stripe_secret;
  String stripe_merchant_display_name;
  String stripe_merchant_country_code;
  String stripe_merchant_country_identifier;

  StripeDetails(
    this.stripe_client_id,
    this.stripe_secret,
    this.stripe_merchant_display_name,
    this.stripe_merchant_country_code,
    this.stripe_merchant_country_identifier,
  );

  factory StripeDetails.fromJson(Map<dynamic, dynamic> json) {
    return StripeDetails(
      json['stripe_client_id'] ?? '',
      json['stripe_secret'] ?? '',
      json['stripe_merchant_display_name'] ?? '',
      json['stripe_merchant_country_code'] ?? '',
      json['stripe_merchant_country_identifier'] ?? '',
    );
  }
}

class PlanDetails {
  int id;
  String plan_name = "";
  String plan_amount = "";
  int is_month_days;
  int validity;
  int is_download;
  int show_advertisement;

  PlanDetails(
    this.id,
    this.plan_name,
    this.plan_amount,
    this.is_month_days,
    this.validity,
    this.is_download,
    this.show_advertisement,
  );

  factory PlanDetails.fromJson(Map<String, dynamic> json) {
    return PlanDetails(
      json['id'] ?? 0,
      json['plan_name'] ?? '',
      json['plan_amount'] ?? '',
      json['is_month_days'] ?? 0,
      json['validity'] ?? 0,
      json['is_download'] ?? 0,
      json['show_advertisement'] ?? 0,
    );
  }
}

class ModelSettingsData {
  int id;

  String name = "";
  String fname = "";
  String lname = "";
  String email = "";
  String mobile = "";
  String image = "";
  String dob = "";
  String country_id = ""; // Keep as string for backward compatibility
  int? country_id_numeric; // Add numeric version for new API
  String currencyCode = "";
  String currencySymbol = "";
  String tax = "";
  String purchased_plan_date = "";
  String key_rzp = "";
  String admin_rzp_key = "";
  String google_api_key = "";
  String yt_channel_key = "";
  String yt_country_code = "";
  int is_youtube;

  int download;
  int in_app_purchase;
  int ads;
  String gender; // This can be null in JSON
  String status; // Keep as String, handle conversion
  String plan_expiry_date;
  PlanDetails? plan_detail; // Make nullable since it might not exist in JSON

  ModelSettingsData(
    this.id,
    this.name,
    this.fname,
    this.lname,
    this.email,
    this.mobile,
    this.image,
    this.dob,
    this.country_id,
    this.country_id_numeric,
    this.currencyCode,
    this.currencySymbol,
    this.tax,
    this.purchased_plan_date,
    this.key_rzp,
    this.admin_rzp_key,
    this.download,
    this.ads,
    this.gender,
    this.status,
    this.google_api_key,
    this.is_youtube,
    this.yt_country_code,
    this.yt_channel_key,
    this.plan_expiry_date,
    this.in_app_purchase,
    this.plan_detail,
  );

  factory ModelSettingsData.fromJson(Map<String, dynamic> json) {
    // Handle backward compatibility for country_id
    String countryIdString = json['country_id']?.toString() ?? '';
    int? countryIdNumeric;

    // Try to parse country_id as numeric if it's a number
    if (json['country_id'] != null) {
      if (json['country_id'] is int) {
        countryIdNumeric = json['country_id'];
        // For backward compatibility, also store as string
        countryIdString = json['country_id'].toString();
      } else if (json['country_id'] is String) {
        // Try to parse string as number for new format
        final parsed = int.tryParse(json['country_id']);
        if (parsed != null) {
          countryIdNumeric = parsed;
        }
        countryIdString = json['country_id'];
      }
    }

    return ModelSettingsData(
      json['id'] ?? 0,
      json['name'] ?? '',
      json['fname'] ?? '',
      json['lname'] ?? '',
      json['email'] ?? '',
      json['mobile'] ?? '',
      json['image'] ?? '',
      json['dob'] ?? '',
      countryIdString, // Use processed country_id string
      countryIdNumeric, // Add numeric country_id
      json['currencyCode'] ?? '',
      json['currencySymbol'] ?? '',
      json['tax'] ?? '',
      json['purchased_plan_date'] ?? '',
      json['key_rzp'] ?? '',
      json['admin_rzp_key'] ?? '',
      json['download'] ?? 0,
      json['ads'] ?? 0,
      json['gender']?.toString() ?? '', // Convert to string, handle null
      json['status']?.toString() ?? '0', // Convert int to string, handle null
      json['google_api_key'] ?? '',
      json['is_youtube'] ?? 0,
      json['yt_country_code'] ?? '',
      json['yt_channel_key'] ?? '',
      json['plan_expiry_date'] ?? '',
      json['in_app_purchase'] ?? 0,
      json['plan_detail'] != null
          ? PlanDetails.fromJson(json['plan_detail'])
          : null, // Handle null case
    );
  }
}
