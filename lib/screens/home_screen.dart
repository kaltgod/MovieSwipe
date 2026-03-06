import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:movieswipe/theme/app_theme.dart';
import 'package:movieswipe/screens/swipe/swipe_screen.dart';
import 'package:movieswipe/screens/search/search_screen.dart';
import 'package:movieswipe/screens/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _screens = [
      const SwipeScreen(),
      const SearchScreen(),
      ProfileScreen(key: _profileKey),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primary : AppTheme.secondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        if (index == 2) {
          _profileKey.currentState?.fetchProfileData();
        }
      },
      child: SizedBox(
        height: 60,
        width: 80,
        child: Center(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(begin: AppTheme.secondary, end: color),
            duration: const Duration(milliseconds: 300),
            builder: (context, animatedColor, child) {
              return Icon(
                isSelected ? activeIcon : icon,
                color: animatedColor,
                size: 28,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: AppTheme.surface, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, CupertinoIcons.film, CupertinoIcons.film_fill),
            _buildNavItem(1, CupertinoIcons.search, CupertinoIcons.search),
            _buildNavItem(2, CupertinoIcons.person, CupertinoIcons.person_fill),
          ],
        ),
      ),
    );
  }
}
