#!/bin/bash
# Run this from inside your Flutter project root (creditdna_app/)
# after `flutter create creditdna_app` and `cd creditdna_app`
# Usage: bash setup_structure.sh

set -e

echo "Creating CreditDNA folder structure..."

# ---- assets ----
mkdir -p assets/images assets/icons assets/fonts assets/animations
touch assets/images/.gitkeep assets/icons/.gitkeep assets/fonts/.gitkeep assets/animations/.gitkeep

# ---- app ----
mkdir -p lib/app
touch lib/app/app.dart lib/app/app_router.dart lib/app/app_theme.dart

# ---- core ----
mkdir -p lib/core/config lib/core/constants lib/core/network lib/core/storage lib/core/security lib/core/utils
touch lib/core/config/env.dart lib/core/config/api_config.dart
touch lib/core/constants/app_colors.dart lib/core/constants/app_strings.dart lib/core/constants/app_constants.dart
touch lib/core/network/api_client.dart lib/core/network/api_interceptors.dart lib/core/network/api_endpoints.dart lib/core/network/api_exceptions.dart
touch lib/core/storage/secure_storage.dart lib/core/storage/local_storage.dart
touch lib/core/security/token_manager.dart lib/core/security/encryption_service.dart
touch lib/core/utils/validators.dart lib/core/utils/formatters.dart lib/core/utils/helpers.dart

# ---- shared ----
mkdir -p lib/shared/widgets lib/shared/models
touch lib/shared/widgets/app_button.dart lib/shared/widgets/app_text_field.dart lib/shared/widgets/loading_widget.dart lib/shared/widgets/error_widget.dart
touch lib/shared/models/api_response.dart

# ---- features helper function ----
make_feature () {
  local name=$1
  shift
  local subdirs=("$@")
  mkdir -p "lib/features/$name"
  for sub in "${subdirs[@]}"; do
    mkdir -p "lib/features/$name/$sub"
    touch "lib/features/$name/$sub/.gitkeep"
  done
}

# splash
mkdir -p lib/features/splash/presentation
touch lib/features/splash/presentation/splash_screen.dart

# onboarding
mkdir -p lib/features/onboarding/presentation
touch lib/features/onboarding/presentation/onboarding_screen.dart lib/features/onboarding/presentation/onboarding_controller.dart

# auth
mkdir -p lib/features/auth/data/models lib/features/auth/data/repositories lib/features/auth/application lib/features/auth/presentation
touch lib/features/auth/data/models/user_model.dart
touch lib/features/auth/data/repositories/auth_repository.dart
touch lib/features/auth/application/auth_provider.dart
touch lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/signup_screen.dart

# profile
mkdir -p lib/features/profile/data lib/features/profile/application lib/features/profile/presentation
touch lib/features/profile/data/.gitkeep lib/features/profile/application/.gitkeep lib/features/profile/presentation/.gitkeep

# consent
mkdir -p lib/features/consent/data/models lib/features/consent/data/repositories lib/features/consent/application lib/features/consent/presentation
touch lib/features/consent/data/models/consent_model.dart
touch lib/features/consent/data/repositories/consent_repository.dart
touch lib/features/consent/application/consent_provider.dart
touch lib/features/consent/presentation/consent_screen.dart

# financial_data (Account Aggregator)
mkdir -p lib/features/financial_data/data/models lib/features/financial_data/data/repositories lib/features/financial_data/data/datasources lib/features/financial_data/application lib/features/financial_data/presentation
touch lib/features/financial_data/data/models/transaction_model.dart
touch lib/features/financial_data/data/repositories/financial_repository.dart
touch lib/features/financial_data/data/datasources/aa_remote_datasource.dart
touch lib/features/financial_data/application/financial_data_provider.dart
touch lib/features/financial_data/presentation/connect_bank_screen.dart lib/features/financial_data/presentation/bank_status_screen.dart lib/features/financial_data/presentation/transaction_summary_screen.dart

