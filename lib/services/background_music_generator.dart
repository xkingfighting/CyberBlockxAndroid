import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Cyberpunk Background Music Generator
/// Generates procedural synthwave/cyberpunk ambient music
class BackgroundMusicGenerator {
  static final BackgroundMusicGenerator instance = BackgroundMusicGenerator._();
  BackgroundMusicGenerator._();

  final AudioPlayer _player = AudioPlayer();
  final int _sampleRate = 44100;

  bool _isPlaying = false;
  bool _isInitialized = false;
  double _volume = 0.5;

  // Music parameters
  double _bpm = 110;

  // Scale: A minor pentatonic for cyberpunk feel
  final List<int> _scale = [0, 3, 5, 7, 10]; // A, C, D, E, G
  final int _rootNote = 45; // A2

  // Patterns
  final List<int> _arpPattern = [0, 2, 4, 2, 1, 3, 4, 3];
  final List<int> _bassPattern = [0, 0, 3, 0, 5, 5, 3, 0];

  bool get isPlaying => _isPlaying;

  Future<void> init() async {
    // Configure audio context to allow mixing with sound effects
    await _player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none, // Don't request exclusive focus
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ));
    await _player.setReleaseMode(ReleaseMode.loop);
    _isInitialized = true;
  }

  void dispose() {
    _player.dispose();
  }

  Future<void> start() async {
    if (!_isInitialized || _isPlaying) return;

    try {
      _isPlaying = true;

      // Generate 8 bars of music (about 17 seconds at 110 BPM)
      final musicData = await compute(_generateMusicIsolate, _MusicParams(
        sampleRate: _sampleRate,
        bpm: _bpm,
        volume: _volume,
        scale: _scale,
        rootNote: _rootNote,
        arpPattern: _arpPattern,
        bassPattern: _bassPattern,
      ));

      if (_isPlaying) {
        await _player.setVolume(_volume);
        await _player.play(BytesSource(musicData));
      }
    } catch (e) {
      debugPrint('Failed to start background music: $e');
      _isPlaying = false;
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    await _player.stop();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    if (_isPlaying) {
      await _player.resume();
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  void setBPM(double bpm) {
    _bpm = bpm.clamp(80, 140);
  }
}

class _MusicParams {
  final int sampleRate;
  final double bpm;
  final double volume;
  final List<int> scale;
  final int rootNote;
  final List<int> arpPattern;
  final List<int> bassPattern;

  _MusicParams({
    required this.sampleRate,
    required this.bpm,
    required this.volume,
    required this.scale,
    required this.rootNote,
    required this.arpPattern,
    required this.bassPattern,
  });
}

// Run in isolate to avoid blocking UI
Uint8List _generateMusicIsolate(_MusicParams params) {
  final generator = _MusicGenerator(params);
  return generator.generate();
}

class _MusicGenerator {
  final _MusicParams params;

  _MusicGenerator(this.params);

  double _midiToFrequency(int midiNote) {
    return 440.0 * pow(2.0, (midiNote - 69) / 12.0);
  }

  Uint8List generate() {
    // Generate 8 bars (32 beats at 4/4)
    final beatsCount = 32;
    final beatDuration = 60.0 / params.bpm;
    final totalDuration = beatsCount * beatDuration;
    final frameCount = (totalDuration * params.sampleRate).toInt();

    final samples = Float32List(frameCount);

    // Generate each component
    _generateBass(samples, frameCount, beatDuration);
    _generatePad(samples, frameCount);
    _generateArp(samples, frameCount, beatDuration);

    // Normalize and apply master volume
    _normalize(samples);

    return _createWavFile(samples);
  }

  void _generateBass(Float32List samples, int frameCount, double beatDuration) {
    final bassVolume = params.volume * 0.35;
    var bassIndex = 0;
    var lastBassTime = 0.0;
    var phase = 0.0;

    for (var frame = 0; frame < frameCount; frame++) {
      final time = frame / params.sampleRate;

      // Change bass note every beat
      if (time - lastBassTime >= beatDuration) {
        bassIndex = (bassIndex + 1) % params.bassPattern.length;
        lastBassTime = time;
      }

      final noteOffset = params.bassPattern[bassIndex];
      final scaleIndex = noteOffset % params.scale.length;
      final octave = noteOffset ~/ params.scale.length;
      final midiNote = params.rootNote - 12 + params.scale[scaleIndex] + (octave * 12);
      final frequency = _midiToFrequency(midiNote);

      // Sub bass with harmonics
      final phaseInc = frequency / params.sampleRate;
      phase += phaseInc;
      if (phase > 1.0) phase -= 1.0;

      var sample = sin(phase * 2 * pi) * 0.7; // Fundamental
      sample += sin(phase * 4 * pi) * 0.2; // Second harmonic
      sample += sin(phase * pi) * 0.1; // Sub octave

      // Apply envelope
      final beatProgress = (time - lastBassTime) / beatDuration;
      final envelope = min(beatProgress * 10, 1.0) * (1.0 - beatProgress * 0.3);

      samples[frame] += (sample * envelope * bassVolume).clamp(-1.0, 1.0);
    }
  }

  void _generatePad(Float32List samples, int frameCount) {
    final padVolume = params.volume * 0.25;
    var lfoPhase = 0.0;
    final lfoRate = 0.2;

    // Chord: root, minor third, fifth
    final chordNotes = [
      params.rootNote,
      params.rootNote + 3,
      params.rootNote + 7,
      params.rootNote + 12,
    ];

    final phases = List<double>.filled(chordNotes.length, 0);

    for (var frame = 0; frame < frameCount; frame++) {
      // LFO for modulation
      lfoPhase += lfoRate / params.sampleRate;
      if (lfoPhase > 1.0) lfoPhase -= 1.0;
      final lfo = sin(lfoPhase * 2 * pi) * 0.5 + 0.5;

      var sample = 0.0;

      for (var i = 0; i < chordNotes.length; i++) {
        final freq = _midiToFrequency(chordNotes[i]);
        final detune = 1.0 + (i - 1.5) * 0.002; // Slight detuning

        phases[i] += freq * detune / params.sampleRate;
        if (phases[i] > 1.0) phases[i] -= 1.0;

        // Soft saw wave with reduced harmonics
        var osc = 0.0;
        for (var harmonic = 1; harmonic <= 8; harmonic++) {
          final h = harmonic.toDouble();
          final harmonicAmp = 1.0 / h * pow(0.8, h - 1);
          osc += sin(phases[i] * 2 * pi * h) * harmonicAmp;
        }

        sample += osc * 0.25;
      }

      // Apply LFO modulation
      sample *= (0.7 + lfo * 0.3);
      sample *= padVolume;

      samples[frame] += sample.clamp(-1.0, 1.0);
    }
  }

  void _generateArp(Float32List samples, int frameCount, double beatDuration) {
    final arpVolume = params.volume * 0.2;
    final arpDuration = beatDuration / 2; // Eighth notes
    var arpIndex = 0;
    var lastArpTime = 0.0;
    var phase = 0.0;

    for (var frame = 0; frame < frameCount; frame++) {
      final time = frame / params.sampleRate;

      // Change arp note every eighth note
      if (time - lastArpTime >= arpDuration) {
        arpIndex = (arpIndex + 1) % params.arpPattern.length;
        lastArpTime = time;
      }

      final patternValue = params.arpPattern[arpIndex];
      final scaleIndex = patternValue % params.scale.length;
      final octave = patternValue ~/ params.scale.length;
      final midiNote = params.rootNote + 12 + params.scale[scaleIndex] + (octave * 12);
      final frequency = _midiToFrequency(midiNote);

      // Square wave with PWM
      final phaseInc = frequency / params.sampleRate;
      phase += phaseInc;
      if (phase > 1.0) phase -= 1.0;

      final pwm = 0.3 + sin(time * 0.5) * 0.2;
      final square = sin(phase * 2 * pi) > pwm ? 1.0 : -1.0;

      // Add triangle for brightness
      final triangle = 2.0 * (2.0 * phase - 1.0).abs() - 1.0;

      var sample = square * 0.6 + triangle * 0.4;

      // Apply envelope
      final noteProgress = (time - lastArpTime) / arpDuration;
      final attack = min(noteProgress * 20, 1.0);
      final decay = exp(-noteProgress * 3);
      final envelope = attack * decay;

      sample *= envelope * arpVolume;

      samples[frame] += sample.clamp(-1.0, 1.0);
    }
  }

  void _normalize(Float32List samples) {
    // Find max amplitude
    var maxAmp = 0.0;
    for (final sample in samples) {
      if (sample.abs() > maxAmp) {
        maxAmp = sample.abs();
      }
    }

    // Normalize to prevent clipping
    if (maxAmp > 0.9) {
      final scale = 0.9 / maxAmp;
      for (var i = 0; i < samples.length; i++) {
        samples[i] *= scale;
      }
    }
  }

  Uint8List _createWavFile(Float32List samples) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = params.sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2;
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
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, params.sampleRate, Endian.little);
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

    // Audio data
    for (final sample in samples) {
      final intSample = (sample * 32767).clamp(-32768, 32767).toInt();
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}
