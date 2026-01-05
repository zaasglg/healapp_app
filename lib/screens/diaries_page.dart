import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../config/app_config.dart';
import '../repositories/diary_repository.dart';
import '../utils/app_icons.dart';
import '../utils/performance_utils.dart';
import '../core/network/api_client.dart';

class DiariesPage extends StatelessWidget {
  const DiariesPage({super.key});
  static const String routeName = '/diaries';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiaryBloc()..add(const LoadDiaries()),
      child: const _DiariesPageContent(),
    );
  }
}

class _DiariesPageContent extends StatefulWidget {
  const _DiariesPageContent();

  @override
  State<_DiariesPageContent> createState() => _DiariesPageContentState();
}

class _DiariesPageContentState extends State<_DiariesPageContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isFirstBuild = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Перезагружаем список дневников при каждом возврате на страницу (кроме первого раза)
    if (!_isFirstBuild) {
      context.read<DiaryBloc>().add(const LoadDiaries());
    }
    _isFirstBuild = false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Diary> _filterDiaries(List<Diary> diaries) {
    if (_searchQuery.isEmpty) {
      return diaries;
    }
    return diaries.where((diary) {
      return diary.patientName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Мои дневники',
          style: GoogleFonts.firaSans(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  String? avatarUrl;
                  if (authState is AuthAuthenticated) {
                    avatarUrl = authState.user.avatar;
                  }
                  return _buildAvatar(avatarUrl);
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
                decoration: InputDecoration(
                  hintText: 'Поиск по имени подопечного...',
                  hintStyle: GoogleFonts.firaSans(
                    fontSize: 18,
                    color: Colors.grey.shade400,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade400),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF7F7F8),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Content based on state
            Expanded(
              child: BlocBuilder<DiaryBloc, DiaryState>(
                buildWhen: (previous, current) {
                  // Перестраиваем только при изменении состояния
                  return previous.runtimeType != current.runtimeType ||
                      (previous is DiariesLoaded &&
                          current is DiariesLoaded &&
                          previous.diaries.length != current.diaries.length);
                },
                builder: (context, state) {
                  if (state is DiaryLoading) {
                    return _buildShimmerLoading();
                  }

                  if (state is DiaryError) {
                    return _buildErrorState(context, state.message);
                  }

                  if (state is DiariesLoaded) {
                    final filteredDiaries = _filterDiaries(state.diaries);

                    if (state.diaries.isEmpty) {
                      return _buildEmptyState();
                    }

                    if (filteredDiaries.isEmpty && _searchQuery.isNotEmpty) {
                      return _buildNoResultsState();
                    }

                    return _buildDiariesList(context, filteredDiaries);
                  }

                  return _buildEmptyState();
                },
              ),
            ),

            // Create button
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                bool canCreateDiary = true;
                if (authState is AuthAuthenticated) {
                  if (authState.user.accountType == 'specialist') {
                    canCreateDiary = false;
                  }
                }

                if (!canCreateDiary) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        context.push('/select-ward-for-diary');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Создать новый дневник',
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 150,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Central icon with gradient
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppConfig.primaryColor.withOpacity(0.7),
                    AppConfig.primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Primary message
            Text(
              'У вас пока нет дневников',
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Secondary message
            Text(
              'Создайте первый дневник для подопечного',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'Ничего не найдено',
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Попробуйте изменить поисковый запрос',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<DiaryBloc>().add(const LoadDiaries());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
              ),
              child: Text(
                'Повторить',
                style: GoogleFonts.firaSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiariesList(BuildContext context, List<Diary> diaries) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DiaryBloc>().add(const LoadDiaries());
      },
      child: OptimizedListView(
        itemCount: diaries.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          final diary = diaries[index];
          return OptimizedWidget(child: _DiaryCard(diary: diary));
        },
      ),
    );
  }

  /// Виджет для отображения аватара пользователя
  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Преобразуем относительный путь в полный URL
      final fullUrl = ApiConfig.getFullUrl(avatarUrl);

      return ClipOval(
        child: Image.network(
          fullUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              child: Center(
                child: SvgPicture.asset(
                  AppIcons.profile,
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppConfig.primaryColor,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      child: Center(
        child: SvgPicture.asset(
          AppIcons.profile,
          width: 44,
          height: 44,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final Diary diary;

  const _DiaryCard({required this.diary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.push('/health-diary/${diary.id}/${diary.patientId}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with patient name and arrow
                Row(
                  children: [
                    // Patient name and info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diary.patientName,
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            diary.patientAge != null
                                ? '${diary.patientAge} лет'
                                : 'Возраст не указан',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow icon
                    Image.asset(
                      AppIcons.chevron_right,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _formatEntriesCount(int count) {
    if (count == 0) return 'Нет записей';
    if (count == 1) return '1 запись';
    if (count >= 2 && count <= 4) return '$count записи';
    return '$count записей';
  }

  String _formatDate(DateTime date) {
    return DateFormatterCache.formatRelativeDate(date);
  }
}