# gst
mkdir -p lib/features/gst/data/models lib/features/gst/data/repositories lib/features/gst/application lib/features/gst/presentation
touch lib/features/gst/data/models/gst_model.dart
touch lib/features/gst/data/repositories/gst_repository.dart
touch lib/features/gst/application/gst_provider.dart
touch lib/features/gst/presentation/connect_gst_screen.dart

# kyc
mkdir -p lib/features/kyc/data/models lib/features/kyc/data/repositories lib/features/kyc/application lib/features/kyc/presentation
touch lib/features/kyc/data/models/kyc_model.dart
touch lib/features/kyc/data/repositories/kyc_repository.dart
touch lib/features/kyc/application/kyc_provider.dart
touch lib/features/kyc/presentation/kyc_screen.dart lib/features/kyc/presentation/kyc_status_screen.dart

# psychometric
mkdir -p lib/features/psychometric/data/models lib/features/psychometric/application lib/features/psychometric/presentation
touch lib/features/psychometric/data/models/quiz_model.dart
touch lib/features/psychometric/application/quiz_provider.dart
touch lib/features/psychometric/presentation/psychometric_quiz_screen.dart

# location
mkdir -p lib/features/location/data lib/features/location/application lib/features/location/presentation
touch lib/features/location/data/location_repository.dart
touch lib/features/location/application/location_provider.dart
touch lib/features/location/presentation/location_consent_screen.dart

# credit_score
mkdir -p lib/features/credit_score/data/models lib/features/credit_score/data/repositories lib/features/credit_score/application lib/features/credit_score/presentation
touch lib/features/credit_score/data/models/score_model.dart
touch lib/features/credit_score/data/repositories/scoring_repository.dart
touch lib/features/credit_score/application/score_provider.dart
touch lib/features/credit_score/presentation/score_loading_screen.dart lib/features/credit_score/presentation/score_result_screen.dart lib/features/credit_score/presentation/report_screen.dart

# marketplace (OCEN)
mkdir -p lib/features/marketplace/data/models lib/features/marketplace/data/repositories lib/features/marketplace/application lib/features/marketplace/presentation
touch lib/features/marketplace/data/models/loan_offer_model.dart
touch lib/features/marketplace/data/repositories/marketplace_repository.dart
touch lib/features/marketplace/application/marketplace_provider.dart
touch lib/features/marketplace/presentation/offers_list_screen.dart lib/features/marketplace/presentation/offer_detail_screen.dart

# loan_status
mkdir -p lib/features/loan_status/data lib/features/loan_status/application lib/features/loan_status/presentation
touch lib/features/loan_status/data/.gitkeep lib/features/loan_status/application/.gitkeep lib/features/loan_status/presentation/.gitkeep

# data_benefit_ledger (added per your deck's differentiator)
mkdir -p lib/features/data_benefit_ledger/data/models lib/features/data_benefit_ledger/data/repositories lib/features/data_benefit_ledger/application lib/features/data_benefit_ledger/presentation
touch lib/features/data_benefit_ledger/data/models/ledger_entry_model.dart
touch lib/features/data_benefit_ledger/data/repositories/ledger_repository.dart
touch lib/features/data_benefit_ledger/application/ledger_provider.dart
touch lib/features/data_benefit_ledger/presentation/ledger_screen.dart

# dashboard
mkdir -p lib/features/dashboard/application lib/features/dashboard/presentation
touch lib/features/dashboard/application/dashboard_provider.dart
touch lib/features/dashboard/presentation/home_screen.dart lib/features/dashboard/presentation/financial_report_screen.dart

# ---- test ----
mkdir -p test/core test/features
touch test/core/.gitkeep test/features/.gitkeep

echo "Done. Folder structure created under lib/, assets/, and test/."
echo "Run 'flutter pub get' next, then start filling in core/network/api_client.dart"

