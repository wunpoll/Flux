import 'package:flutter/foundation.dart';

// Глобальный переключатель языка ('ru' по умолчанию)
// Используй ValueListenableBuilder(valueListenable: languageNotifier, ...) чтобы обновлять UI на лету
final ValueNotifier<String> languageNotifier = ValueNotifier('ru');

class AppStrings {
  // Метод для получения текущего языка
  static String get current => languageNotifier.value;

  // Словарь
  static final Map<String, Map<String, String>> _values = {
    'ru': {
      // --- AUTH (Вход/Регистрация) ---
      'app_name': 'FLUX',
      'slogan': 'Advantage Trading',
      'login': 'Войти',
      'register': 'Регистрация',
      'create_account': 'Создать аккаунт',
      'email': 'Email',
      'password': 'Пароль',
      'confirm_password': 'Повторите пароль',
      'forgot_password': 'Забыли пароль?',
      'logout': 'Выйти',
      'reset_password_title': 'Сброс пароля',
      'reset_password_desc': 'Введите email, чтобы получить ссылку',
      'send_link': 'Отправить ссылку',
      'link_sent': 'Ссылка для сброса отправлена!',
      'user_not_found': 'Пользователь не найден',

      // --- TABS (Нижняя навигация) ---
      'market': 'Рынок',
      'signals': 'Сигналы',
      'settings': 'Профиль',

      // --- HOME / MARKET SCREEN ---
      'search_hint': 'Поиск тикера...',
      'favorites_empty_hint': 'Добавьте активы в избранное\nчерез поиск',
      'moex': 'МОСБИРЖА',
      'crypto': 'КРИПТА',
      'sort_alphabet': 'По алфавиту',
      'sort_loss': 'Падение % (Топ)',
      'sort_gain': 'Рост % (Топ)',
      'sort_rsi_overbought': 'RSI: Перекупленность (>70)',
      'sort_rsi_oversold': 'RSI: Перепроданность (<30)',

      // --- CHART SCREEN (График и Аналитика) ---
      'buy': 'КУПИТЬ',
      'sell': 'ПРОДАТЬ',
      'loading': 'Загрузка...',
      'loading_price': 'Загрузка цены...',
      'analytics_signals': 'Аналитика и Сигналы',
      'trend_sma': 'Тренд (SMA 20)',
      'buy_signal': 'Сигнал: Покупка',
      'sell_signal': 'Сигнал: Продажа',
      'volatility': 'Волатильность',
      'risk_level': 'Уровень риска',
      'macd': 'MACD Стратегия',
      'professional_grade': 'Профессиональный уровень',
      'session': '(Сессия)',

      // --- ALERTS (Уведомления) ---
      'alerts_title': 'Уведомления для',
      'add': 'Добавить',
      'no_alerts': 'Нет активных уведомлений',
      'create_alert_title': 'Создать уведомление',
      'notify_cond': 'Уведомить, когда цена:',
      'cond_greater': 'Больше чем (>)',
      'cond_less': 'Меньше чем (<)',
      'target_price': 'Целевая цена',
      'cancel': 'Отмена',
      'create': 'Создать',
      'price_type': 'Цена',
      'condition_label': 'Условие:',

      // --- SIGNALS SCREEN (Экран сигналов) ---
      'active_signals': 'Активные сигналы',
      'no_signals': 'Нет сигналов',
      'set_alerts_hint': 'Создайте уведомления на графике',
      'status_triggered': 'СРАБОТАЛ',
      'status_pending': 'ОЖИДАНИЕ',
      'status_active': 'АКТИВЕН',

      // --- WALLET & TRADE (Кошелек и Торговля) ---
      'portfolio': 'Портфель',
      'total_balance': 'Общий баланс',
      'deposit': 'Пополнить',
      'my_assets': 'Мои активы',
      'no_assets': 'Активов пока нет',
      'top_up_title': 'Пополнение баланса',
      'success_deposit': 'Успешно пополнено на',
      'available_balance': 'Доступно (USD)',
      'available_asset': 'Доступно',
      'amount_usd': 'Сумма в USD',
      'amount_asset': 'Количество',
      'buy_action': 'КУПИТЬ СЕЙЧАС',
      'sell_action': 'ПРОДАТЬ СЕЙЧАС',
      'transaction_success': 'Транзакция успешна',
      'you_bought': 'Вы купили',
      'you_sold': 'Вы продали',
      'awesome': 'Отлично!',
      'for_price': 'за',
      'error': 'Ошибка',
      'insufficient_funds': 'Недостаточно средств',
      'insufficient_assets': 'Недостаточно активов',

      // --- PAYWALL (Подписка) ---
      'upgrade_pro': 'Обновиться до PRO',
      'processing_payment': 'Обработка платежа...',
      'welcome_club': 'Добро пожаловать в клуб!',
      'unlock_desc': 'Разблокируйте проф. индикаторы и безлимитные уведомления.',
      'unlimited_alerts': 'Безлимитные уведомления',
      'advanced_analytics': 'Продвинутая аналитика',
      'lets_go': 'Погнали!',
      'subscribe_price': 'Подписка \$4.99',

      // --- SETTINGS & PROFILE ---
      'account': 'Аккаунт',
      'appearance': 'Внешний вид',
      'dark_theme': 'Темная тема',
      'language': 'Язык',
      'app_version': 'Версия приложения',
      'net_worth': 'Баланс',
      'cash': 'Деньги',
      'all_time': 'За всё время',

      // --- ROLES & ADMIN ---
      'guest': 'Гость',
      'pro_member': 'PRO ПОДПИСЧИК',
      'admin': 'АДМИНИСТРАТОР',
      'basic_plan': 'Базовый тариф',
      'admin_console': 'Админ панель',
      'user_management': 'Пользователи',
      'system_analytics': 'Аналитика системы',
      'no_email': 'Нет Email',
      'role_label': 'Роль',
      'master_role': 'МАСТЕР',
      'platform_health': 'Состояние платформы',
      'total_users': 'Всего юзеров',
      'pro_members': 'PRO Участники',
      'total_alerts': 'Всего сигналов',
      'active_triggers': 'Активные триггеры',
      'db_status': 'Статус БД',
      'status_healthy': 'Норма',
      'api_status': 'API Соединения',
      'status_online': 'Онлайн',
      'status_offline': 'Офлайн',
      'status_error': 'Ошибка',
      'status_cached': 'Нет соединения',

    },
    'en': {
      // --- AUTH ---
      'app_name': 'FLUX',
      'slogan': 'Advantage Trading',
      'login': 'Log In',
      'register': 'Sign Up',
      'create_account': 'Create Account',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'forgot_password': 'Forgot Password?',
      'logout': 'Log Out',
      'reset_password_title': 'Reset Password',
      'reset_password_desc': 'Enter email to receive reset link',
      'send_link': 'Send Link',
      'link_sent': 'Reset link sent!',
      'user_not_found': 'User not found',

      // --- TABS ---
      'market': 'Market',
      'signals': 'Signals',
      'settings': 'Profile',

      // --- HOME / MARKET SCREEN ---
      'search_hint': 'Search ticker...',
      'favorites_empty_hint': 'Add assets to favorites\nvia search',
      'moex': 'MOEX',
      'crypto': 'CRYPTO',
      'sort_alphabet': 'Alphabetical',
      'sort_loss': 'Top Losers %',
      'sort_gain': 'Top Gainers %',
      'sort_rsi_overbought': 'RSI: Overbought (>70)',
      'sort_rsi_oversold': 'RSI: Oversold (<30)',

      // --- CHART SCREEN ---
      'buy': 'BUY',
      'sell': 'SELL',
      'loading': 'Loading...',
      'loading_price': 'Loading price...',
      'analytics_signals': 'Analytics & Signals',
      'trend_sma': 'Trend (SMA 20)',
      'buy_signal': 'Buy Signal',
      'sell_signal': 'Sell Signal',
      'volatility': 'Volatility',
      'risk_level': 'Risk Level',
      'macd': 'MACD Strategy',
      'professional_grade': 'Professional Grade',
      'session': '(Session)',

      // --- ALERTS ---
      'alerts_title': 'Alerts for',
      'add': 'Add',
      'no_alerts': 'No active alerts',
      'create_alert_title': 'Create Price Alert',
      'notify_cond': 'Notify me when price is:',
      'cond_greater': 'Greater Than (>)',
      'cond_less': 'Less Than (<)',
      'target_price': 'Target Price',
      'cancel': 'Cancel',
      'create': 'Create',
      'price_type': 'Price',
      'condition_label': 'Condition:',

      // --- SIGNALS SCREEN ---
      'active_signals': 'Active Signals',
      'no_signals': 'No signals set',
      'set_alerts_hint': 'Set alerts on Chart Screen',
      'status_triggered': 'TRIGGERED',
      'status_pending': 'PENDING',
      'status_active': 'ACTIVE',

      // --- WALLET & TRADE ---
      'portfolio': 'Portfolio',
      'total_balance': 'Total Balance',
      'deposit': 'Deposit',
      'my_assets': 'My Assets',
      'no_assets': 'No assets yet',
      'top_up_title': 'Top Up Balance',
      'success_deposit': 'Successfully added',
      'available_balance': 'Available USD',
      'available_asset': 'Available',
      'amount_usd': 'Amount in USD',
      'amount_asset': 'Amount in',
      'buy_action': 'BUY NOW',
      'sell_action': 'SELL NOW',
      'transaction_success': 'Transaction Successful',
      'you_bought': 'You successfully bought',
      'you_sold': 'You successfully sold',
      'awesome': 'Awesome!',
      'for_price': 'for',
      'error': 'Error',
      'insufficient_funds': 'Insufficient Funds',
      'insufficient_assets': 'Not enough assets',

      // --- PAYWALL ---
      'upgrade_pro': 'Upgrade to PRO',
      'processing_payment': 'Processing payment...',
      'welcome_club': 'Welcome to the Club!',
      'unlock_desc': 'Unlock professional grade indicators and unlimited alerts.',
      'unlimited_alerts': 'Unlimited Alerts',
      'advanced_analytics': 'Advanced Analytics',
      'lets_go': "Let's go!",
      'subscribe_price': 'Subscribe \$4.99',

      // --- SETTINGS & PROFILE ---
      'account': 'Account',
      'appearance': 'Appearance',
      'dark_theme': 'Dark Mode',
      'language': 'Language',
      'app_version': 'App Version',
      'net_worth': 'Net Worth',
      'cash': "Cash",
      'all_time': 'All time',

      // --- ROLES & ADMIN ---
      'guest': 'Guest',
      'pro_member': 'PRO MEMBER',
      'admin': 'ADMINISTRATOR',
      'basic_plan': 'Basic Plan',
      'admin_console': 'Admin Console',
      'user_management': 'User Management',
      'system_analytics': 'System Analytics',
      'no_email': 'No Email',
      'role_label': 'Role',
      'master_role': 'MASTER',
      'platform_health': 'Platform Health',
      'total_users': 'Total Users',
      'pro_members': 'PRO Members',
      'total_alerts': 'Total Alerts',
      'active_triggers': 'Active Triggers',
      'db_status': 'Database Status',
      'status_healthy': 'Healthy',
      'api_status': 'API Connections',
      'status_online': 'Online',
      'status_offline': 'Offline',
      'status_error': 'Error',
      'status_cached': 'No connection',

    },
  };

  // Функция для получения строки по ключу
  static String t(String key) {
    return _values[current]?[key] ?? key; // Если ключа нет, возвращаем сам ключ
  }
}