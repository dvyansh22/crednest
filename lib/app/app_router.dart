import 'package:go_router/go_router.dart';

// Placeholder imports — swap these for real screens as each feature is built
import '../features/splash/presentation/splash_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/consent/presentation/consent_center_screen.dart';
import '../features/consent/presentation/consent_details_screen.dart';
import '../features/consent/data/models/consent_model.dart';
import '../features/kyc/presentation/kyc_screen.dart';
import '../features/kyc/presentation/kyc_status_screen.dart';
import '../features/financial_data/presentation/connect_bank_screen.dart';
import '../features/gst/presentation/connect_gst_screen.dart';
import '../features/psychometric/presentation/psychometric_quiz_screen.dart';
import '../features/location/presentation/location_consent_screen.dart';
import '../features/credit_score/presentation/score_loading_screen.dart';
import '../features/credit_score/presentation/score_result_screen.dart';
import '../features/credit_score/presentation/report_screen.dart';
import '../features/marketplace/presentation/offers_list_screen.dart';
import '../features/data_benefit_ledger/presentation/ledger_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/profile/presentation/profile_setup_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/consent', builder: (context, state) => const ConsentCenterScreen()),
    GoRoute(
      path: '/consent/:id',
      builder: (context, state) => ConsentDetailsScreen(
        consentId: state.pathParameters['id']!,
        initialConsent: state.extra as ConsentModel?,
      ),
    ),
    GoRoute(path: '/kyc', builder: (context, state) => const KycScreen()),
    GoRoute(path: '/kyc-status', builder: (context, state) => const KycStatusScreen()),
    GoRoute(path: '/connect-bank', builder: (context, state) => const ConnectBankScreen()),
    GoRoute(path: '/connect-gst', builder: (context, state) => const ConnectGstScreen()),
    GoRoute(path: '/psychometric-quiz', builder: (context, state) => const PsychometricQuizScreen()),
    GoRoute(path: '/location-consent', builder: (context, state) => const LocationConsentScreen()),
    GoRoute(path: '/score-loading', builder: (context, state) => const ScoreLoadingScreen()),
    GoRoute(path: '/score-result', builder: (context, state) => const ScoreResultScreen()),
    GoRoute(path: '/offers', builder: (context, state) => const OffersListScreen()),
    GoRoute(path: '/ledger', builder: (context, state) => const LedgerScreen()),
    GoRoute(path: '/dashboard', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/profile-setup', builder: (context, state) => const ProfileSetupScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/credit-dna-report', builder: (context, state) => const ReportScreen()),
  ],
);