MovieSwipe — Technical Specification (MVP)
Summary: A private, cross-platform mobile application built for a close circle of friends. It helps users discover movies based on their mood, maintain watchlists, rate films, and find common movies to watch together through a synchronous swipe-matching mechanic.

1. Platform and Tech Stack
Framework: Flutter (Dart). Chosen for premium UI capabilities and smooth animations.

Backend & Database: Supabase (Authentication, PostgreSQL database for users, lists, and relations).

Movie Data API: TMDB (The Movie Database) API — free source for posters, trailers, genres, cast, and descriptions.

AI Search: Gemini API (free tier) for natural language processing of mood-based search queries.

Dynamic UI Colors: palette_generator package for Flutter to extract dominant colors from posters.

Network Requirement: Online only (no offline mode required).

2. Authentication and Onboarding
Welcome Screen: Visually appealing screen with the app logo and welcoming text.

Auth Methods: Email/Password, Google Sign-In, Apple Sign-In.

Registration Flow: New users must create a unique username upon registration.

3. UI / UX — Navigation Structure
Premium dark minimalist design (Apple-style), deep black background, no visual clutter, liquid glass effects.
The app relies on a 3-tab bottom navigation bar.

Tab 1: Main (Swipe)

Full-screen movie poster view.

Matching Lobby Icon (top right).

Three quick-action buttons below the poster: ❌, ⭐️, ❤️.

Tab 2: Search (AI & Genres)

Large text input for AI mood search (e.g., "atmospheric thriller for a snowy evening").

Quick-filter chips for basic genres (Comedy, Horror, Thriller, etc.) directly below the search bar.

Results displayed as a grid or carousel of movie cards.

Tab 3: Profile

Header: Avatar, Username.

Spotify-style Stats: Infographics showing most watched genres, total watch count.

"Plan to Watch": Large carousel of saved movies.

"My Ratings": Grid of watched movies with user's numerical rating overlay.

4. Core Swipe Mechanics & Gestures
Every action is accompanied by Haptic Touch (vibration) for premium tactile feedback.

Swipe Right (or ❤️ button): Add movie to the "Plan to Watch" list.

Swipe Left (or ❌ button): Skip / Not interested.

Swipe Down (or ⭐️ button): Mark as "Watched". Triggers a bottom sheet with a 1-to-10 rating slider and an optional text field for a short review.

Swipe Up: Open Movie Details.

Animation: The poster smoothly dissolves.

Content: Auto-playing trailer (muted by default), followed by plot description and cast list.

5. Friend System & Social Features
Profiles: Users can open a friend's profile to view their stats, read their short reviews, and view their "Plan to Watch" list (with the ability to quickly copy a movie to their own list).

Matching Flow (Shared Viewing):

User taps the Match icon on the Main screen.

Opens the friend list. User selects one or multiple friends and taps "Invite".

Host sees a Lobby screen with invitees and their status (Waiting, Ready, Declined).

Invitees receive a push notification or an in-app popup.

Upon acceptance, invitee status changes to "Ready".

Host presses "Start selection".

Synchronous swiping session begins until users swipe right on the same movie ("Match").

6. Visual Style & Theming
Theme: Dark mode only. Deep blacks and dark greys.

Dynamic Accent Colors: The UI is reactive. Action buttons (❌, ⭐️, ❤️), rating sliders, and active bottom navigation icons dynamically change their color to match the dominant color extracted from the currently displayed movie poster.

7. Localization
Default: App language automatically follows the device's system language settings.

Manual Override: A setting in the profile allows manual selection between:

Russian

English

Chinese