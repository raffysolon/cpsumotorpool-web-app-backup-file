# cpsumotorpooladmin

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Run against a local Laravel API

The API base URL can be overridden at build time with `API_BASE_URL`. Run the
Flutter Web app against a local Laravel server with:

```shell
flutter run -d chrome --web-hostname localhost --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Keep the `/api` suffix in the URL. Without this define, the app uses the
deployed Render API URL. Authentication tokens are stored separately for each
API base URL, so a local login is not reused for the deployed backend.
