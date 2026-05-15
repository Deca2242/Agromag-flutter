/// Constantes con los paths y nombres de las rutas.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String home = '/home';

  /// Segmento bajo `/home` (ruta completa: `/home/weather`).
  static const String homeWeatherSegment = 'weather';
  static const String crops = '/crops';
  static const String cropsNew = '/crops/new';
  static const String cropsDetail = '/crops/:id';
  static const String cropsEdit = '/crops/:id/edit';
  static const String alerts = '/alerts';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';
  static const String assistant = '/assistant';

  static const String homeName = 'home';
  static const String homeWeatherName = 'home-weather';
  static const String cropsName = 'crops';
  static const String cropsNewName = 'crops-new';
  static const String cropsDetailName = 'crops-detail';
  static const String cropsEditName = 'crops-edit';
  static const String alertsName = 'alerts';
  static const String profileName = 'profile';
  static const String profileEditName = 'profile-edit';
  static const String assistantName = 'assistant';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String forgotName = 'forgot-password';
  static const String splashName = 'splash';
}
