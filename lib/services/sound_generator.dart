import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Cyberpunk Sound Effect Generator
/// Generates procedural synthesized sound effects matching the cyberpunk/synthwave aesthetic
class SoundGenerator {
  static final SoundGenerator instance = SoundGenerator._();
  SoundGenerator._();

  // Use a pool of audio players for concurrent sounds
  final List<AudioPlayer> _playerPool = [];
  static const _poolSize = 4;
  int _currentPlayerIndex = 0;

  final int _sampleRate = 44100;
  bool _isInitialized = false;

  // Rate limiting to prevent audio overload
  DateTime _lastSoundTime = DateTime.now();
  static const _minSoundInterval = Duration(milliseconds: 25);

  Future<void> init() async {
    // Create a pool of audio players
    for (int i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      // Configure to not request audio focus (don't interrupt music)
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none, // Don't request focus
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
      await player.setReleaseMode(ReleaseMode.stop);
      _playerPool.add(player);
    }
    _isInitialized = true;
  }

  AudioPlayer get _player {
    final player = _playerPool[_currentPlayerIndex];
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _poolSize;
    return player;
  }

  void dispose() {
    for (final player in _playerPool) {
      player.dispose();
    }
    _playerPool.clear();
  }

  // MARK: - Public Sound Methods

  Future<void> playMove(double volume) async {
    // Quick high-pitched cyberpunk blip
    await _playSynthSound(
      frequencies: [880, 1320],
      durations: [0.03, 0.02],
      waveform: Waveform.sine,
      envelope: Envelope.sharp,
      volume: volume * 0.4,
    );
  }

  Future<void> playRotate(double volume) async {
    // Frequency sweep with electronic character
    await _playSweep(
      startFreq: 400,
      endFreq: 1200,
      duration: 0.08,
      waveform: Waveform.triangle,
      volume: volume * 0.5,
    );
  }

  Future<void> playDrop(double volume) async {
    // Bass impact with noise burst for hard drop (audible on phone speakers)
    await _playDropSound(volume * 0.7);
  }

  Future<void> playLock(double volume) async {
    // Solid "click" when piece locks into place with digital click
    await _playLockSound(volume * 0.5);
  }

  // Custom drop sound with bass + noise burst for phone speaker audibility
  Future<void> _playDropSound(double volume) async {
    if (!_isInitialized) return;

    // Rate limiting
    final now = DateTime.now();
    if (now.difference(_lastSoundTime) < _minSoundInterval) return;
    _lastSoundTime = now;

    try {
      const duration = 0.15;
      final frameCount = (duration * _sampleRate).toInt();
      final samples = Float32List(frameCount);
      final random = Random();
      var bassPhase = 0.0;

      for (var frame = 0; frame < frameCount; frame++) {
        final time = frame / _sampleRate;
        final normalizedTime = time / duration;

        // Bass component (80Hz -> 40Hz sweep)
        final bassFreq = 80 - normalizedTime * 40;
        bassPhase += bassFreq / _sampleRate;
        if (bassPhase > 1.0) bassPhase -= 1.0;
        var bassSample = sin(bassPhase * 2 * pi);

        // Noise burst for impact (high frequencies audible on phone speakers)
        final noise = (random.nextDouble() * 2 - 1);

        // Punch envelope - very fast attack, quick decay
        final attack = min(normalizedTime * 100, 1.0);
        final decay = pow(1.0 - normalizedTime, 3).toDouble();
        final envelope = attack * decay;

        // Mix bass and noise
        final sample = (bassSample * 0.6 + noise * 0.4) * envelope * volume;
        samples[frame] = sample.clamp(-1.0, 1.0);
      }

      await _playBuffer(samples);
    } catch (e) {
      debugPrint('Failed to play drop sound: $e');
    }
  }

