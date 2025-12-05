import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/api_service.dart' as api;
import 'models/ticket_info.dart';
import 'dart:async';

void main() {
  runApp(const TicketScannerApp());
}

class TicketScannerApp extends StatelessWidget {
  const TicketScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Validador de Tickets',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ModeSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Pantalla de selección de modo
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // Azul oscuro
              Color(0xFF3B82F6), // Azul medio
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo o icono principal
                const Icon(
                  Icons.qr_code_scanner,
                  size: 120,
                  color: Colors.white,
                ),
                const SizedBox(height: 30),
                
                // Título
                const Text(
                  'Validador de Tickets',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                
                const Text(
                  'Selecciona el modo de operación',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                
                // Botón Modo Normal
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NormalModeScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 30),
                    label: const Text(
                      'Modo Normal',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Botón Modo Debug
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DebugModeScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bug_report, size: 30),
                    label: const Text(
                      'Modo Debug',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Información adicional
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '• Modo Normal: Interfaz limpia para escaneo',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '• Modo Debug: Herramientas de testing y monitoreo',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Enums y clases auxiliares
enum ValidationState {
  ready,
  validating,
  valid,
  invalid,
}

enum AdminMode {
  off,
  viewer,
  admin,
}

// Pantalla Modo Normal (solo escaneo)
class NormalModeScreen extends StatefulWidget {
  const NormalModeScreen({super.key});

  @override
  State<NormalModeScreen> createState() => _NormalModeScreenState();
}

class _NormalModeScreenState extends State<NormalModeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _qrController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ValidationState _currentState = ValidationState.ready;
  
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _backgroundAnimation;
  
  AudioPlayer audioPlayer = AudioPlayer();
  bool _isConnected = true;
  String _apiUrl = 'http://23.22.68.102:5102';
  late api.ApiService _apiService;
  
  Timer? _resetTimer;
  String _currentMessage = 'Listo para escanear';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
    _checkConnectivity();
    _maintainFocus();
    
    // Monitor de conectividad
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _backgroundAnimation = ColorTween(
      begin: const Color(0xFF2E3B4E),
      end: Colors.green,
    ).animate(_backgroundController);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrl = prefs.getString('api_url') ?? 'http://23.22.68.102:5102';
      _apiService = api.ApiService(baseUrl: _apiUrl);
    });
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (!mounted) return;
    setState(() {
      _isConnected = result != ConnectivityResult.none;
    });
  }

  void _maintainFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentState != ValidationState.validating) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _processQRCode(String qrCode) async {
    if (qrCode.trim().isEmpty || _currentState == ValidationState.validating) {
      return;
    }

    _qrController.clear();
    
    setState(() {
      _currentState = ValidationState.validating;
      _currentMessage = 'Validando ticket...';
    });

    try {
      final result = await _validateTicket(qrCode.trim());
      _handleValidationResult(result, qrCode.trim());
    } catch (e) {
      _handleError('Error de conexión');
    }
  }

  Future<api.ApiResponse> _validateTicket(String code) async {
    if (!_isConnected) {
      return api.ApiResponse(
        success: false,
        error: 'Sin conexión a internet',
        code: 'OFFLINE',
      );
    }

    return await _apiService.validateTicket(code);
  }

  void _handleValidationResult(api.ApiResponse response, String code) {
    final isValid = response.success && response.ticketInfo != null;
    final ticketInfo = response.ticketInfo;
    
    setState(() {
      _currentState = isValid ? ValidationState.valid : ValidationState.invalid;
      
      if (isValid && ticketInfo != null) {
        _currentMessage = '¡Ticket Válido!\n${ticketInfo.event}\n${ticketInfo.isValid ? "Activo" : "Usado"}';
      } else {
        // Handle different error codes
        switch (response.code) {
          case 'TICKET_NOT_FOUND':
            _currentMessage = 'Ticket no encontrado\no inválido';
            break;
          case 'TICKET_ALREADY_USED':
            _currentMessage = 'Ticket ya fue\nescaneado anteriormente';
            break;
          case 'OFFLINE':
            _currentMessage = 'Sin conexión\n(guardado offline)';
            break;
          default:
            _currentMessage = response.error ?? 'Error desconocido';
        }
      }
    });

    // Animaciones y efectos
    if (isValid) {
      _animationController.forward();
      _backgroundController.forward();
      _playSuccessSound();
      _vibrate();
    } else {
      _playErrorSound();
      _vibrate();
    }

    // Auto-reset después de 3 segundos
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), _resetToReady);
  }

  void _handleError(String error) {
    setState(() {
      _currentState = ValidationState.invalid;
      _currentMessage = error;
    });
    
    _playErrorSound();
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), _resetToReady);
  }

  void _resetToReady() {
    setState(() {
      _currentState = ValidationState.ready;
      _currentMessage = 'Listo para escanear';
    });
    
    _animationController.reset();
    _backgroundController.reset();
    _maintainFocus();
  }

  Future<void> _playSuccessSound() async {
    // Audio desactivado temporalmente - archivos vacíos
    SystemSound.play(SystemSoundType.click);
  }

  Future<void> _playErrorSound() async {
    // Audio desactivado temporalmente - archivos vacíos
    SystemSound.play(SystemSoundType.alert);
  }

  void _vibrate() {
    HapticFeedback.mediumImpact();
  }

  Color _getBackgroundColor() {
    switch (_currentState) {
      case ValidationState.ready:
        return const Color(0xFF2E3B4E);
      case ValidationState.validating:
        return Colors.orange.shade300;
      case ValidationState.valid:
        return _backgroundAnimation.value ?? Colors.green;
      case ValidationState.invalid:
        return Colors.red.shade400;
    }
  }

  IconData _getStateIcon() {
    switch (_currentState) {
      case ValidationState.ready:
        return Icons.qr_code_scanner;
      case ValidationState.validating:
        return Icons.hourglass_empty;
      case ValidationState.valid:
        return Icons.check_circle;
      case ValidationState.invalid:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _getBackgroundColor(),
                  _getBackgroundColor().withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header con botón de volver
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        Row(
                          children: [
                            Icon(
                              _isConnected ? Icons.wifi : Icons.wifi_off,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isConnected ? 'Online' : 'Offline',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Título
                  const Text(
                    'Modo Normal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Área central de escaneo
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Marco de escaneo visual
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 160,
                                height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _getStateIcon(),
                                size: 80,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Mensaje de estado
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _currentMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                            if (_currentState == ValidationState.validating)
                              const Padding(
                                padding: EdgeInsets.only(top: 20),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Input visible con transparencia del 50%
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5), // 50% transparencia
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Área de Escaneo',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          // Input del scanner con transparencia
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _qrController,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Apunta el scanner aquí...',
                                hintStyle: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.blue.withOpacity(0.7),
                                ),
                              ),
                              onSubmitted: _processQRCode,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              readOnly: false,
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          const Text(
                            'El scanner escribirá automáticamente el código aquí',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      

    );
  }

  @override
  void dispose() {
    _qrController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _backgroundController.dispose();
    _resetTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}

// Pantalla Modo Debug (con todas las herramientas de testing)
class DebugModeScreen extends StatefulWidget {
  const DebugModeScreen({super.key});

  @override
  State<DebugModeScreen> createState() => _DebugModeScreenState();
}

class _DebugModeScreenState extends State<DebugModeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _qrController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ValidationState _currentState = ValidationState.ready;
  
  // Variables específicas del modo debug
  String _currentInputText = '';
  String _lastProcessedCode = '';
  DateTime? _lastEnterPressed;
  
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _backgroundAnimation;
  
  AudioPlayer audioPlayer = AudioPlayer();
  List<TicketInfo> _validationHistory = [];
  int _sessionCount = 0;
  bool _isConnected = true;
  String _apiUrl = 'http://23.22.68.102:5102';
  late api.ApiService _apiService;
  AdminMode _adminMode = AdminMode.off;
  
  Timer? _resetTimer;
  String _currentMessage = 'Listo para escanear';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
    _checkConnectivity();
    _maintainFocus();
    
    // Listener para mostrar texto en tiempo real en modo debug
    _qrController.addListener(() {
      setState(() {
        _currentInputText = _qrController.text;
      });
    });
    
    // Monitor de conectividad
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _backgroundAnimation = ColorTween(
      begin: const Color(0xFF2E3B4E),
      end: Colors.green,
    ).animate(_backgroundController);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrl = prefs.getString('api_url') ?? 'http://23.22.68.102:5102';
      _apiService = api.ApiService(baseUrl: _apiUrl);
    });
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (!mounted) return;
    setState(() {
      _isConnected = result != ConnectivityResult.none;
    });
  }

  void _maintainFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentState != ValidationState.validating) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _processQRCode(String qrCode) async {
    if (qrCode.trim().isEmpty || _currentState == ValidationState.validating) {
      return;
    }

    // Registrar el evento de Enter/envío
    setState(() {
      _lastEnterPressed = DateTime.now();
      _lastProcessedCode = qrCode.trim();
      _currentInputText = ''; // Limpiar el display
    });

    _qrController.clear();
    
    setState(() {
      _currentState = ValidationState.validating;
      _currentMessage = 'Validando ticket...';
    });

    try {
      final result = await _validateTicket(qrCode.trim());
      _handleValidationResult(result, qrCode.trim());
    } catch (e) {
      _handleError('Error de conexión');
    }
  }

  Future<api.ApiResponse> _validateTicket(String code) async {
    if (!_isConnected) {
      // Modo offline - guardar para sincronización posterior
      await _saveOfflineValidation(code);
      return api.ApiResponse(
        success: false,
        error: 'Sin conexión a internet',
        code: 'OFFLINE',
      );
    }

    return await _apiService.validateTicket(code);
  }

  void _handleValidationResult(api.ApiResponse response, String code) {
    final isValid = response.success && response.ticketInfo != null;
    final ticketInfo = response.ticketInfo;
    
    setState(() {
      _currentState = isValid ? ValidationState.valid : ValidationState.invalid;
      
      if (isValid && ticketInfo != null) {
        _currentMessage = '¡Ticket Válido!\n${ticketInfo.event}\n${ticketInfo.isValid ? "Activo" : "Usado"}';
      } else {
        // Handle different error codes
        switch (response.code) {
          case 'TICKET_NOT_FOUND':
            _currentMessage = 'Ticket no encontrado\no inválido';
            break;
          case 'TICKET_ALREADY_USED':
            _currentMessage = 'Ticket ya fue\nescaneado anteriormente';
            break;
          case 'OFFLINE':
            _currentMessage = 'Sin conexión\n(guardado offline)';
            break;
          default:
            _currentMessage = response.error ?? 'Error desconocido';
        }
      }
      
      _sessionCount++;
    });

    // Añadir al historial - crear una nueva instancia de TicketInfo compatible
    if (response.ticketInfo != null) {
      final backendTicket = response.ticketInfo!;
      final modelTicket = TicketInfo(
        event: backendTicket.event,
        date: backendTicket.date,
        code: code,
        isValid: backendTicket.isValid,
        timestamp: DateTime.now(),
        message: response.message,
        errorCode: response.code,
      );
      _validationHistory.insert(0, modelTicket);
      if (_validationHistory.length > 10) {
        _validationHistory.removeLast();
      }
    }

    // Animaciones y efectos
    if (isValid) {
      _animationController.forward();
      _backgroundController.forward();
      _playSuccessSound();
      _vibrate();
    } else {
      _playErrorSound();
      _vibrate();
    }

    // Auto-reset después de 3 segundos
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), _resetToReady);
  }

  void _handleError(String error) {
    setState(() {
      _currentState = ValidationState.invalid;
      _currentMessage = error;
    });
    
    _playErrorSound();
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), _resetToReady);
  }

  void _resetToReady() {
    setState(() {
      _currentState = ValidationState.ready;
      _currentMessage = 'Listo para escanear';
    });
    
    _animationController.reset();
    _backgroundController.reset();
    _maintainFocus();
  }

  Future<void> _playSuccessSound() async {
    // Audio desactivado temporalmente - archivos vacíos
    SystemSound.play(SystemSoundType.click);
  }

  Future<void> _playErrorSound() async {
    // Audio desactivado temporalmente - archivos vacíos
    SystemSound.play(SystemSoundType.alert);
  }

  void _vibrate() {
    HapticFeedback.mediumImpact();
  }

  Future<void> _saveOfflineValidation(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final offline = prefs.getStringList('offline_validations') ?? [];
    offline.add('$code|${DateTime.now().toIso8601String()}');
    await prefs.setStringList('offline_validations', offline);
  }

  Color _getBackgroundColor() {
    switch (_currentState) {
      case ValidationState.ready:
        return const Color(0xFF2E3B4E);
      case ValidationState.validating:
        return Colors.orange.shade300;
      case ValidationState.valid:
        return _backgroundAnimation.value ?? Colors.green;
      case ValidationState.invalid:
        return Colors.red.shade400;
    }
  }

  IconData _getStateIcon() {
    switch (_currentState) {
      case ValidationState.ready:
        return Icons.qr_code_scanner;
      case ValidationState.validating:
        return Icons.hourglass_empty;
      case ValidationState.valid:
        return Icons.check_circle;
      case ValidationState.invalid:
        return Icons.error;
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) => HistoryBottomSheet(history: _validationHistory),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        currentApiUrl: _apiUrl,
        adminMode: _adminMode,
        onApiUrlChanged: (url) {
          setState(() {
            _apiUrl = url;
            _apiService = api.ApiService(baseUrl: url);
          });
        },
        onAdminModeChanged: (mode) {
          setState(() {
            _adminMode = mode;
          });
        },
      ),
    );
  }

  void _clearInput() {
    _qrController.clear();
    setState(() {
      _currentInputText = '';
    });
    _maintainFocus();
  }

  void _resetDebugInfo() {
    setState(() {
      _lastProcessedCode = '';
      _lastEnterPressed = null;
      _currentInputText = '';
    });
    _clearInput();
  }

  void _showAdminPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AdminPanelSheet(
        apiService: _apiService,
        adminMode: _adminMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _getBackgroundColor(),
                  _getBackgroundColor().withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            Icon(
                              _isConnected ? Icons.wifi : Icons.wifi_off,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isConnected ? 'Online' : 'Offline',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _showHistory,
                              icon: const Icon(Icons.history, color: Colors.white),
                            ),
                            if (_adminMode != AdminMode.off)
                              IconButton(
                                onPressed: _showAdminPanel,
                                icon: Icon(
                                  Icons.admin_panel_settings,
                                  color: _adminMode == AdminMode.admin ? Colors.red : Colors.orange,
                                ),
                              ),
                            IconButton(
                              onPressed: _showSettings,
                              icon: const Icon(Icons.settings, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Título principal
                  const Text(
                    'Modo Debug',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Marco de escaneo pequeño
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _getStateIcon(),
                        size: 50,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Mensaje de estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _currentMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Sección de Debug
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellow, width: 2),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bug_report, color: Colors.yellow, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'HERRAMIENTAS DE DEBUG',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Texto actual en el input (en tiempo real)
                            Text(
                              'Escribiendo en tiempo real:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _currentInputText.isNotEmpty ? Colors.green : Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _currentInputText.isEmpty ? '(esperando que el scanner escriba...)' : _currentInputText,
                                style: TextStyle(
                                  color: _currentInputText.isEmpty ? Colors.grey : Colors.green,
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: _currentInputText.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Último código procesado
                            Text(
                              'Último código enviado (Enter):',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _lastProcessedCode.isNotEmpty ? Colors.blue : Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lastProcessedCode.isEmpty ? '(ningún código enviado aún)' : _lastProcessedCode,
                                    style: TextStyle(
                                      color: _lastProcessedCode.isEmpty ? Colors.grey : Colors.blue,
                                      fontFamily: 'monospace',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_lastEnterPressed != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Enviado: ${_lastEnterPressed!.toString().substring(11, 19)}',
                                      style: TextStyle(
                                        color: Colors.blue.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                           
                            const SizedBox(height: 12),
                            
                            // Input visible para testing manual
                            TextField(
                              controller: _qrController,
                              focusNode: _focusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Input del Scanner - Presiona ENTER para enviar',
                                labelStyle: const TextStyle(color: Colors.white70),
                                helperText: 'El scanner debe terminar con Enter/Return',
                                helperStyle: const TextStyle(color: Colors.yellow, fontSize: 11),
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.yellow),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.yellow),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.yellow, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                suffixIcon: _currentInputText.isNotEmpty 
                                  ? const Icon(Icons.keyboard_return, color: Colors.yellow, size: 20)
                                  : null,
                              ),
                              onSubmitted: (value) {
                                _processQRCode(value);
                              },
                              onChanged: (value) {
                                setState(() {
                                  _currentInputText = value;
                                });
                              },
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                            ),
                           
                            const SizedBox(height: 12),
                            
                            // Botones de control
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _clearInput,
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Limpiar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _resetDebugInfo,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reset'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final testCode = 'TEST_${DateTime.now().millisecondsSinceEpoch}';
                                      _qrController.text = testCode;
                                      setState(() {
                                        _currentInputText = testCode;
                                      });
                                      Future.delayed(const Duration(milliseconds: 500), () {
                                        _processQRCode(testCode);
                                      });
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Test'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                           
                            const SizedBox(height: 12),
                            
                            // Información de status detallada
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STATUS DE DEBUG:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '• Estado: ${_currentState.name.toUpperCase()}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '• Input en focus: ${_focusNode.hasFocus ? "✅ SÍ" : "❌ NO"}',
                                    style: TextStyle(
                                      color: _focusNode.hasFocus ? Colors.green : Colors.red,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '• Caracteres escribiendo: ${_currentInputText.length}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '• Último ENTER: ${_lastEnterPressed != null ? "✅ ${_lastEnterPressed.toString().substring(11, 19)}" : "❌ Ninguno"}',
                                    style: TextStyle(
                                      color: _lastEnterPressed != null ? Colors.green : Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '• Tickets procesados: $_sessionCount',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _qrController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _backgroundController.dispose();
    _resetTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}

// Clases auxiliares
class HistoryBottomSheet extends StatelessWidget {
  final List<TicketInfo> history;

  const HistoryBottomSheet({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historial de Validaciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final ticket = history[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      ticket.isValid ? Icons.check_circle : Icons.error,
                      color: ticket.isValid ? Colors.green : Colors.red,
                    ),
                    title: Text(ticket.event),
                    subtitle: Text(
                      '${ticket.displayCode}... - ${ticket.timestamp.toString().substring(11, 19)}',
                    ),
                    trailing: Text(
                      ticket.isValid ? 'Válido' : 'Usado',
                      style: TextStyle(
                        color: ticket.isValid ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPanelSheet extends StatefulWidget {
  final api.ApiService apiService;
  final AdminMode adminMode;

  const AdminPanelSheet({
    super.key,
    required this.apiService,
    required this.adminMode,
  });

  @override
  State<AdminPanelSheet> createState() => _AdminPanelSheetState();
}

class _AdminPanelSheetState extends State<AdminPanelSheet> {
  List<TicketInfo>? _allTickets;
  bool _loading = false;
  final TextEditingController _ticketCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllTickets();
  }

  Future<void> _loadAllTickets() async {
    setState(() => _loading = true);
    try {
      final response = await widget.apiService.getAllTickets();
      setState(() {
        _allTickets = response.tickets?.map((backendTicket) => TicketInfo(
          event: backendTicket.event,
                  date: backendTicket.date,
        code: backendTicket.code,
          isValid: backendTicket.isValid,
          timestamp: DateTime.now(),
        )).toList() ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetTicket(String qrCode) async {
    try {
      final response = await widget.apiService.resetTicket(qrCode);
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket reset exitosamente')),
        );
        _loadAllTickets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.error}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel de Administración',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.adminMode == AdminMode.admin ? Colors.red : Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          
          if (widget.adminMode == AdminMode.admin) ...[
            TextField(
              controller: _ticketCodeController,
              decoration: const InputDecoration(
                labelText: 'Código QR para resetear',
                hintText: 'QUJDLWFiYy0xMjM0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (_ticketCodeController.text.isNotEmpty) {
                  _resetTicket(_ticketCodeController.text);
                  _ticketCodeController.clear();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reset Ticket', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
          
          Text(
            'Todos los Tickets (${_allTickets?.length ?? 0})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _allTickets == null || _allTickets!.isEmpty
                ? const Center(child: Text('No hay tickets disponibles'))
                : ListView.builder(
                    itemCount: _allTickets!.length,
                    itemBuilder: (context, index) {
                      final ticket = _allTickets![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ticket.isValid ? Colors.green : Colors.red,
                            child: Text(
                              ticket.event.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(ticket.event),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${ticket.event} - ${ticket.date}'),
                              Text('QR: ${ticket.displayCode}...'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ticket.isValid ? 'ACTIVO' : 'USADO',
                                style: TextStyle(
                                  color: ticket.isValid ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Estado: ${ticket.statusText}'),
                            ],
                          ),
                          onTap: widget.adminMode == AdminMode.admin && !ticket.isValid
                            ? () => _resetTicket(ticket.code)
                            : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticketCodeController.dispose();
    super.dispose();
  }
}

class SettingsDialog extends StatefulWidget {
  final String currentApiUrl;
  final AdminMode adminMode;
  final Function(String) onApiUrlChanged;
  final Function(AdminMode) onAdminModeChanged;

  const SettingsDialog({
    super.key,
    required this.currentApiUrl,
    required this.adminMode,
    required this.onApiUrlChanged,
    required this.onAdminModeChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.currentApiUrl);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuración'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL de API',
              hintText: 'http://localhost:3000',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Modo Admin:'),
              const SizedBox(width: 10),
              DropdownButton<AdminMode>(
                value: widget.adminMode,
                items: const [
                  DropdownMenuItem(value: AdminMode.off, child: Text('Desactivado')),
                  DropdownMenuItem(value: AdminMode.viewer, child: Text('Visualización')),
                  DropdownMenuItem(value: AdminMode.admin, child: Text('Administrador')),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    widget.onAdminModeChanged(mode);
                  }
                },
              ),
            ],
          ),
          if (widget.adminMode != AdminMode.off)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Modo admin permite ver y resetear tickets',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('api_url', _urlController.text);
            widget.onApiUrlChanged(_urlController.text);
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
