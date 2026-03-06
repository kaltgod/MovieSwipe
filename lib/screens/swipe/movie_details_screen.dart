import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/models/movie_model.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  String? _action;
  double? _userRating;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingStatus = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('swipes')
          .select()
          .eq('user_id', userId)
          .eq('movie_id', widget.movie.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _action = response['action'] as String?;
          _userRating = response['rating'] != null
              ? (response['rating'] as num).toDouble()
              : null;
          _isLoadingStatus = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingStatus = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _deleteSwipe() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('swipes')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', widget.movie.id);
      if (mounted) {
        setState(() {
          _action = null;
          _userRating = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Удалено из списка')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ошибка при удалении')));
      }
    }
  }

  Future<void> _showRatingDialog({bool isUpdating = false}) async {
    double tempRating = _userRating?.roundToDouble() ?? 5.0;

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                isUpdating ? 'Изменить оценку' : 'Оцените фильм',
                style: const TextStyle(color: AppTheme.primary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.movie.title,
                    style: const TextStyle(color: AppTheme.secondary),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempRating,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: tempRating.toStringAsFixed(0),
                    activeColor: AppTheme.accentYellow,
                    onChanged: (val) {
                      setDialogState(() => tempRating = val);
                    },
                  ),
                  Text(
                    'Оценка: ${tempRating.toInt()} / 10',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: AppTheme.secondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, tempRating),
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      try {
        await Supabase.instance.client
            .from('swipes')
            .update({'action': 'watched', 'rating': result})
            .match({'user_id': userId, 'movie_id': widget.movie.id});
        if (mounted) {
          setState(() {
            _action = 'watched';
            _userRating = result;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Оценка сохранена')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Ошибка сохранения')));
        }
      }
    }
  }

  Future<void> _addToWatchlist() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('swipes').upsert({
        'user_id': userId,
        'movie_id': widget.movie.id,
        'action': 'like',
        'rating': null,
      });
      if (mounted) {
        setState(() => _action = 'like');
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

  Widget _buildActionButtons() {
    if (_isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_action == null) {
      return _buildButton(
        '+ Запланировать',
        AppTheme.accentYellow,
        () => _addToWatchlist(),
      );
    }

    if (_action == 'like') {
      return Column(
        children: [
          _buildButton(
            'Посмотрел',
            AppTheme.primary,
            () => _showRatingDialog(),
          ),
          const SizedBox(height: 12),
          _buildButton(
            'Удалить из запланированного',
            Colors.redAccent,
            () => _deleteSwipe(),
            isOutlined: true,
          ),
        ],
      );
    } else if (_action == 'watched') {
      return Column(
        children: [
          _buildButton(
            'Изменить оценку (${_userRating?.toStringAsFixed(1) ?? "-"})',
            AppTheme.accentYellow,
            () => _showRatingDialog(isUpdating: true),
          ),
          const SizedBox(height: 12),
          _buildButton(
            'Удалить оценку',
            Colors.redAccent,
            () => _deleteSwipe(),
            isOutlined: true,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildButton(
    String text,
    Color color,
    VoidCallback onTap, {
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
          border: isOutlined
              ? Border.all(color: color.withOpacity(0.5))
              : Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.background,
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop image
                  if (widget.movie.backdropUrl.isNotEmpty)
                    Image.network(
                      widget.movie.backdropUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: AppTheme.surface),
                    )
                  else if (widget.movie.posterUrl.isNotEmpty)
                    Image.network(
                      widget.movie.posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: AppTheme.surface),
                    )
                  else
                    Container(color: AppTheme.surface),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.background.withOpacity(0.5),
                          AppTheme.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.clear,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.movie.title,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meta info row
                  Row(
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentYellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentYellow.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.star_fill,
                              color: AppTheme.accentYellow,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.movie.rating.toStringAsFixed(2),
                              style: const TextStyle(
                                color: AppTheme.accentYellow,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Release Date
                      if (widget.movie.releaseDate.isNotEmpty)
                        Text(
                          widget.movie.releaseDate.split(
                            '-',
                          )[0], // Just the year
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Genres
                  if (widget.movie.genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.movie.genres.map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  const Text(
                    'Сюжет',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    widget.movie.overview.isNotEmpty
                        ? widget.movie.overview
                        : 'Описание отсутствует.',
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 32), // Padding before actions
                  // Action buttons
                  _buildActionButtons(),

                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