  // Custom lock sound with bass + digital click for better audibility
  Future<void> _playLockSound(double volume) async {
    if (!_isInitialized) return;

    // Rate limiting
    final now = DateTime.now();
    if (now.difference(_lastSoundTime) < _minSoundInterval) return;
    _lastSoundTime = now;

    try {
      const duration = 0.08;
      final frameCount = (duration * _sampleRate).toInt();
      final samples = Float32List(frameCount);
      var bassPhase = 0.0;
      var clickPhase = 0.0;

      for (var frame = 0; frame < frameCount; frame++) {
        final time = frame / _sampleRate;
        final normalizedTime = time / duration;

        // Low thud (120Hz -> 80Hz)
        final bassFreq = 120 - normalizedTime * 40;
        bassPhase += bassFreq / _sampleRate;
        if (bassPhase > 1.0) bassPhase -= 1.0;
        var bassSample = sin(bassPhase * 2 * pi);

        // High frequency click (1000Hz, audible on phone speakers)
        final clickFreq = 1000.0;
        clickPhase += clickFreq / _sampleRate;
        if (clickPhase > 1.0) clickPhase -= 1.0;
        var clickSample = sin(clickPhase * 2 * pi);

        // Punch envelope for bass
        final bassEnvelope = min(normalizedTime * 100, 1.0) * pow(1.0 - normalizedTime, 3);
        // Sharp envelope for click (very fast decay)
        final clickEnvelope = min(normalizedTime * 100, 1.0) * pow(1.0 - normalizedTime, 5);

        // Mix bass and click
        final sample = (bassSample * bassEnvelope * 0.6 + clickSample * clickEnvelope * 0.4) * volume;
        samples[frame] = sample.clamp(-1.0, 1.0);
      }

      await _playBuffer(samples);
    } catch (e) {
      debugPrint('Failed to play lock sound: $e');
    }
  }

  Future<void> playLineClear(double volume) async {
    // Satisfying electronic "whoosh" with multiple layers
    await _playSweep(
      startFreq: 200,
      endFreq: 1800,
      duration: 0.25,
      waveform: Waveform.saw,
      volume: volume * 0.6,
    );
  }

