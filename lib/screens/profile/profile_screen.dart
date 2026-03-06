import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/services/auth_service.dart';
import 'package:movieswipe/widgets/auth_wrapper.dart';
import 'package:movieswipe/services/tmdb_service.dart';
import 'package:movieswipe/models/movie_model.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movieswipe/screens/swipe/movie_details_screen.dart';
import 'package:movieswipe/screens/profile/watched_movies_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  final _tmdbService = TmdbService();

  bool _isLoading = true;
  int _moviesCount = 0;
  int _plannedCount = 0;
  String _avgRating = '0.0';

  List<Movie> _plannedMovies = [];
  List<Movie> _watchedMovies = [];
  List<MapEntry<String, int>> _favoriteGenres = [];
  Map<int, double> _userRatings = {};

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await _supabase
          .from('swipes')
          .select('action, rating, movie_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      int moviesWatched = 0;
      int plannedMovies = 0;
      double totalRating = 0;
      int ratedMovies = 0;

      List<int> plannedIds = [];
      List<int> watchedIds = [];
      Map<int, double> tempRatings = {};

      for (var row in data) {
        if (row['action'] == 'watched' ||
            row['action'] == 'like' ||
            row['action'] == 'dislike') {
          if (row['action'] == 'watched') {
            moviesWatched++;
            watchedIds.add(row['movie_id'] as int);
          }
          if (row['action'] == 'like') {
            plannedMovies++;
            plannedIds.add(row['movie_id'] as int);
          }
        }
        if (row['rating'] != null) {
          double ratingVal = (row['rating'] as num).toDouble();
          totalRating += ratingVal;
          ratedMovies++;
          tempRatings[row['movie_id'] as int] = ratingVal;
        }
      }

      // Fetch full movie details for posters
      List<Movie> loadedPlanned = [];
      List<Movie> loadedWatched = [];

      if (plannedIds.isNotEmpty) {
        final results = await Future.wait(
          plannedIds.map((id) => _tmdbService.getMovieById(id)),
        );
        loadedPlanned = results.whereType<Movie>().toList();
      }

      if (watchedIds.isNotEmpty) {
        final results = await Future.wait(
          watchedIds.map((id) => _tmdbService.getMovieById(id)),
        );
        loadedWatched = results.whereType<Movie>().toList();
      }

      Map<String, int> genreCounts = {};
      for (var movie in loadedWatched) {
        for (var genre in movie.genres) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }
      var sortedGenres = genreCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      List<MapEntry<String, int>> topGenres = sortedGenres.take(5).toList();

      if (mounted) {
        setState(() {
          _moviesCount = moviesWatched;
          _plannedCount = plannedMovies;
          _avgRating = ratedMovies > 0
              ? (totalRating / ratedMovies).toStringAsFixed(1)
              : '0.0';
          _plannedMovies = loadedPlanned;
          _watchedMovies = loadedWatched;
          _favoriteGenres = topGenres;
          _userRatings = tempRatings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName =
        user?.userMetadata?['username'] as String? ??
        user?.email?.split('@')[0] ??
        'Guest';
    final displayEmail = user?.email ?? 'Not logged in';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: null,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.square_arrow_right),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (From Style 1)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.surface,
                      child: Icon(
                        CupertinoIcons.person_solid,
                        size: 40,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayEmail,
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats Row (Compact)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatBlock(
                        'Фильмов',
                        _isLoading ? '-' : '$_moviesCount',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBlock(
                        'Ср.оценка',
                        _isLoading ? '-' : _avgRating,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Favorite Genres (From Style 3)
              _buildSectionTitle('Любимые жанры', ''),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: _isLoading
                      ? [const CircularProgressIndicator()]
                      : _favoriteGenres.isEmpty
                      ? [
                          const Text(
                            'Пока нет данных о жанрах',
                            style: TextStyle(color: AppTheme.secondary),
                          ),
                        ]
                      : _favoriteGenres
                            .map((genre) => _buildGenreChip(genre))
                            .toList(),
                ),
              ),

              const SizedBox(height: 32),

              // Plan to watch (From Style 1)
              _buildSectionTitle(
                'Запланировано',
                _isLoading ? '-' : '$_plannedCount',
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMovieHorizontalList(_plannedMovies),

              const SizedBox(height: 32),

              // My Ratings (From Style 1)
              _buildSectionTitle(
                'Оцененные фильмы',
                'Все',
                onActionTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WatchedMoviesScreen(
                        movies: _watchedMovies,
                        userRatings: _userRatings,
                        onDataChanged: fetchProfileData,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildWatchedVerticalList(_watchedMovies),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // COMMON HELPERS
  // ===========================================================================

  Widget _buildStatBlock(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String actionLabel, {
    VoidCallback? onActionTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (actionLabel.isNotEmpty)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionLabel,
                style: const TextStyle(color: AppTheme.secondary, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMovieHorizontalList(List<Movie> movies) {
    if (movies.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Список пока пуст',
            style: TextStyle(color: AppTheme.secondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          MovieDetailsScreen(movie: movie),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  )
                  .then((_) => fetchProfileData());
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: movie.posterUrl.isNotEmpty
                          ? Image.network(
                              movie.posterUrl,
                              fit: BoxFit.cover,
                              width: 140,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: AppTheme.surface),
                            )
                          : Container(color: AppTheme.surface),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWatchedVerticalList(List<Movie> movies) {
    if (movies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Text(
            'Вы еще не оценили ни одного фильма',
            style: TextStyle(color: AppTheme.secondary),
          ),
        ),
      );
    }

    final top10Movies = movies.take(10).toList();

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: top10Movies.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final movie = top10Movies[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        MovieDetailsScreen(movie: movie),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                )
                .then((_) => fetchProfileData());
          },
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: movie.posterUrl.isNotEmpty
                      ? Image.network(
                          movie.posterUrl,
                          width: 70,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 70,
                                height: 100,
                                color: AppTheme.background,
                              ),
                        )
                      : Container(
                          width: 70,
                          height: 100,
                          color: AppTheme.background,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Displaying individual user rating
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppTheme.accentYellow,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userRatings[movie.id] != null
                                ? _userRatings[movie.id]!.toStringAsFixed(1)
                                : '-',
                            style: const TextStyle(
                              color: AppTheme.accentYellow,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: AppTheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenreChip(MapEntry<String, int> genreEntry) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            genreEntry.key,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              genreEntry.value.toString(),
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
