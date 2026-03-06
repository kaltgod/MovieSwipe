import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/models/movie_model.dart';
import 'package:movieswipe/screens/swipe/movie_details_screen.dart';

class WatchedMoviesScreen extends StatelessWidget {
  final List<Movie> movies;
  final Map<int, double> userRatings;
  final VoidCallback onDataChanged;

  const WatchedMoviesScreen({
    super.key,
    required this.movies,
    required this.userRatings,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Оцененные фильмы',
          style: TextStyle(color: AppTheme.primary, fontSize: 18),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: movies.isEmpty
          ? const Center(
              child: Text(
                'Список пока пуст',
                style: TextStyle(color: AppTheme.secondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: movies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final movie = movies[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    MovieDetailsScreen(movie: movie),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                            transitionDuration: const Duration(
                              milliseconds: 300,
                            ),
                          ),
                        )
                        .then((_) => onDataChanged());
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
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppTheme.accentYellow,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    userRatings[movie.id] != null
                                        ? userRatings[movie.id]!
                                              .toStringAsFixed(1)
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
            ),
    );
  }
}
