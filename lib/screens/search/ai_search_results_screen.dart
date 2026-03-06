import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/models/movie_model.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/services/ai_service.dart';
import 'package:movieswipe/services/tmdb_service.dart';
import 'package:movieswipe/screens/swipe/movie_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiSearchResultsScreen extends StatefulWidget {
  final String query;

  const AiSearchResultsScreen({super.key, required this.query});

  @override
  State<AiSearchResultsScreen> createState() => _AiSearchResultsScreenState();
}

class _AiSearchResultsScreenState extends State<AiSearchResultsScreen> {
  final AiService _aiService = AiService();
  final TmdbService _tmdbService = TmdbService();

  List<Movie> _results = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<int> _savedMovieIds = {};

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
  void initState() {
    super.initState();
    _performAiSearch();
  }

  Future<void> _performAiSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Get titles from Groq LLaMA-3
      final titles = await _aiService.searchMoviesByMood(widget.query);

      if (titles.isEmpty) {
        setState(() {
          _errorMessage = 'Не удалось найти фильмы по такому запросу.';
          _isLoading = false;
        });
        return;
      }

      // 2. Resolve titles via TMDB
      final futures = titles.map((title) => _tmdbService.searchMovies(title));
      final tmdbResultsLists = await Future.wait(futures);

      List<Movie> finalMovies = [];
      for (var resultList in tmdbResultsLists) {
        if (resultList.isNotEmpty) {
          finalMovies.add(resultList.first);
        }
      }

      setState(() {
        _results = finalMovies;
        _isLoading = false;
        if (_results.isEmpty) {
          _errorMessage = 'Не удалось загрузить данные о фильмах.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла ошибка при поиске: \$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'ИИ Поиск',
          style: TextStyle(color: AppTheme.primary),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.accentYellow),
            const SizedBox(height: 24),
            Text(
              'Анализируем запрос...',
              style: TextStyle(
                color: AppTheme.secondary.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${widget.query}"',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: AppTheme.primary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _performAiSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surface,
                  foregroundColor: AppTheme.primary,
                ),
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Результаты по запросу:',
            style: TextStyle(
              color: AppTheme.secondary.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '"${widget.query}"',
            style: const TextStyle(
              color: AppTheme.accentYellow,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) {
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
