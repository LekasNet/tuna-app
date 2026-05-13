import 'package:flutter/widgets.dart';

import '../../di/settings/settings_service.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('ru')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static Locale? localeFor(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return null;
      case AppLanguage.ru:
        return const Locale('ru');
      case AppLanguage.en:
        return const Locale('en');
    }
  }

  static AppLanguage languageFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ru':
        return AppLanguage.ru;
      case 'en':
        return AppLanguage.en;
      default:
        return AppLanguage.en;
    }
  }

  String get _code => locale.languageCode == 'ru' ? 'ru' : 'en';

  String t(String key) {
    return _values[_code]?[key] ?? _values['en']?[key] ?? key;
  }

  String format(String key, Map<String, Object?> values) {
    var result = t(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  String languageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return t('language.system');
      case AppLanguage.ru:
        return t('language.ru');
      case AppLanguage.en:
        return t('language.en');
    }
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _values = <String, Map<String, String>>{
  'ru': {
    'app.title': 'tuna_unofficial_client',
    'language.system': 'Системный',
    'language.ru': 'Русский',
    'language.en': 'English',
    'nav.dashboard': 'Обзор',
    'nav.tunnels': 'Туннели',
    'nav.docker': 'Docker',
    'nav.remote': 'Удалённые',
    'nav.settings': 'Настройки',
    'nav.console': 'Консоль',
    'notifications.title': 'Уведомления',
    'notifications.empty': 'Нет уведомлений',
    'notifications.actionFailed': 'Не удалось выполнить действие уведомления',
    'notifications.site': 'На сайт',
    'notifications.update': 'Обновить',
    'notifications.subscriptionDateMissing': 'Дата не указана',
    'notifications.subscriptionUntil': 'Подписка до {date}',
    'settings.theme': 'Тема',
    'settings.language': 'Язык',
    'settings.system': 'Системная',
    'settings.light': 'Светлая',
    'settings.dark': 'Тёмная',
    'settings.authorization': 'Авторизация',
    'settings.token': 'Токен',
    'settings.tokenMissing': 'Токен не задан',
    'settings.tokenSaved': 'Токен сохранён',
    'settings.tokenSavedCheckFailed':
        'Токен сохранён, но проверить его не удалось',
    'settings.editToken': 'Редактировать токен',
    'settings.pasteToken': 'Вставь токен',
    'settings.tokenHelp': 'Где взять токен: https://my.tuna.am/token',
    'settings.apiKeySaved': 'API key сохранён',
    'settings.apiKeyMissing': 'API key не задан',
    'settings.editApiKey': 'Редактировать API key',
    'settings.pasteApiKey': 'Вставь API key',
    'settings.apiKeyHelp':
        'Управление API ключами: https://my.tuna.am/api_keys',
    'settings.tunaPath': 'Путь до tuna',
    'settings.editPath': 'Редактировать путь',
    'settings.pathToTuna': 'Путь к tuna',
    'settings.pathMissing': 'Путь не задан, используется поиск в PATH',
    'settings.pathHintWindows':
        'Пример: C:\\\\Users\\\\<имя>\\\\AppData\\\\Local\\\\Microsoft\\\\WinGet\\\\Packages\\\\...\\\\tuna.exe\nМожно найти через команду "where tuna" или "where tuna.exe" в PowerShell.',
    'settings.pathHintMac':
        'Пример: /opt/homebrew/bin/tuna или /usr/local/bin/tuna\nМожно найти через команду "which tuna" в терминале.',
    'settings.pathHintLinux':
        'Пример: /usr/local/bin/tuna или /usr/bin/tuna\nМожно найти через команду "which tuna" в терминале.',
    'settings.account': 'Аккаунт',
    'settings.user': 'Пользователь: {name}',
    'settings.subscriptionUntil': 'Подписка до: {date}',
    'settings.save': 'Сохранить',
    'settings.cancel': 'Отмена',
    'settings.paste': 'Вставить',
    'settings.clear': 'Очистить',
    'settings.disclaimerPrefix':
        'tuna_unofficial_client — независимый клиент для работы с tuna. Он не является официальным приложением tuna и не поддерживается командой сервиса. За актуальной информацией, документацией и официальными инструментами обращайтесь на ',
    'settings.disclaimerLink': 'официальный сайт tuna',
    'settings.disclaimerSuffix': '.',
    'settings.officialSite': 'https://tuna.am',
    'common.cancel': 'Отмена',
    'common.save': 'Сохранить',
    'common.stop': 'Остановить',
    'common.start': 'Запустить',
    'common.delete': 'Удалить',
    'common.refresh': 'Обновить',
    'common.openUrl': 'Открыть URL',
    'common.clear': 'Очистить',
    'common.copyAddress': 'Адрес скопирован',
    'dashboard.title': 'Обзор',
    'dashboard.latestStarts': '2 последних запуска',
    'dashboard.noStarts': 'Запуски пока не зафиксированы.',
    'dashboard.failures': 'Сбои',
    'dashboard.all': 'Все',
    'dashboard.active': 'Активные',
    'dashboard.stable': 'Стабильные',
    'dashboard.localRemote': 'Локальные/удалённые',
    'dashboard.failedStart': 'Не удалось запустить туннель',
    'dashboard.failedOpenUrl': 'Не удалось открыть URL',
    'tunnels.title': 'Туннели',
    'tunnels.add': 'Добавить туннель',
    'tunnels.new': 'Новый туннель',
    'tunnels.empty': 'Туннелей пока нет',
    'tunnels.saved': 'Туннель сохранён',
    'tunnels.noLogs': 'Логи отсутствуют',
    'tunnels.logsSaved': 'Логи сохранены в файл:\n{path}',
    'tunnels.checkForm': 'Проверь данные формы',
    'tunnels.copyUrl': 'Скопировать URL',
    'tunnels.copyWebUi': 'Скопировать Web UI',
    'tunnels.backToList': 'К списку',
    'tunnels.webInterface': 'Web интерфейс',
    'tunnels.exportLogs': 'Экспорт логов',
    'tunnels.edit': 'Редактировать',
    'tunnels.log': 'Лог',
    'tunnels.clearVisibleLog': 'Очистить видимый лог',
    'tunnelForm.name': 'Название',
    'tunnelForm.nameHint': 'Например, Local API',
    'tunnelForm.localPort': 'Локальный порт',
    'tunnelForm.localPortHint': 'Например, 8080',
    'tunnelForm.localIp': 'Локальный IP (опционально)',
    'tunnelForm.localIpHint': 'Например, 127.0.0.1',
    'tunnelForm.type': 'Тип тоннеля',
    'tunnelForm.subdomain': 'Subdomain (опционально)',
    'tunnelForm.subdomainHint': 'Например, myapp',
    'docker.title': 'Docker',
    'docker.stopTitle': 'Остановить туннель в контейнере',
    'docker.cancel': 'Отмена',
    'docker.stop': 'Остановить',
    'docker.refreshList': 'Обновить список',
    'docker.notRunning': 'Docker Engine не запущен.',
    'docker.empty': 'Контейнеры не найдены',
    'docker.back': 'Назад к контейнерам',
    'docker.refreshContainer': 'Обновить контейнер',
    'docker.containerLog': 'Лог контейнера',
    'docker.stopTunnel': 'Остановить туннель',
    'remote.title': 'Удалённые туннели',
    'remote.empty': 'Активных удалённых туннелей не найдено.',
    'remote.stopTitle': 'Остановить удалённый туннель',
    'remote.noId': 'Нельзя остановить туннель без ID.',
    'remote.forceStop': 'Принудительно остановить',
    'remote.stopped': 'Удалённый туннель остановлен.',
    'remote.stopFailed': 'Не удалось остановить удалённый туннель.',
    'console.title': 'Консоль',
  },
  'en': {
    'app.title': 'tuna_unofficial_client',
    'language.system': 'System',
    'language.ru': 'Русский',
    'language.en': 'English',
    'nav.dashboard': 'Dashboard',
    'nav.tunnels': 'Tunnels',
    'nav.docker': 'Docker',
    'nav.remote': 'Remote',
    'nav.settings': 'Settings',
    'nav.console': 'Console',
    'notifications.title': 'Notifications',
    'notifications.empty': 'No notifications',
    'notifications.actionFailed': 'Could not run notification action',
    'notifications.site': 'Website',
    'notifications.update': 'Update',
    'notifications.subscriptionDateMissing': 'Date not set',
    'notifications.subscriptionUntil': 'Subscription until {date}',
    'settings.theme': 'Theme',
    'settings.language': 'Language',
    'settings.system': 'System',
    'settings.light': 'Light',
    'settings.dark': 'Dark',
    'settings.authorization': 'Authorization',
    'settings.token': 'Token',
    'settings.tokenMissing': 'Token is not set',
    'settings.tokenSaved': 'Token saved',
    'settings.tokenSavedCheckFailed': 'Token saved, but verification failed',
    'settings.editToken': 'Edit token',
    'settings.pasteToken': 'Paste token',
    'settings.tokenHelp': 'Get token: https://my.tuna.am/token',
    'settings.apiKeySaved': 'API key saved',
    'settings.apiKeyMissing': 'API key is not set',
    'settings.editApiKey': 'Edit API key',
    'settings.pasteApiKey': 'Paste API key',
    'settings.apiKeyHelp': 'Manage API keys: https://my.tuna.am/api_keys',
    'settings.tunaPath': 'Path to tuna',
    'settings.editPath': 'Edit path',
    'settings.pathToTuna': 'Path to tuna',
    'settings.pathMissing': 'Path is not set, PATH lookup is used',
    'settings.pathHintWindows':
        'Example: C:\\\\Users\\\\<name>\\\\AppData\\\\Local\\\\Microsoft\\\\WinGet\\\\Packages\\\\...\\\\tuna.exe\nYou can find it with "where tuna" or "where tuna.exe" in PowerShell.',
    'settings.pathHintMac':
        'Example: /opt/homebrew/bin/tuna or /usr/local/bin/tuna\nYou can find it with "which tuna" in Terminal.',
    'settings.pathHintLinux':
        'Example: /usr/local/bin/tuna or /usr/bin/tuna\nYou can find it with "which tuna" in Terminal.',
    'settings.account': 'Account',
    'settings.user': 'User: {name}',
    'settings.subscriptionUntil': 'Subscription until: {date}',
    'settings.save': 'Save',
    'settings.cancel': 'Cancel',
    'settings.paste': 'Paste',
    'settings.clear': 'Clear',
    'settings.disclaimerPrefix':
        'tuna_unofficial_client is an independent client for working with tuna. It is not an official tuna application and is not maintained by the service team. For up-to-date information, documentation, and official tools, visit the ',
    'settings.disclaimerLink': 'official tuna website',
    'settings.disclaimerSuffix': '.',
    'settings.officialSite': 'https://tuna.am',
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.stop': 'Stop',
    'common.start': 'Start',
    'common.delete': 'Delete',
    'common.refresh': 'Refresh',
    'common.openUrl': 'Open URL',
    'common.clear': 'Clear',
    'common.copyAddress': 'Address copied',
    'dashboard.title': 'Dashboard',
    'dashboard.latestStarts': '2 latest starts',
    'dashboard.noStarts': 'No starts recorded yet.',
    'dashboard.failures': 'Failures',
    'dashboard.all': 'All',
    'dashboard.active': 'Active',
    'dashboard.stable': 'Stable',
    'dashboard.localRemote': 'Local/remote',
    'dashboard.failedStart': 'Could not start tunnel',
    'dashboard.failedOpenUrl': 'Could not open URL',
    'tunnels.title': 'Tunnels',
    'tunnels.add': 'Add tunnel',
    'tunnels.new': 'New tunnel',
    'tunnels.empty': 'No tunnels yet',
    'tunnels.saved': 'Tunnel saved',
    'tunnels.noLogs': 'No logs',
    'tunnels.logsSaved': 'Logs saved to file:\n{path}',
    'tunnels.checkForm': 'Check the form data',
    'tunnels.copyUrl': 'Copy URL',
    'tunnels.copyWebUi': 'Copy Web UI',
    'tunnels.backToList': 'Back to list',
    'tunnels.webInterface': 'Web interface',
    'tunnels.exportLogs': 'Export logs',
    'tunnels.edit': 'Edit',
    'tunnels.log': 'Log',
    'tunnels.clearVisibleLog': 'Clear visible log',
    'tunnelForm.name': 'Name',
    'tunnelForm.nameHint': 'For example, Local API',
    'tunnelForm.localPort': 'Local port',
    'tunnelForm.localPortHint': 'For example, 8080',
    'tunnelForm.localIp': 'Local IP (optional)',
    'tunnelForm.localIpHint': 'For example, 127.0.0.1',
    'tunnelForm.type': 'Tunnel type',
    'tunnelForm.subdomain': 'Subdomain (optional)',
    'tunnelForm.subdomainHint': 'For example, myapp',
    'docker.title': 'Docker',
    'docker.stopTitle': 'Stop tunnel in container',
    'docker.cancel': 'Cancel',
    'docker.stop': 'Stop',
    'docker.refreshList': 'Refresh list',
    'docker.notRunning': 'Docker Engine is not running.',
    'docker.empty': 'No containers found',
    'docker.back': 'Back to containers',
    'docker.refreshContainer': 'Refresh container',
    'docker.containerLog': 'Container log',
    'docker.stopTunnel': 'Stop tunnel',
    'remote.title': 'Remote tunnels',
    'remote.empty': 'No active remote tunnels found.',
    'remote.stopTitle': 'Stop remote tunnel',
    'remote.noId': 'Cannot stop a tunnel without an ID.',
    'remote.forceStop': 'Force stop',
    'remote.stopped': 'Remote tunnel stopped.',
    'remote.stopFailed': 'Could not stop remote tunnel.',
    'console.title': 'Console',
  },
};
