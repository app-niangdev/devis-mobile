/// Adresse de l'API, fixée à la compilation :
/// `flutter run s://api.exemple.sn/api`
/// (émulateur Android : http://10.0.2.2:8000/api).
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000/api',
);
