import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/local_user.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  final List<String> _languageOptions = const [
    'English',
    'Hindi',
    'Tamil',
    'Malayalam',
    'Telugu',
  ];

  String _selectedLanguage = 'English';

  bool _captionsOn = true;
  bool _highContrast = true;
  bool _vibrationAlerts = false;
  bool _wordMeaningPopup = true;
  bool _communityNotifications = true;
  bool _sosConfirmation = true;
  bool _saveInProgress = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loaded) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _usernameController.text = user.username;
      _emailController.text = user.email;
      _passwordController.text = user.password;
      _confirmPasswordController.text = user.password;
      _pinController.text = user.pin ?? '';
      _selectedLanguage = user.preferredLanguage;
    }

    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    HapticFeedback.lightImpact();

    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      _showSnackBar('Please fill all required fields');
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showSnackBar('Password and confirm password must match');
      return;
    }

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('No logged in user found');
      return;
    }

    setState(() => _saveInProgress = true);

    final updatedUser = LocalUser(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      pin: _pinController.text.trim().isEmpty ? null : _pinController.text.trim(),
      preferredLanguage: _selectedLanguage,
    );

    await auth.updateProfile(updatedUser);

    if (!mounted) return;

    context.read<LanguageProvider>().setLanguage(_selectedLanguage);

    setState(() => _saveInProgress = false);
    _showSnackBar('Profile settings updated successfully');
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go(AppConstants.routeLogin);
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceLg,
            ),
            child: Column(
              children: [
                _TopBar(
                  onBackTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppConstants.routeDashboard);
                    }
                  },
                ),
                const SizedBox(height: AppConstants.spaceSm),
                const _Header(),
                const SizedBox(height: AppConstants.spaceMd),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 120 + bottomInset),
                    child: Column(
                      children: [
                        FadeInUp(
                          delay: const Duration(milliseconds: 60),
                          child: _ProfileHero(
                            name: user?.name ?? 'User',
                            username: user?.username != null
                                ? '@${user!.username}'
                                : '@captrio_user',
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        FadeInUp(
                          delay: const Duration(milliseconds: 110),
                          child: _SectionCard(
                            title: 'Profile Details',
                            child: Column(
                              children: [
                                _InputField(
                                  label: 'Name',
                                  controller: _nameController,
                                  icon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 14),
                                _InputField(
                                  label: 'Username',
                                  controller: _usernameController,
                                  icon: Icons.alternate_email_rounded,
                                ),
                                const SizedBox(height: 14),
                                _InputField(
                                  label: 'Email',
                                  controller: _emailController,
                                  icon: Icons.mail_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                _DropdownField(
                                  label: 'Preferred Language',
                                  value: _selectedLanguage,
                                  icon: Icons.language_rounded,
                                  items: _languageOptions,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedLanguage = value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        FadeInUp(
                          delay: const Duration(milliseconds: 160),
                          child: _SectionCard(
                            title: 'Security',
                            child: Column(
                              children: [
                                _InputField(
                                  label: 'Password',
                                  controller: _passwordController,
                                  icon: Icons.lock_rounded,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 14),
                                _InputField(
                                  label: 'Confirm Password',
                                  controller: _confirmPasswordController,
                                  icon: Icons.verified_user_rounded,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 14),
                                _InputField(
                                  label: 'PIN (Optional)',
                                  controller: _pinController,
                                  icon: Icons.pin_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        FadeInUp(
                          delay: const Duration(milliseconds: 210),
                          child: _SectionCard(
                            title: 'Accessibility & Preferences',
                            child: Column(
                              children: [
                                _SettingToggleTile(
                                  title: 'Captions Enabled',
                                  subtitle: 'Keep translated text visible across features',
                                  value: _captionsOn,
                                  icon: Icons.closed_caption_rounded,
                                  onChanged: (v) => setState(() => _captionsOn = v),
                                ),
                                const SizedBox(height: 12),
                                _SettingToggleTile(
                                  title: 'High Contrast Mode',
                                  subtitle: 'Improve readability for texts and controls',
                                  value: _highContrast,
                                  icon: Icons.contrast_rounded,
                                  onChanged: (v) => setState(() => _highContrast = v),
                                ),
                                const SizedBox(height: 12),
                                _SettingToggleTile(
                                  title: 'Word Meaning Popup',
                                  subtitle: 'Show meaning card when a transcript word is tapped',
                                  value: _wordMeaningPopup,
                                  icon: Icons.auto_awesome_rounded,
                                  onChanged: (v) => setState(() => _wordMeaningPopup = v),
                                ),
                                const SizedBox(height: 12),
                                _SettingToggleTile(
                                  title: 'Vibration Alerts',
                                  subtitle: 'Use device vibration for important events',
                                  value: _vibrationAlerts,
                                  icon: Icons.vibration_rounded,
                                  onChanged: (v) => setState(() => _vibrationAlerts = v),
                                ),
                                const SizedBox(height: 12),
                                _SettingToggleTile(
                                  title: 'Community Notifications',
                                  subtitle: 'Receive updates for comments and replies',
                                  value: _communityNotifications,
                                  icon: Icons.notifications_active_rounded,
                                  onChanged: (v) => setState(() => _communityNotifications = v),
                                ),
                                const SizedBox(height: 12),
                                _SettingToggleTile(
                                  title: 'SOS Confirmation',
                                  subtitle: 'Ask before sending SOS to saved contacts',
                                  value: _sosConfirmation,
                                  icon: Icons.sos_rounded,
                                  onChanged: (v) => setState(() => _sosConfirmation = v),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceLg),
                        FadeInUp(
                          delay: const Duration(milliseconds: 310),
                          child: _PrimaryButton(
                            label: _saveInProgress ? 'Saving...' : 'Save Changes',
                            onTap: _saveInProgress ? null : _saveProfile,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeInUp(
                          delay: const Duration(milliseconds: 340),
                          child: _LogoutButton(
                            onTap: _logout,
                          ),
                        ),
                      ],
                    ),
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

class _TopBar extends StatelessWidget {
  final VoidCallback onBackTap;

  const _TopBar({
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spaceMd,
        bottom: AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBackTap,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Text(
                'CAPTRIO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.settings_suggest_rounded,
              color: AppColors.textSecondary,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Profile & Settings',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String username;

  const _ProfileHero({
    required this.name,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusFull,
                    ),
                  ),
                  child: const Text(
                    'Captrio Member',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          child,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _InputField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    dropdownColor: AppColors.surface3,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _SettingToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5F7A).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: const Color(0xFFFF5F7A).withValues(alpha: 0.42),
          ),
        ),
        child: const Center(
          child: Text(
            'Logout',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7B8F),
            ),
          ),
        ),
      ),
    );
  }
}