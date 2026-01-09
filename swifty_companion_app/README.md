# swifty_companion_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

Résumé visuel du flux OAuth2 (API 42)
-   Ton app → envoie client_id + client_secret
-   Serveur OAuth 42 → renvoie access_token
-   Ton app → appelle /v2/users/{login} avec le token
-   API 42 → renvoie les données
