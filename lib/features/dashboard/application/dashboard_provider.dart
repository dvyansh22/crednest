import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/models/user_profile_model.dart';
import '../data/dashboard_repository.dart';
import '../data/models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());

class DashboardState {
  final bool isLoading;
  final DashboardData? data;

  const DashboardState({this.isLoading = false, this.data});
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repository) : super(const DashboardState());

  final DashboardRepository _repository;

  Future<void> loadDashboard({required UserType userType}) async {
    state = const DashboardState(isLoading: true);
    final data = await _repository.getDashboardData(userType: userType);
    state = DashboardState(data: data);
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.watch(dashboardRepositoryProvider));
});
