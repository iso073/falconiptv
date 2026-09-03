import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/tv_toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_text_field.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../iptv/data/repositories/m3u_repository.dart';
import '../../data/models/profile_model.dart';
import '../cubit/profile_cubit.dart';
import 'qr_add_profile_page.dart';

class AddProfilePage extends StatefulWidget {
  const AddProfilePage({super.key});

  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  ProfileType _selectedType = ProfileType.xtream;

  final TextEditingController _profileName = TextEditingController();
  final TextEditingController _serverUrl = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _m3uUrl = TextEditingController();
  final FocusNode _saveFocusNode = FocusNode(debugLabel: 'Kaydet');
  bool _saving = false;

  @override
  void dispose() {
    _profileName.dispose();
    _serverUrl.dispose();
    _username.dispose();
    _password.dispose();
    _m3uUrl.dispose();
    _saveFocusNode.dispose();
    super.dispose();
  }

  ProfileModel? _buildProfile() {
    final String profileName = _profileName.text.trim();
    if (profileName.isEmpty) {
      TvToastService.show(context, 'Lütfen profil adını giriniz.');
      return null;
    }

    if (_selectedType == ProfileType.xtream) {
      if (_serverUrl.text.trim().isEmpty ||
          _username.text.trim().isEmpty ||
          _password.text.trim().isEmpty) {
        TvToastService.show(
          context,
          'Lütfen Xtream Codes için zorunlu alanları eksiksiz doldurunuz.',
        );
        return null;
      }
      return ProfileModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        profileName: profileName,
        type: ProfileType.xtream,
        serverUrl: _serverUrl.text.trim(),
        username: _username.text.trim(),
        password: _password.text.trim(),
        createdDate: DateTime.now(),
      );
    }

    if (_m3uUrl.text.trim().isEmpty) {
      TvToastService.show(
        context,
        'Lütfen M3U oynatma listesi için zorunlu alanları eksiksiz doldurunuz.',
      );
      return null;
    }
    return ProfileModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      profileName: profileName,
      type: ProfileType.m3u,
      m3uUrl: _m3uUrl.text.trim(),
      createdDate: DateTime.now(),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final ProfileModel? profile = _buildProfile();
    if (profile == null) {
      return;
    }

    setState(() => _saving = true);
    TvToastService.show(
      context,
      'Bağlantı doğrulanıyor, lütfen bekleyiniz...',
      type: TvToastType.info,
      duration: const Duration(seconds: 30),
    );

    try {
      await context.read<IptvCatalogRepository>().validate(profile);
    } on IptvDataException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        TvToastService.show(context, error.message);
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        TvToastService.show(
          context,
          'Sunucuya bağlanılamadı. Lütfen adres ve internet bağlantınızı kontrol ediniz.',
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }
    await context.read<ProfileCubit>().addProfile(profile);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (context.read<ProfileCubit>().state is ProfileError) {
      return;
    }
    TvToastService.show(
      context,
      'Profil doğrulandı ve kaydedildi.',
      type: TvToastType.success,
    );
    Navigator.of(context).pop();
  }

  KeyEventResult _onSaveKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool isActivate = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space;
    if (isActivate) {
      _save();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.ambientGlow),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassmorphismBar(
                  child: Row(
                    children: [
                      NeonFocusCard(
                        width: 56,
                        height: 56,
                        padding: EdgeInsets.zero,
                        focusedScale: 1.08,
                        onActivate: () => Navigator.of(context).maybePop(),
                        child: const Center(child: Icon(Icons.arrow_back_rounded)),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Yeni Profil Oluştur',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      NeonFocusCard(
                        glowColor: AppColors.neonCyan,
                        focusedScale: 1.06,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        onActivate: () {
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              transitionDuration: const Duration(milliseconds: 300),
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const QrAddProfilePage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2_rounded, color: AppColors.neonCyan),
                            SizedBox(width: 8),
                            Text(
                              'Telefondan',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FocusTraversalOrder(
                                      order: const NumericFocusOrder(0),
                                      child: NeonFocusCard(
                                        glowColor: AppColors.neonCyan,
                                        focusedScale: 1.04,
                                        unfocusedOpacity:
                                            _selectedType == ProfileType.xtream ? 1 : 0.6,
                                        onActivate: () {
                                          setState(() => _selectedType = ProfileType.xtream);
                                        },
                                        child: const Center(
                                          child: Text(
                                            'Xtream Codes API',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: FocusTraversalOrder(
                                      order: const NumericFocusOrder(1),
                                      child: NeonFocusCard(
                                        glowColor: AppColors.neonPurple,
                                        focusedScale: 1.04,
                                        unfocusedOpacity:
                                            _selectedType == ProfileType.m3u ? 1 : 0.6,
                                        onActivate: () {
                                          setState(() => _selectedType = ProfileType.m3u);
                                        },
                                        child: const Center(
                                          child: Text(
                                            'M3U URL / Playlist',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(2),
                                child: TvTextField(
                                  label: 'Profil Adı',
                                  controller: _profileName,
                                  autofocus: true,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_selectedType == ProfileType.xtream) ...[
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(3),
                                  child: TvTextField(
                                    label: 'Sunucu URL',
                                    controller: _serverUrl,
                                    keyboardType: TextInputType.url,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(4),
                                  child: TvTextField(
                                    label: 'Kullanıcı Adı',
                                    controller: _username,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(5),
                                  child: TvTextField(
                                    label: 'Şifre',
                                    controller: _password,
                                    obscureText: true,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                  ),
                                ),
                              ] else ...[
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(3),
                                  child: TvTextField(
                                    label: 'Playlist Linki',
                                    controller: _m3uUrl,
                                    keyboardType: TextInputType.url,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FocusTraversalOrder(
                                  order: const NumericFocusOrder(11),
                                  child: _SaveButton(
                                    focusNode: _saveFocusNode,
                                    onKeyEvent: _onSaveKey,
                                    onActivate: _save,
                                    busy: _saving,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.focusNode,
    required this.onKeyEvent,
    required this.onActivate,
    required this.busy,
  });

  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final VoidCallback onActivate;
  final bool busy;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final bool hasFocus = widget.focusNode.hasFocus;
    if (hasFocus != _focused) {
      setState(() => _focused = hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onActivate();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 280,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _focused ? AppColors.neonCyan : AppColors.glassBorder,
              width: _focused ? 3 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.neonCyan.withValues(alpha: 0.55),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: widget.busy
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.neonCyan,
                    ),
                  )
                : const Text(
                    'Kaydet',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }
}
