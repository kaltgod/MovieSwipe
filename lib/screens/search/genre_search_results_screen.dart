import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/models/movie_model.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/services/tmdb_service.dart';
import 'package:movieswipe/screens/swipe/movie_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenreSearchResultsScreen extends StatefulWidget {
  final Set<int> genreIds;
  final bool requireAll;
  final String genreNamesTitle;

  const GenreSearchResultsScreen({
    super.key,
    required this.genreIds,
    required this.requireAll,
    required this.genreNamesTitle,
  });

  @override
  State<GenreSearchResultsScreen> createState() =>
      _GenreSearchResultsScreenState();
}

class _GenreSearchResultsScreenState extends State<GenreSearchResultsScreen> {
  final TmdbService _tmdbService = TmdbService();
  final ScrollController _scrollController = ScrollController();

  List<Movie> _results = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMorePages = true;

  final Set<int> _savedMovieIds = {};

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePages) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchFirstPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage = 1;
    });

    try {
      final movies = await _tmdbService.discoverMoviesByGenres(
        widget.genreIds,
        requireAll: widget.requireAll,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          _results = movies;
          _isLoading = false;
          if (movies.isEmpty) _hasMorePages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Не удалось загрузить фильмы по жанрам. Проверьте интернет.\n$e';
        });
      }
    }
  }

  Future<void> _fetchNextPage() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final movies = await _tmdbService.discoverMoviesByGenres(
        widget.genreIds,
        requireAll: widget.requireAll,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          if (movies.isEmpty) {
            _hasMorePages = false;
          } else {
            _results.addAll(movies);
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Optionally show a small snackbar for pagination error
        });
      }
    }
  }

  Future<void> _addToWatchlist(Movie movie) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('swipes').upsert({
        'user_id': userId,
        'movie_id': movie.id,
        'action': 'like',
        'rating': null,
      });
      if (mounted) {
        setState(() => _savedMovieIds.add(movie.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавлено в запланированные ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ошибка при добавлении')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.genreNamesTitle,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.primary),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentYellow),
            SizedBox(height: 24),
            Text(
              'Ищем лучшие фильмы...',
              style: TextStyle(color: AppTheme.secondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: AppTheme.accentRed,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.primary, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _fetchFirstPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.background,
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.film, color: AppTheme.secondary, size: 64),
              SizedBox(height: 24),
              Text(
                'По этим жанрам ничего не найдено\nПопробуйте изменить комбинацию.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.secondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                widget.requireAll
                    ? CupertinoIcons.link
                    : CupertinoIcons.layers_alt_fill,
                color: AppTheme.accentYellow,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.requireAll
                    ? 'Строгое совпадение жанров (И)'
                    : 'Желательное совпадение жанров (ИЛИ)',
                style: const TextStyle(color: AppTheme.secondary, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _results.length + (_isLoadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= _results.length) {
                // Loading placeholders at the bottom
                return Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentYellow,
                    strokeWidth: 2,
                  ),
                );
              }

              final movie = _results[index];
              return _buildMovieCard(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie) {
    final isSaved = _savedMovieIds.contains(movie.id);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            movie.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: movie.posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppTheme.surface),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.surface,
                      child: const Icon(
                        CupertinoIcons.film,
                        color: AppTheme.secondary,
                      ),
                    ),
                  )
                : Container(
                    color: AppTheme.surface,
                    child: const Icon(
                      CupertinoIcons.film,
                      color: AppTheme.secondary,
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            // Bookmark button — top right
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _addToWatchlist(movie),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSaved
                        ? AppTheme.accentYellow.withOpacity(0.9)
                        : Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSaved
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    color: isSaved ? AppTheme.background : AppTheme.primary,
                    size: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        color: AppTheme.accentYellow,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
