import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/models/movie_model.dart';
import 'package:movieswipe/services/tmdb_service.dart';
import 'package:movieswipe/widgets/auth_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _tmdbService = TmdbService();
  final _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  bool _isSaving = false;

  List<Movie> _movies = [];
  final List<Movie> _selectedMovies = [];

  @override
  void initState() {
    super.initState();
    _loadInitialMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialMovies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final movies = await _tmdbService.getPopularMovies(page: 1);
      if (mounted) {
        setState(() {
          _movies = movies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchMovies(String query) async {
    if (query.isEmpty) {
      _loadInitialMovies();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _tmdbService.searchMovies(query);
      if (mounted) {
        setState(() {
          _movies = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchMovies(query);
    });
  }

  void _toggleMovieSelection(Movie movie) {
    setState(() {
      if (_selectedMovies.any((m) => m.id == movie.id)) {
        _selectedMovies.removeWhere((m) => m.id == movie.id);
      } else {
        if (_selectedMovies.length < 5) {
          _selectedMovies.add(movie);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы уже выбрали 5 фильмов!')),
          );
        }
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedMovies.length != 5) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      for (final movie in _selectedMovies) {
        await _supabase.from('swipes').upsert({
          'user_id': userId,
          'movie_id': movie.id,
          'action': 'watched',
          'rating': 10.0,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при сохранении результатов')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Выбери 5 любимых фильмов',
          style: TextStyle(color: AppTheme.primary, fontSize: 18),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false, // Cannot go back
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selection indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: AppTheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Выбрано: ${_selectedMovies.length} / 5',
                    style: TextStyle(
                      color: _selectedMovies.length == 5
                          ? AppTheme.primary
                          : AppTheme.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: _selectedMovies.isEmpty
                        ? const Center(
                            child: Text(
                              'Пока ничего не выбрано',
                              style: TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            itemCount: _selectedMovies.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final movie = _selectedMovies[index];
                              return GestureDetector(
                                onTap: () => _toggleMovieSelection(movie),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: movie.posterUrl.isNotEmpty
                                      ? Image.network(
                                          movie.posterUrl,
                                          width: 32,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 32,
                                          height: 48,
                                          color: AppTheme.background,
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppTheme.primary),
                decoration: InputDecoration(
                  hintText: 'Поиск фильмов...',
                  hintStyle: const TextStyle(color: AppTheme.secondary),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: AppTheme.secondary,
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Movies Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _movies.isEmpty
                  ? const Center(
                      child: Text(
                        'Ничего не найдено',
                        style: TextStyle(color: AppTheme.secondary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ).copyWith(bottom: 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _movies.length,
                      itemBuilder: (context, index) {
                        final movie = _movies[index];
                        final isSelected = _selectedMovies.any(
                          (m) => m.id == movie.id,
                        );

                        return GestureDetector(
                          onTap: () => _toggleMovieSelection(movie),
                          child: Stack(
                            children: [
                              // Poster
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: movie.posterUrl.isNotEmpty
                                      ? Image.network(
                                          movie.posterUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: AppTheme.surface,
                                                  ),
                                        )
                                      : Container(color: AppTheme.surface),
                                ),
                              ),
                              // Dim overlay if selected
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.primary,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedMovies.length == 5
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.background,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'Завершить',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            )
          : null,
    );
  }
}
