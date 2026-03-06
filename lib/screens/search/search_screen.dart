import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/screens/search/ai_search_results_screen.dart';
import 'package:movieswipe/screens/search/genre_search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Official TMDB Movie Genres
  final Map<int, String> _tmdbGenres = {
    28: 'Боевик',
    12: 'Приключения',
    16: 'Мультфильм',
    35: 'Комедия',
    80: 'Криминал',
    99: 'Документальный',
    18: 'Драма',
    10751: 'Семейный',
    14: 'Фэнтези',
    36: 'История',
    27: 'Ужасы',
    10402: 'Музыка',
    9648: 'Детектив',
    10749: 'Мелодрама',
    878: 'Фантастика',
    10770: 'ТВ фильм',
    53: 'Триллер',
    10752: 'Военный',
    37: 'Вестерн',
  };

  // Selected genre IDs
  final Set<int> _selectedGenreIds = {};

  // true = 'AND' (all must match), false = 'OR' (any can match)
  bool _requireAllGenres = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: null, // Removed title as requested
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Spacer to push content slightly above center
              const Spacer(flex: 3),

              // Title / AI Prompt Text
              const Text(
                'Что будем искать?',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Modern AI Search Bar
              TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.primary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'ИИ поиск: "мрачный триллер на вечер"...',
                  hintStyle: const TextStyle(color: AppTheme.secondary),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: AppTheme.secondary,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      CupertinoIcons.sparkles,
                      color: AppTheme.accentYellow,
                    ),
                    onPressed: () {
                      _triggerAiSearch(context);
                    },
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // Slightly rounded corners
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, // Reduced height
                    horizontal: 20,
                  ),
                ),
                onSubmitted: (value) {
                  _triggerAiSearch(context);
                },
              ),

              const SizedBox(height: 24),

              // Search by Genre Button
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedGenreIds.clear();
                    _requireAllGenres =
                        false; // optionally reset the AND/OR switch too
                  });
                  _showGenresBottomSheet(context);
                },
                icon: const Icon(
                  CupertinoIcons.tags_solid,
                  color: AppTheme.background,
                ),
                label: const Text(
                  'Поиск по жанрам',
                  style: TextStyle(
                    color: AppTheme.background,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ), // Reduced height
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // Slightly rounded corners
                  ),
                ),
              ),

              const Spacer(flex: 4), // Push everything slightly up
            ],
          ),
        ),
      ),
    );
  }

  void _triggerAiSearch(BuildContext context) {
    if (_searchController.text.trim().isEmpty) return;

    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AiSearchResultsScreen(query: _searchController.text.trim()),
      ),
    );
  }

  void _showGenresBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 24),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Жанры',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedGenreIds.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  _selectedGenreIds.clear();
                                });
                                setState(() {});
                              },
                              child: const Text(
                                'Сбросить',
                                style: TextStyle(color: AppTheme.accentRed),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // AND/OR Switcher
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(
                                  () => _requireAllGenres = false,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_requireAllGenres
                                        ? AppTheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Любой из (ИЛИ)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_requireAllGenres
                                          ? AppTheme.primary
                                          : AppTheme.secondary,
                                      fontWeight: !_requireAllGenres
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(
                                  () => _requireAllGenres = true,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _requireAllGenres
                                        ? AppTheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Строго все (И)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _requireAllGenres
                                          ? AppTheme.primary
                                          : AppTheme.secondary,
                                      fontWeight: _requireAllGenres
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Genres Cloud
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Wrap(
                          spacing: 12.0,
                          runSpacing: 16.0,
                          children: _tmdbGenres.entries.map((entry) {
                            final genreId = entry.key;
                            final genreName = entry.value;
                            final isSelected = _selectedGenreIds.contains(
                              genreId,
                            );

                            return ChoiceChip(
                              label: Text(genreName),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    _selectedGenreIds.add(genreId);
                                  } else {
                                    _selectedGenreIds.remove(genreId);
                                  }
                                });
                                setState(
                                  () {},
                                ); // Update underlying screen state too
                              },
                              selectedColor: AppTheme.primary,
                              backgroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppTheme.background
                                    : AppTheme.primary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.background,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Search Button inside bottom sheet
                    Padding(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                        bottom: MediaQuery.of(context).padding.bottom + 24,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close sheet

                            // Build friendly title from selected genres
                            String title = 'Популярные фильмы';
                            if (_selectedGenreIds.isNotEmpty) {
                              final names = _selectedGenreIds.map((id) {
                                return _tmdbGenres[id] ?? 'Неизвестно';
                              }).toList();

                              // Capitalize first letters for better UI
                              for (int i = 0; i < names.length; i++) {
                                if (names[i].isNotEmpty &&
                                    names[i] != 'Неизвестно') {
                                  names[i] =
                                      names[i][0].toUpperCase() +
                                      names[i].substring(1);
                                }
                              }

                              title = names.join(', ');
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GenreSearchResultsScreen(
                                  genreIds: _selectedGenreIds,
                                  requireAll: _requireAllGenres,
                                  genreNamesTitle: title,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedGenreIds.isEmpty
                                ? 'Показать все фильмы'
                                : 'Показать фильмы (${_selectedGenreIds.length})',
                            style: const TextStyle(
                              color: AppTheme.background,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
