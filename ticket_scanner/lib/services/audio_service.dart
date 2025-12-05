import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Servicio de audio para manejar sonidos de la aplicación
class AudioService {
  late AudioPlayer _audioPlayer;
  double _volume = 1.0;
  bool _soundEnabled = false; // Desactivado temporalmente - archivos de audio vacíos

  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _audioPlayer = AudioPlayer();
  }

  /// Inicializa el servicio de audio
  Future<void> initialize() async {
    await _loadSettings();
    await _audioPlayer.setVolume(_volume);
  }

  /// Carga configuraciones de audio desde SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(AppConstants.volumeKey) ?? 1.0;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
  }

  /// Reproduce sonido de éxito
  Future<void> playSuccessSound() async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.stop(); // Detener cualquier sonido anterior
      await _audioPlayer.play(AssetSource(AppConstants.successSoundPath));
    } catch (e) {
      // Fallback a sonido del sistema
      _playSystemSound(SystemSoundType.click);
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error reproduciendo sonido de éxito: $e');
      }
    }
  }

  /// Reproduce sonido de error
  Future<void> playErrorSound() async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.stop(); // Detener cualquier sonido anterior
      await _audioPlayer.play(AssetSource(AppConstants.errorSoundPath));
    } catch (e) {
      // Fallback a sonido del sistema
      _playSystemSound(SystemSoundType.alert);
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error reproduciendo sonido de error: $e');
      }
    }
  }

  /// Reproduce un sonido personalizado
  Future<void> playCustomSound(String soundPath) async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      _playSystemSound(SystemSoundType.click);
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error reproduciendo sonido personalizado: $e');
      }
    }
  }

  /// Reproduce sonido del sistema como fallback
  void _playSystemSound(SystemSoundType soundType) {
    try {
      SystemSound.play(soundType);
    } catch (e) {
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error reproduciendo sonido del sistema: $e');
      }
    }
  }

  /// Establece el volumen del audio
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    
    // Guardar configuración
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.volumeKey, _volume);
  }

  /// Habilita o deshabilita el sonido
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    
    // Guardar configuración
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  /// Detiene cualquier sonido en reproducción
  Future<void> stopAllSounds() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error deteniendo sonidos: $e');
      }
    }
  }

  /// Prueba los sonidos del sistema
  Future<void> testSounds() async {
    if (!_soundEnabled) return;

    // Probar sonido de éxito
    await playSuccessSound();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Probar sonido de error
    await playErrorSound();
  }

  /// Reproduce feedback háptico
  void playHapticFeedback({required bool isSuccess}) {
    try {
      if (isSuccess) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error reproduciendo feedback háptico: $e');
      }
    }
  }

  /// Reproduce vibración de error más intensa
  void playErrorVibration() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error reproduciendo vibración de error: $e');
      }
    }
  }

  /// Reproduce secuencia de feedback para éxito
  Future<void> playSuccessFeedback() async {
    await playSuccessSound();
    playHapticFeedback(isSuccess: true);
  }

  /// Reproduce secuencia de feedback para error
  Future<void> playErrorFeedback() async {
    await playErrorSound();
    playErrorVibration();
  }

  /// Verifica si los archivos de audio existen
  Future<bool> checkAudioFiles() async {
    try {
      // Intentar cargar los archivos de audio para verificar que existen
      await _audioPlayer.setSource(AssetSource(AppConstants.successSoundPath));
      await _audioPlayer.setSource(AssetSource(AppConstants.errorSoundPath));
      return true;
    } catch (e) {
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Archivos de audio no encontrados: $e');
      }
      return false;
    }
  }

  /// Configura el modo de audio para diferentes escenarios
  Future<void> setAudioMode(AudioMode mode) async {
    switch (mode) {
      case AudioMode.silent:
        await setSoundEnabled(false);
        break;
      case AudioMode.normal:
        await setSoundEnabled(true);
        await setVolume(1.0);
        break;
      case AudioMode.quiet:
        await setSoundEnabled(true);
        await setVolume(0.3);
        break;
    }
  }

  // Getters
  double get volume => _volume;
  bool get soundEnabled => _soundEnabled;
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  /// Libera recursos del servicio de audio
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      if (AppConstants.enableLogging) {
        print('${AppConstants.logTag}: Error liberando recursos de audio: $e');
      }
    }
  }
}

/// Enum para diferentes modos de audio
enum AudioMode {
  silent,   // Sin sonido
  quiet,    // Volumen bajo
  normal,   // Volumen normal
}

/// Extensión para facilitar el uso del servicio de audio
extension AudioServiceExtension on AudioService {
  /// Método conveniente para reproducir sonido basado en resultado de validación
  Future<void> playValidationSound(bool isValid) async {
    if (isValid) {
      await playSuccessFeedback();
    } else {
      await playErrorFeedback();
    }
  }
} 