  Future<void> playTetris(double volume) async {
    // Epic 4-line clear - arpeggio chord
    final notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        _playSynthSound(
          frequencies: [notes[i], notes[i] * 1.5],
          durations: [0.15, 0.1],
          waveform: Waveform.square,
          envelope: Envelope.soft,
          volume: volume * 0.35,
        );
      });
    }
  }

  Future<void> playLevelUp(double volume) async {
    // Ascending celebratory tones
    final notes = [440.0, 554.37, 659.25, 880.0]; // A4, C#5, E5, A5
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        _playSynthSound(
          frequencies: [notes[i]],
          durations: [0.12],
          waveform: Waveform.triangle,
          envelope: Envelope.soft,
          volume: volume * 0.5,
        );
      });
    }
  }

  Future<void> playGameOver(double volume) async {
    // Dramatic descending sweep
    await _playSweep(
      startFreq: 500,
      endFreq: 100,
      duration: 0.5,
      waveform: Waveform.triangle,
      volume: volume * 0.25,
    );
  }

  Future<void> playHold(double volume) async {
    // Two-tone confirmation blip
    await _playSynthSound(
      frequencies: [660],
      durations: [0.04],
      waveform: Waveform.square,
      envelope: Envelope.sharp,
      volume: volume * 0.35,
    );
    Future.delayed(const Duration(milliseconds: 50), () {
      _playSynthSound(
        frequencies: [880],
        durations: [0.06],
        waveform: Waveform.square,
        envelope: Envelope.sharp,
        volume: volume * 0.35,
      );
    });
  }

  Future<void> playCombo(double volume) async {
    // Rising tone for combo (pitch increases with excitement)
    await _playSynthSound(
      frequencies: [440, 550, 660],
      durations: [0.06, 0.06, 0.08],
      waveform: Waveform.triangle,
      envelope: Envelope.soft,
      volume: volume * 0.4,
    );
  }

  Future<void> playPerfectClear(double volume) async {
    // Epic celebration sound for perfect clear
    final notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]; // C5, E5, G5, C6, E6
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        _playSynthSound(
          frequencies: [notes[i]],
          durations: [0.2],
          waveform: Waveform.triangle,
          envelope: Envelope.soft,
          volume: volume * 0.5,
        );
      });
    }
    // Add shimmering sweep
    Future.delayed(const Duration(milliseconds: 100), () {
      _playSweep(
        startFreq: 500,
        endFreq: 2500,
        duration: 0.4,
        waveform: Waveform.sine,
        volume: volume * 0.3,
      );
    });
  }

  // MARK: - Sound Synthesis Core

  Future<void> _playSynthSound({
    required List<double> frequencies,
    required List<double> durations,
    required Waveform waveform,
    required Envelope envelope,
    required double volume,
  }) async {
    if (!_isInitialized) return;

    // Rate limiting
    final now = DateTime.now();
    if (now.difference(_lastSoundTime) < _minSoundInterval) return;
    _lastSoundTime = now;

    try {
      final totalDuration = durations.reduce((a, b) => a + b);
      final frameCount = (totalDuration * _sampleRate).toInt();
      final samples = Float32List(frameCount);

      var currentFrame = 0;
      var phase = 0.0;

      for (var i = 0; i < frequencies.length; i++) {
        final freq = frequencies[i];
        final segmentFrames = (durations[i] * _sampleRate).toInt();
        final segmentDuration = durations[i];

        for (var frame = 0; frame < segmentFrames && currentFrame < frameCount; frame++) {
          final time = frame / _sampleRate;
          final normalizedTime = time / segmentDuration;

          // Generate waveform
          final phaseIncrement = freq / _sampleRate;
          phase += phaseIncrement;
          if (phase > 1.0) phase -= 1.0;

          var sample = _generateWaveform(phase, waveform);

          // Apply envelope
          final env = _generateEnvelope(normalizedTime, envelope);
          sample *= env * volume;

          samples[currentFrame] = sample.clamp(-1.0, 1.0);
          currentFrame++;
        }
      }

      await _playBuffer(samples);
    } catch (e) {
      debugPrint('Failed to play synth sound: $e');
    }
  }

  Future<void> _playSweep({
    required double startFreq,
    required double endFreq,
    required double duration,
    required Waveform waveform,
    required double volume,
  }) async {
    if (!_isInitialized) return;

    // Rate limiting
    final now = DateTime.now();
    if (now.difference(_lastSoundTime) < _minSoundInterval) return;
    _lastSoundTime = now;

    try {
      final frameCount = (duration * _sampleRate).toInt();
      final samples = Float32List(frameCount);
      var phase = 0.0;

      for (var frame = 0; frame < frameCount; frame++) {
        final time = frame / _sampleRate;
        final normalizedTime = time / duration;

        // Exponential frequency sweep
        final freq = startFreq * pow(endFreq / startFreq, normalizedTime);

        final phaseIncrement = freq / _sampleRate;
        phase += phaseIncrement;
        if (phase > 1.0) phase -= 1.0;

        var sample = _generateWaveform(phase, waveform);

        // Envelope: fade in quickly, fade out at end
        final env = min(normalizedTime * 10, 1.0) * (1.0 - pow(normalizedTime, 2));
        sample *= env * volume;

        samples[frame] = sample.clamp(-1.0, 1.0);
      }

      await _playBuffer(samples);
    } catch (e) {
      debugPrint('Failed to play sweep: $e');
    }
  }

  // MARK: - Waveform Generators

  double _generateWaveform(double phase, Waveform type) {
    switch (type) {
      case Waveform.sine:
        return sin(phase * 2 * pi);
      case Waveform.square:
        // Softened square wave to reduce harshness
        final sine = sin(phase * 2 * pi);
        return sine > 0 ? 0.8 : -0.8;
      case Waveform.triangle:
        return 2.0 * (2.0 * phase - 1.0).abs() - 1.0;
      case Waveform.saw:
        // Band-limited saw approximation
        var saw = 0.0;
        for (var harmonic = 1; harmonic <= 6; harmonic++) {
          final h = harmonic.toDouble();
          saw += sin(phase * 2 * pi * h) / h;
        }
        return saw * 0.5;
    }
  }

  double _generateEnvelope(double normalizedTime, Envelope type) {
    switch (type) {
      case Envelope.sharp:
        final attack = min(normalizedTime * 50, 1.0);
        final decay = pow(1.0 - normalizedTime, 2);
        return attack * decay;
      case Envelope.soft:
        final attack = min(normalizedTime * 10, 1.0);
        final decay = pow(1.0 - normalizedTime, 1.5);
        return attack * decay;
      case Envelope.punch:
        final attack = min(normalizedTime * 100, 1.0);
        final decay = pow(1.0 - normalizedTime, 3);
        return attack * decay;
      case Envelope.slow:
        final attack = min(normalizedTime * 5, 1.0);
        final decay = pow(1.0 - normalizedTime, 0.8);
        return attack * decay;
    }
  }

  // MARK: - Buffer Playback

  Future<void> _playBuffer(Float32List samples) async {
    try {
      // Convert to 16-bit PCM WAV format
      final wavData = _createWavFile(samples);
      final source = BytesSource(wavData);
      await _player.play(source);
    } catch (e) {
      debugPrint('Failed to play buffer: $e');
    }
  }

  Uint8List _createWavFile(Float32List samples) {
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = _sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt subchunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // space
    buffer.setUint32(offset, 16, Endian.little); // Subchunk1Size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // AudioFormat (PCM)
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data subchunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Audio data (convert float to 16-bit PCM)
    for (final sample in samples) {
      final intSample = (sample * 32767).clamp(-32768, 32767).toInt();
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}

enum Waveform { sine, square, triangle, saw }
enum Envelope { sharp, soft, punch, slow }
