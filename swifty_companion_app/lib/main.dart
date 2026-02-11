import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:swifty_companion_app/profilPage.dart';
import 'package:json_theme/json_theme.dart';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeStr = await rootBundle.loadString('assets/theme.json');
  final themeJson = jsonDecode(themeStr);
  
  final ThemeData theme = ThemeDecoder.decodeThemeData(
    themeJson,
    validate: true,
    )!;

  runApp(SwiftyCompanionApp(theme: theme));
}

class SwiftyCompanionApp extends StatelessWidget {
  const SwiftyCompanionApp({super.key, required this.theme});

  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifty Companion',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const BootstrapPage(),
    );
  }
}

/// Page d'initialisation : charge .env, initialise Dio/Auth, récupère un token.
/// Ensuite, redirige vers la page de recherche.
class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Charger .env (doit être déclaré dans pubspec.yaml en assets)
      await dotenv.load(fileName: '.env');

      final apiBase = dotenv.env['API42_URL'] ?? 'https://api.intra.42.fr';

      // 2) Client réseau
      final dio = Dio(BaseOptions(
        baseUrl: apiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // 3) Auth + token (cache)
      final auth = AuthService(dio: dio);
      await auth.ensureValidToken();

      // 4) Interceptor : injecte Authorization + retry 401
      dio.interceptors.add(AuthInterceptor(authService: auth, dio: dio));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginSearchPage(dio: dio),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final screenWidth = mediaSize.width;
    final screenHeight = mediaSize.height;
    final baseSize = mediaSize.shortestSide;
    
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Swifty Companion')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: _loading
                ? const CircularProgressIndicator()
                : _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Initialization failed:\n$_error',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: screenWidth * 0.04),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          SizedBox(
                            width: screenWidth * 0.6,
                            height: screenHeight * 0.06,
                            child: FilledButton(
                              onPressed: _bootstrap,
                              child: Text(
                                'Retry',
                                style: TextStyle(fontSize: screenWidth * 0.04),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Text('Ready'),
          ),
        ),
      ),
    );
  }
}

class LoginSearchPage extends StatefulWidget {
  final Dio dio;

  const LoginSearchPage({
    super.key,
    required this.dio,
  });

  @override
  State<LoginSearchPage> createState() => _LoginSearchPageState();
}

class _LoginSearchPageState extends State<LoginSearchPage> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
  final login = _controller.text.trim().toLowerCase();

  if (login.isEmpty) {
    setState(() => _error = 'Please enter a 42 login.');
    return;
  }
  if (login.length > 8) {
    setState(() => _error = 'Login must be at most 8 characters.');
    return;
  }

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    // Grâce à l’interceptor: Authorization + refresh automatique
    final res = await widget.dio.get('/v2/users/$login');

    final data = res.data;
    final Map<String, dynamic> user =
        (data is Map<String, dynamic>) ? data : Map<String, dynamic>.from(data);

    // Navigation uniquement si succès
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(user: user),
      ),
    );
  } on DioException catch (e) {
    final status = e.response?.statusCode;

    setState(() {
      if (status == 404) {
        _error = 'Login not found.';
      } else if (status == 401) {
        _error = 'Unauthorized (token invalid/expired).';
      } else if (status == 429) {
        _error = 'Too many requests (rate limit).';
      } else if (status != null) {
        _error = 'HTTP $status error.';
      } else {
        _error = 'Network error (timeout / no connection).';
      }
    });
  } catch (e) {
    setState(() => _error = 'Unexpected error: $e');
  } finally {
    if (!mounted) return;
    setState(() => _loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final screenWidth = mediaSize.width;
    final screenHeight = mediaSize.height;
    final baseSize = mediaSize.shortestSide;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Swifty Companion')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                maxLength: 8,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(8),
                ],
                style: TextStyle(fontSize: baseSize * 0.045),
                decoration: InputDecoration(
                  labelText: '42 login',
                  hintText: 'e.g. jdupont',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  counterText: '',
                  labelStyle: TextStyle(fontSize: baseSize * 0.04),
                  hintStyle: TextStyle(fontSize: baseSize * 0.04),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              SizedBox(
                height: screenHeight * 0.06,
                child: FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Search',
                          style: TextStyle(fontSize: baseSize * 0.045),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthService {
  final Dio dio;

  String? _accessToken;
  DateTime? _expiresAt;

  Future<void>? _refreshing; // verrou correct (nullable)

  AuthService({required this.dio});

  String? get accessToken => _accessToken;

  bool get _tokenValid {
    if (_accessToken == null || _expiresAt == null) return false;
    // marge anti-dérive : considéré expiré 30s avant
    return DateTime.now().isBefore(_expiresAt!.subtract(const Duration(seconds: 30)));
  }

  Future<void> ensureValidToken() {
    if (_tokenValid) return Future.value();
    _refreshing ??= _fetchToken().whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  Future<void> forceRefreshToken() {
    _refreshing ??= _fetchToken().whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  Future<void> _fetchToken() async {
    final clientId = dotenv.env['CLIENT_ID'];
    final clientSecret = dotenv.env['CLIENT_SECRET'];

    if (clientId == null ||
        clientId.isEmpty ||
        clientSecret == null ||
        clientSecret.isEmpty) {
      throw Exception('Missing CLIENT_ID / CLIENT_SECRET in .env');
    } else {
      debugPrint("CLIENT_ID len=${(dotenv.env['CLIENT_ID'] ?? '').length}");
      debugPrint("CLIENT_SECRET len=${(dotenv.env['CLIENT_SECRET'] ?? '').length}");
    }

    final res = await dio.post(
      '/oauth/token',
      data: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Accept': 'application/json'},
      ),
    );

    final data = res.data;
    final token = data['access_token'] as String?;
    final expiresIn = data['expires_in'];

    if (token == null || token.isEmpty) {
      throw Exception('Token response missing access_token');
    }

    final expiresSeconds = (expiresIn is int)
        ? expiresIn
        : int.tryParse(expiresIn.toString()) ?? 0;

    _accessToken = token;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresSeconds));
  }
}

class AuthInterceptor extends Interceptor {
  final AuthService authService;
  final Dio dio;

  AuthInterceptor({required this.authService, required this.dio});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      await authService.ensureValidToken();
      final token = authService.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      options.headers['Accept'] = 'application/json';
      handler.next(options);
    } catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Retry une fois sur 401 (token expiré / révoqué)
    if (err.response?.statusCode == 401) {
      try {
        await authService.forceRefreshToken();
        final token = authService.accessToken;

        if (token != null) {
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
        }

        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {
        // si refresh échoue, on laisse l’erreur remonter
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
