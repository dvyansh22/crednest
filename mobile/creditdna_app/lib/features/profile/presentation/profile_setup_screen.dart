import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/auth_text_field.dart';
import '../../auth/application/auth_provider.dart';
import '../data/models/user_profile_model.dart';
import '../providers/user_profile_provider.dart';

/// Collects the financial-profile details CredNest needs beyond auth
/// identity. Reused for both first-time setup and later edits — whichever
/// profile data already exists (local cache) pre-fills the form.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  EmploymentType _employmentType = EmploymentType.salaried;
  IncomeCategory _incomeCategory = IncomeCategory.r25kTo50k;
  UserType _userType = UserType.individual;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authProvider).user;
    final existingProfile = ref.read(userProfileProvider).profile;

    _nameController = TextEditingController(text: existingProfile?.fullName ?? authUser?.name ?? '');
    _phoneController = TextEditingController(text: existingProfile?.phoneNumber ?? '');
    _emailController = TextEditingController(text: existingProfile?.email ?? authUser?.email ?? '');

    if (existingProfile != null) {
      _employmentType = existingProfile.employmentType;
      _incomeCategory = existingProfile.incomeCategory;
      _userType = existingProfile.userType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final profile = UserProfileModel(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      employmentType: _employmentType,
      incomeCategory: _incomeCategory,
      userType: _userType,
      profileCompleted: true,
      updatedAt: DateTime.now(),
    );

    await ref.read(userProfileProvider.notifier).saveProfile(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);
    context.go('/dashboard');
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your phone number';
    if (value.trim().length < 10) return 'Please enter a valid phone number';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email address';
    final emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Please enter a valid email address';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canPop) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy, height: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A few details so we can build a CreditDNA profile that fits your financial life.',
                  style: TextStyle(fontSize: 14.5, color: AppColors.subGrey, height: 1.4),
                ),
                const SizedBox(height: 28),

                AuthTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  hintText: 'e.g. Sneha Kumari',
                  prefixIcon: Icons.person_outline,
                  validator: _validateName,
                ),
                const SizedBox(height: 18),

                AuthTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  hintText: 'e.g. 98765 43210',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 18),

                AuthTextField(
                  controller: _emailController,
                  labelText: 'Email Address',
                  hintText: 'e.g. name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),

                _SectionLabel('Employment Type'),
                const SizedBox(height: 8),
                _StyledDropdown<EmploymentType>(
                  value: _employmentType,
                  items: EmploymentType.values,
                  labelOf: (e) => e.label,
                  icon: Icons.work_outline,
                  onChanged: (value) => setState(() => _employmentType = value),
                ),
                const SizedBox(height: 18),

                _SectionLabel('Income Category'),
                const SizedBox(height: 8),
                _StyledDropdown<IncomeCategory>(
                  value: _incomeCategory,
                  items: IncomeCategory.values,
                  labelOf: (e) => e.label,
                  icon: Icons.payments_outlined,
                  onChanged: (value) => setState(() => _incomeCategory = value),
                ),
                const SizedBox(height: 18),

                _SectionLabel('You are best described as'),
                const SizedBox(height: 10),
                _UserTypeSelector(
                  selected: _userType,
                  onSelected: (value) => setState(() => _userType = value),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Continue to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.navy, fontSize: 14, fontWeight: FontWeight.w600));
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final IconData icon;
  final ValueChanged<T> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.subGrey),
      style: const TextStyle(color: AppColors.navy, fontSize: 14.5, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        fillColor: AppColors.fieldFill,
        filled: true,
        prefixIcon: Icon(icon, color: AppColors.subGrey, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(labelOf(item)))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _UserTypeSelector extends StatelessWidget {
  final UserType selected;
  final ValueChanged<UserType> onSelected;

  const _UserTypeSelector({required this.selected, required this.onSelected});

  static const _icons = {
    UserType.individual: Icons.person_outline,
    UserType.gigWorker: Icons.two_wheeler_outlined,
    UserType.msme: Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: UserType.values.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: type != UserType.values.last ? 10 : 0),
            child: GestureDetector(
              onTap: () => onSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blueTint : AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? AppColors.blue : Colors.transparent, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(_icons[type], size: 22, color: isSelected ? AppColors.blue : AppColors.subGrey),
                    const SizedBox(height: 6),
                    Text(
                      type.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.navy : AppColors.subGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
