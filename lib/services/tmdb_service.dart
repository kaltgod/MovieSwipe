import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:movieswipe/models/movie_model.dart';

class TmdbService {
  final String _baseUrl = 'https://api.tmdb.org/3';
  late final String _apiKey;

  // Cache for genres
  Map<int, String> _genresCache = {};

  TmdbService() {
    _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      print('WARNING: TMDB_API_KEY is not found in .env');
    }
  }

  // Helper to attach authorization header
  Map<String, String> get _headers => {'accept': 'application/json'};

  /// Fetch movie genres and cache them
  Future<void> fetchGenres() async {
    if (_genresCache.isNotEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/genre/movie/list?language=ru-RU&api_key=$_apiKey'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> genresList = data['genres'];
        for (var genre in genresList) {
          _genresCache[genre['id']] = genre['name'];
        }
      } else {
        print('Error fetching genres: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception fetching genres: $e');
    }
  }

  /// Resolve genre IDs to strings and inject into Movie object
  void _injectGenres(Movie movie) {
    if (_genresCache.isEmpty) return; // Can't resolve

    List<String> resolved = [];
    for (var id in movie.genreIds) {
      if (_genresCache.containsKey(id)) {
        // Capitalize first letter for better UI
        String name = _genresCache[id]!;
        if (name.isNotEmpty) {
          name = name[0].toUpperCase() + name.substring(1);
        }
        resolved.add(name);
      }
    }
    movie.genres = resolved;
  }

  /// Fetch popular movies (used for swiping functionality)
  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    // Ensure genres are loaded first
    await fetchGenres();

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/movie/popular?language=ru-RU&page=$page&api_key=$_apiKey',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];

        List<Movie> movies = results
            .map((json) => Movie.fromJson(json))
            .toList();

        // Filter out movies without posters
        movies = movies.where((m) => m.posterUrl.isNotEmpty).toList();

        // Inject string genres
        for (var m in movies) {
          _injectGenres(m);
        }

        return movies;
      } else {
        print('Error fetching popular movies: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching popular movies: $e');
      return [];
    }
  }

  /// Search movies by title
  Future<List<Movie>> searchMovies(String query) async {
    await fetchGenres();

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search/movie?language=ru-RU&query=${Uri.encodeComponent(query)}&api_key=$_apiKey',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];

        List<Movie> movies = results
            .map((json) => Movie.fromJson(json))
            .toList();

        movies = movies.where((m) => m.posterUrl.isNotEmpty).toList();

        for (var m in movies) {
          _injectGenres(m);
        }

        return movies;
      } else {
        print('Error searching movies: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception searching movies: $e');
      return [];
    }
  }

  /// Fetch a single movie by ID
  Future<Movie?> getMovieById(int movieId) async {
    await fetchGenres();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/$movieId?language=ru-RU&api_key=$_apiKey'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final movie = Movie.fromJson(data);
        _injectGenres(movie);
        return movie;
      } else {
        print('Error fetching movie $movieId: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception fetching movie $movieId: $e');
      return null;
    }
  }

  /// Fetch recommendations for a specific movie directly from TMDB
  Future<List<Movie>> getRecommendationsForMovie(
    int movieId, {
    int page = 1,
  }) async {
    await fetchGenres();

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/movie/$movieId/recommendations?language=ru-RU&page=$page&api_key=$_apiKey',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];

        List<Movie> movies = results
            .map((json) => Movie.fromJson(json))
            .toList();

        // Filter out movies without posters
        movies = movies.where((m) => m.posterUrl.isNotEmpty).toList();

        // Inject string genres
        for (var m in movies) {
          _injectGenres(m);
        }

        return movies;
      } else {
        print(
          'Error fetching TMDB recommendations for $movieId: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      print('Exception fetching TMDB recommendations: $e');
      return [];
    }
  }

  /// Generates a mathematical aggregation of recommendations from multiple seed movies.
  /// Fetches Top 100 uniquely scored movies to serve as the feed.
  Future<List<Movie>> getAggregatedRecommendations(
    List<Map<String, dynamic>> userSwipes, {
    List<int> ignoreIds = const [],
    int page = 1,
  }) async {
    await fetchGenres();

    if (userSwipes.isEmpty) return [];

    try {
      // 1. Sort semantic swipes by highest rating first, to find the "Top Seed Movies"
      var seedSwipes = List<Map<String, dynamic>>.from(userSwipes);
      seedSwipes.sort((a, b) {
        final ratingA =
            (a['rating'] as num?)?.toDouble() ??
            (a['action'] == 'like' ? 8.0 : 0.0);
        final ratingB =
            (b['rating'] as num?)?.toDouble() ??
            (b['action'] == 'like' ? 8.0 : 0.0);
        return ratingB.compareTo(ratingA); // Descending
      });

      // Take Top 20 best-rated movies as our seeds
      final topSeeds = seedSwipes.take(20).toList();

      // 2. Fetch parallel TMDB recommendations for each seed
      // For each seed movie, we want the `page` of its recommendations
      final futures = topSeeds.map((seed) {
        return getRecommendationsForMovie(seed['movie_id'] as int, page: page);
      });

      final resultLists = await Future.wait(futures);

      // 3. Mathematical Scoring Engine
      // Map<MovieId, Map<String, dynamic>> to track scores and movie objects
      Map<int, Map<String, dynamic>> scoredPool = {};

      for (int i = 0; i < topSeeds.length; i++) {
        final seed = topSeeds[i];
        final recommendedMovies = resultLists[i];

        final seedRating =
            (seed['rating'] as num?)?.toDouble() ??
            (seed['action'] == 'like' ? 8.0 : 1.0);
        // Normalize rating to a multiplier (e.g. 10.0 -> 1.0x, 5.0 -> 0.5x)
        final multiplier = seedRating / 10.0;

        for (var movie in recommendedMovies) {
          if (ignoreIds.contains(movie.id)) continue; // Already swiped

          if (scoredPool.containsKey(movie.id)) {
            // Increase score (additive weight logic)
            scoredPool[movie.id]!['score'] += (1.0 * multiplier);
          } else {
            // Initialize score
            scoredPool[movie.id] = {'movie': movie, 'score': 1.0 * multiplier};
          }
        }
      }

      // 4. Sort and Filter
      var sortedEntries = scoredPool.values.toList()
        ..sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double),
        );

      // Return Top 100 movies
      List<Movie> finalMovies = sortedEntries
          .take(100)
          .map((e) => e['movie'] as Movie)
          .toList();

      return finalMovies;
    } catch (e) {
      print('Exception in getAggregatedRecommendations: $e');
      return [];
    }
  }

  /// Discover movies globally filtering by TMDB genre IDs
  Future<List<Movie>> discoverMoviesByGenres(
    Set<int> genreIds, {
    bool requireAll = false,
    int page = 1,
  }) async {
    await fetchGenres();

    if (genreIds.isEmpty) return getPopularMovies(page: page);

    // TMDB uses comma (,) for OR logic, and pipe (|) for AND logic
    final String separator = requireAll ? ',' : '|';
    final String genresString = genreIds.join(separator);

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/discover/movie?language=ru-RU&with_genres=$genresString&page=$page&api_key=$_apiKey',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];

        List<Movie> movies = results
            .map((json) => Movie.fromJson(json))
            .toList();

        // Filter out movies without posters
        movies = movies.where((m) => m.posterUrl.isNotEmpty).toList();

        for (var m in movies) {
          _injectGenres(m);
        }

        return movies;
      } else {
        print('Error discovering movies by genre: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception discovering movies: $e');
      return [];
    }
  }
}
