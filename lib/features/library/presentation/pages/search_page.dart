import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../../core/widgets/tv_text_field.dart';
import '../../../catalog/presentation/pages/catalog_browser_page.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../settings/domain/adult_content_policy.dart';
import '../playback_launcher.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const String _keys = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789';

  final TextEditingController _query = TextEditingController();
  List<PlayableItem> _results = const <PlayableItem>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String text = _query.text.trim();
    if (text.length < 2) {
      setState(() {
        _results = const <PlayableItem>[];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<PlayableItem> found =
          await context.read<IptvCatalogRepository>().search(PlaybackLauncher.profileOf(context), text);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = found
            .where((PlayableItem item) => !AdultContentPolicy.isAdult(item.category))
            .take(80)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  void _append(String value) {
    _query.text = '${_query.text}$value';
    _query.selection = TextSelection.collapsed(offset: _query.text.length);
    _search();
  }

  void _backspace() {
    if (_query.text.isEmpty) {
      return;
    }
    _query.text = _query.text.substring(0, _query.text.length - 1);
    _query.selection = TextSelection.collapsed(offset: _query.text.length);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return TvBackScope(
      onBack: () => popToPreviousPage(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              child: Column(
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
                        const Icon(Icons.search, color: AppColors.neonCyan, size: 32),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Arama',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TvTextField(
                    label: 'Kanal, film veya dizi adı',
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 168,
                    child: GridView.builder(
                      clipBehavior: Clip.none,
                      itemCount: _keys.length + 2,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 14,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (context, index) {
                        if (index == _keys.length) {
                          return NeonFocusCard(
                            padding: EdgeInsets.zero,
                            focusedScale: 1.08,
                            onActivate: _backspace,
                            child: const Center(child: Icon(Icons.backspace_outlined, size: 20)),
                          );
                        }
                        if (index == _keys.length + 1) {
                          return NeonFocusCard(
                            padding: EdgeInsets.zero,
                            focusedScale: 1.08,
                            glowColor: AppColors.neonPurple,
                            onActivate: () => _append(' '),
                            child: const Center(
                              child: Text('Boşluk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          );
                        }
                        final String letter = _keys[index];
                        return NeonFocusCard(
                          autofocus: index == 0,
                          padding: EdgeInsets.zero,
                          focusedScale: 1.08,
                          onActivate: () => _append(letter),
                          child: Center(
                            child: Text(letter, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildResults()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonCyan));
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_query.text.trim().length < 2) {
      return const Center(
        child: Text(
          'Aramak için en az iki karakter giriniz.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Eşleşen kayıt bulunamadı.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      clipBehavior: Clip.none,
      itemCount: _results.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final PlayableItem item = _results[index];
        return CatalogTile(
          item: item,
          accent: AppColors.neonCyan,
          icon: Icons.play_circle_outline,
          onActivate: () => PlaybackLauncher.openItem(context, item),
        );
      },
    );
  }
}
