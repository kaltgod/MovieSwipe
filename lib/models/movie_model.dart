class Movie {
  final int id;
  final String title;
  final String posterUrl;
  final String backdropUrl;
  final String overview;
  final String releaseDate;
  final List<int> genreIds;
  List<String> genres;
  final double rating;
  final int runtime;

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.backdropUrl,
    required this.overview,
    required this.releaseDate,
    required this.genreIds,
    this.genres = const [],
    required this.rating,
    this.runtime = 0,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    const imageBaseUrl = 'https://image.tmdb.org/t/p/w780';
    final posterPath = json['poster_path'] as String?;
    final backdropPath = json['backdrop_path'] as String?;

    List<int> parsedGenreIds = [];
    if (json['genre_ids'] != null) {
      parsedGenreIds = List<int>.from(json['genre_ids']);
    } else if (json['genres'] != null) {
      parsedGenreIds = (json['genres'] as List)
          .map((g) => g['id'] as int)
          .toList();
    }

    return Movie(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      posterUrl: posterPath != null ? '$imageBaseUrl$posterPath' : '',
      backdropUrl: backdropPath != null ? '$imageBaseUrl$backdropPath' : '',
      overview:
          json['overview'] as String? ?? json['description'] as String? ?? '',
      releaseDate:
          json['release_date'] as String? ??
          json['first_air_date'] as String? ??
          '',
      genreIds: parsedGenreIds,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      runtime: json['runtime'] as int? ?? 0,
    );
  }

  // Mock data for UI building
  static List<Movie> mockMovies = [
    Movie(
      id: 3,
      title: 'Blade Runner 2049',
      posterUrl:
          'https://image.tmdb.org/t/p/w780/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg',
      backdropUrl: '',
      overview:
          'Young Blade Runner K\'s discovery of a long-buried secret leads him to track down former Blade Runner Rick Deckard, who\'s been missing for thirty years.',
      releaseDate: '2017-10-04',
      genreIds: [878, 53],
      genres: ['Sci-Fi', 'Thriller'],
      rating: 8.0,
      runtime: 164,
    ),
    Movie(
      id: 4,
      title: 'Inception',
      posterUrl:
          'https://image.tmdb.org/t/p/w780/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg',
      backdropUrl: '',
      overview:
          'A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.',
      releaseDate: '2010-07-15',
      genreIds: [28, 878, 53],
      genres: ['Action', 'Sci-Fi', 'Thriller'],
      rating: 8.8,
      runtime: 148,
    ),
    Movie(
      id: 5,
      title: 'Joker',
      posterUrl:
          'https://image.tmdb.org/t/p/w780/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg',
      backdropUrl: '',
      overview:
          'During the 1980s, a failed stand-up comedian is driven insane and turns to a life of crime and chaos in Gotham City while becoming an infamous psychopathic crime figure.',
      releaseDate: '2019-10-02',
      genreIds: [80, 53, 18],
      genres: ['Crime', 'Thriller', 'Drama'],
      rating: 8.4,
      runtime: 122,
    ),
    Movie(
      id: 6,
      title: 'The Dark Knight',
      posterUrl:
          'https://image.tmdb.org/t/p/w780/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
      backdropUrl: '',
      overview:
          'When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.',
      releaseDate: '2008-07-16',
      genreIds: [28, 80, 18],
      genres: ['Action', 'Crime', 'Drama'],
      rating: 9.0,
    ),
    Movie(
      id: 8,
      title: 'The Matrix',
      posterUrl:
          'https://image.tmdb.org/t/p/w780/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
      backdropUrl: '',
      overview:
          'A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.',
      releaseDate: '1999-03-30',
      genreIds: [28, 878],
      genres: ['Action', 'Sci-Fi'],
      rating: 8.7,
    ),
  ];
}
