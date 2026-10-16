# How to build for android

create a file .env with the following content:

```
{
    "OPENAI_API_KEY":"<your_openai_api_key>"
}
```
flutter pub get

flutter build apk --release --dart-define-from-file=.env

