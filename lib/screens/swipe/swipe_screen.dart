import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/models/movie_model.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/widgets/movie_card.dart';
import 'package:movieswipe/screens/swipe/movie_details_screen.dart';
import 'package:movieswipe/services/tmdb_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Movie> _movies = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  int _currentPage = 1;

  final _tmdbService = TmdbService();
  final _supabase = Supabase.instance.client;

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;

  // Track past drag offsets to know where cards went so we can bring them back
  final List<Offset> _pastOffsets = [];

  // Track primary drag axis to lock movement
  Axis? _dragAxis;

  late AnimationController _animationController;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.addListener(() {
      setState(() {
        _dragOffset = _animation.value;
        // Only set angle if we are animating a horizontal wipe.
        // If it was vertical, keep it 0.
        if (_dragOffset.dx.abs() > 0) {
          _dragAngle = _dragOffset.dx / 20;
        } else {
          _dragAngle = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMovies({bool loadMore = false, bool skipAi = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final user = _supabase.auth.currentUser;
    List<int> swipedIds = [];
    List<Movie> newMovies = [];

    if (user != null) {
      try {
        // 1. Get ALL swiped IDs to filter out seen movies and build AI context
        final allSwipesData = await _supabase
            .from('swipes')
            .select('movie_id, rating, action')
            .eq('user_id', user.id);

        swipedIds = (allSwipesData as List)
            .map((e) => e['movie_id'] as int)
            .toList();

        // 2. Resolve ONLY rated or watched movies for TMDB Aggregation context
        List<Map<String, dynamic>> ratedSwipes = [];
        if (allSwipesData.isNotEmpty) {
          ratedSwipes = (allSwipesData as List)
              .where(
                (e) =>
                    e['rating'] != null ||
                    e['action'] == 'like' ||
                    e['action'] == 'watched',
              )
              .cast<Map<String, dynamic>>()
              .toList();
        }

        // 3. Mathematical TMDB Recommendations Engine
        if (ratedSwipes.isNotEmpty && !skipAi) {
          print('Requesting TMDB Native Aggregation (Page $_currentPage)...');
          try {
            final aggregatedMovies = await _tmdbService
                .getAggregatedRecommendations(
                  ratedSwipes,
                  ignoreIds: swipedIds,
                  page: _currentPage,
                );
            newMovies.addAll(aggregatedMovies);
          } catch (e) {
            print('Error in aggregation engine: $e');
          }
        }
      } catch (e) {
        print('Error fetching swipes: $e');
      }
    }

    // 4. Fallback to Popular TMDB if user is new or aggregation yielded no results
    if (newMovies.isEmpty) {
      print('Falling back to TMDB popular movies (Page $_currentPage)...');
      if (loadMore) {
        _currentPage++;
        if (_currentPage > 30) {
          _currentPage = Random().nextInt(20) + 1;
        }
      } else {
        _currentPage = Random().nextInt(20) + 1;
      }
      newMovies = await _tmdbService.getPopularMovies(page: _currentPage);
    }

    // 5. Filter and Shuffle
    newMovies.removeWhere((movie) => swipedIds.contains(movie.id));
    // Also remove items already currently in the deck
    newMovies.removeWhere((movie) => _movies.any((m) => m.id == movie.id));
    newMovies.shuffle(Random());

    if (newMovies.isEmpty) {
      // If we filtered out all movies on this page/AI batch, recursively load next batch from TMDB
      _loadMovies(loadMore: loadMore, skipAi: true);
      return;
    }

    if (mounted) {
      setState(() {
        if (loadMore) {
          _movies.addAll(newMovies);
        } else {
          _movies = newMovies;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSwipe(Movie movie, String action, {double? rating}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    print('CURRENT_USER_ID: ${user.id}');

    try {
      await _supabase.from('swipes').upsert({
        'user_id': user.id,
        'movie_id': movie.id,
        'action': action,
        'rating': rating,
      }, onConflict: 'user_id, movie_id');

      // Run cleanup asynchronously
      if (action == 'dislike') {
        _cleanupOldSkips(user.id);
      }
    } catch (e) {
      print('Error saving swipe: $e');
    }
  }

  Future<void> _cleanupOldSkips(String userId) async {
    try {
      final skipData = await _supabase
          .from('swipes')
          .select('id')
          .eq('user_id', userId)
          .eq('action', 'dislike')
          .order('created_at', ascending: false);

      final skips = skipData as List;
      if (skips.length > 500) {
        final idsToDelete = skips.skip(500).map((e) => e['id'] as int).toList();
        print(
          'Cleaning up ${idsToDelete.length} old skips for second chance...',
        );
        await _supabase.from('swipes').delete().inFilter('id', idsToDelete);
      }
    } catch (e) {
      print('Error cleaning up skips: $e');
    }
  }

  void _onPanStart(DragStartDetails details) {
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_dragAxis == null) {
        // Determine primary axis on first significant movement
        if (details.delta.dx.abs() > details.delta.dy.abs()) {
          _dragAxis = Axis.horizontal;
        } else {
          _dragAxis = Axis.vertical;
        }
      }

      if (_dragAxis == Axis.horizontal) {
        _dragOffset += Offset(details.delta.dx, 0);
        _dragAngle = _dragOffset.dx / 20; // Rotate on horizontal drag
      } else {
        _dragOffset += Offset(0, details.delta.dy);
        _dragAngle = 0; // Don't rotate on vertical drag
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Check if swiped far enough left or right
    if (_dragOffset.dx > screenWidth * 0.4) {
      _animateOut(const Offset(500, 0), 'like'); // Swiped Right
    } else if (_dragOffset.dx < -screenWidth * 0.4) {
      _animateOut(const Offset(-500, 0), 'dislike'); // Swiped Left
    } else if (_dragOffset.dy > 150) {
      _animateOut(const Offset(0, 500), 'watched'); // Swiped Down
    } else if (_dragOffset.dy < -150) {
      _openDetails(); // Swiped Up
    } else {
      _animateBack(); // Didn't swipe far enough, snap back
    }
  }

  void _animateOut(Offset targetOffset, String action) {
    if (_currentIndex >= _movies.length) return;

    final swipedMovie = _movies[_currentIndex];

    _animation = Tween<Offset>(begin: _dragOffset, end: targetOffset).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0).then((_) {
      if (action == 'watched') {
        _showRatingDialog(swipedMovie, targetOffset);
      } else {
        _finalizeSwipe(swipedMovie, action, targetOffset, null);
      }
    });
  }

  void _finalizeSwipe(
    Movie movie,
    String action,
    Offset targetOffset,
    double? rating,
  ) {
    _saveSwipe(movie, action, rating: rating);

    setState(() {
      _pastOffsets.add(targetOffset); // Remember where this card went
      _currentIndex++;
      _dragOffset = Offset.zero;
      _dragAngle = 0;
      _dragAxis = null;

      // Trigger pagination if getting close to the end
      if (_currentIndex >= _movies.length - 10) {
        _loadMovies(loadMore: true);
      }
    });
  }

  void _showRatingDialog(Movie movie, Offset targetOffset) {
    double selectedRating = 5.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text(
                'Оцените фильм',
                style: TextStyle(color: AppTheme.primary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title,
                    style: const TextStyle(color: AppTheme.secondary),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: selectedRating,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: selectedRating.toStringAsFixed(0),
                    activeColor: AppTheme.accentYellow,
                    onChanged: (val) {
                      setDialogState(() => selectedRating = val);
                    },
                  ),
                  Text(
                    'Оценка: ${selectedRating.toInt()} / 10',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _finalizeSwipe(
                      movie,
                      'watched',
                      targetOffset,
                      selectedRating,
                    );
                  },
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(color: AppTheme.accentYellow),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDetails() {
    if (_currentIndex >= _movies.length) return;
    final swipedMovie = _movies[_currentIndex];

    // Snap back to center while opening
    _animateBack();

    // Navigate with fade transition
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MovieDetailsScreen(movie: swipedMovie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _animateBack() {
    _animation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragAngle = 0;
          _dragAxis = null;
        });
      }
    });
  }

  void _handleAction(String type) {
    if (_currentIndex >= _movies.length) return;

    setState(() {
      if (type == 'like') {
        _dragAxis = Axis.horizontal;
        _animateOut(const Offset(500, 0), 'like');
      } else if (type == 'nope') {
        _dragAxis = Axis.horizontal;
        _animateOut(const Offset(-500, 0), 'dislike');
      } else if (type == 'watched') {
        _dragAxis = Axis.vertical;
        _animateOut(const Offset(0, 500), 'watched');
      }
    });
  }

  void _undoSwipe() {
    if (_currentIndex > 0 && _pastOffsets.isNotEmpty) {
      // Find where the last card went
      final lastOffset = _pastOffsets.removeLast();

      setState(() {
        _currentIndex--;
        // Instantly place the card off-screen where it ended up
        _dragOffset = lastOffset;
        _dragAngle = lastOffset.dx / 20;
      });

      // Animate it back to the center
      _animateBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Empty State
            if (_currentIndex >= _movies.length)
              const Center(
                child: Text(
                  'No more movies :(\nCome back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondary, fontSize: 18),
                ),
              ),

            // Back card (Next movie)
            if (_currentIndex < _movies.length - 1)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: MovieCard(movie: _movies[_currentIndex + 1]),
              ),

            // Front card (Current movie)
            if (_currentIndex < _movies.length)
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: _dragOffset,
                  child: Transform.rotate(
                    angle: _dragAngle * pi / 180,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MovieCard(movie: _movies[_currentIndex]),
                    ),
                  ),
                ),
              ),

            // Overlays
            if (_currentIndex < _movies.length) ...[
              // Action Buttons
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: CupertinoIcons.xmark,
                      color: AppTheme.accentRed,
                      size: 56,
                      onTap: () => _handleAction('nope'),
                    ),
                    _ActionButton(
                      icon: CupertinoIcons.star_fill,
                      color: AppTheme.accentYellow,
                      size: 56,
                      onTap: () => _handleAction('watched'),
                    ),
                    _ActionButton(
                      icon: CupertinoIcons.checkmark_alt,
                      color: AppTheme.accentGreen,
                      size: 56,
                      onTap: () => _handleAction('like'),
                    ),
                  ],
                ),
              ),

              // Match with friends button
              Positioned(
                top: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    // Open Matching Lobby
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      CupertinoIcons.group_solid,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Undo button (Top Left)
              if (_currentIndex > 0)
                Positioned(
                  top: 24,
                  left: 24,
                  child: GestureDetector(
                    onTap: _undoSwipe,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.undo_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.size = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
