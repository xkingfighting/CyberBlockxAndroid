import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Supported languages
enum AppLanguage {
  system('system', 'System'),
  english('en', 'English'),
  simplifiedChinese('zh-Hans', '简体中文'),
  traditionalChinese('zh-Hant', '繁體中文'),
  japanese('ja', '日本語'),
  korean('ko', '한국어'),
  french('fr', 'Français'),
  german('de', 'Deutsch');

  final String code;
  final String displayName;

  const AppLanguage(this.code, this.displayName);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.system,
    );
  }
}

// Localization keys
enum L {
  // Menu
  gameTitle,
  startGame,
  settings,
  controls,
  leaderboard,
  quit,

  // Pause
  paused,
  resume,
  restart,
  mainMenu,

  // Game Over
  gameOver,
  finalScore,
  level,
  lines,
  maxCombo,
  time,
  playAgain,

  // HUD
  score,
  next,
  hold,
  combo,

  // Settings
  settingsTitle,
  visual,
  glowIntensity,
  glitchEffects,
  audio,
  soundEffects,
  volume,
  music,
  musicVolume,
  hapticFeedback,
  language,
  languageSettings,

  // Controls
  controlsTitle,
  moveLeft,
  moveRight,
  softDrop,
  hardDrop,
  rotateCW,
  rotateCCW,
  holdPiece,
  pause,

  // Leaderboard
  rank,
  playerName,
  noRecords,
  playToRecord,
  newHighScore,
  yourRank,
  enterName,
  submit,
  skip,

  // Controls screen
  touchControls,
  tips,
  tip1,
  tip2,
  tip3,

  // Pause
  tapToResume,
}

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  static LocalizationService get instance => _instance;
  LocalizationService._internal();

  static const _languageKey = 'app_language';

  AppLanguage _currentLanguage = AppLanguage.system;
  AppLanguage get currentLanguage => _currentLanguage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageKey) ?? 'system';
    _currentLanguage = AppLanguage.fromCode(code);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
    notifyListeners();
  }

  AppLanguage get _effectiveLanguage {
    if (_currentLanguage != AppLanguage.system) {
      return _currentLanguage;
    }

    // Get device language
    final locale = PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode;
    final scriptCode = locale.scriptCode;
    final countryCode = locale.countryCode;

    if (languageCode == 'zh') {
      if (scriptCode == 'Hans' || countryCode == 'CN') {
        return AppLanguage.simplifiedChinese;
      } else if (scriptCode == 'Hant' || countryCode == 'TW' || countryCode == 'HK') {
        return AppLanguage.traditionalChinese;
      }
      return AppLanguage.simplifiedChinese;
    } else if (languageCode == 'ja') {
      return AppLanguage.japanese;
    } else if (languageCode == 'ko') {
      return AppLanguage.korean;
    } else if (languageCode == 'fr') {
      return AppLanguage.french;
    } else if (languageCode == 'de') {
      return AppLanguage.german;
    }

    return AppLanguage.english;
  }

  String tr(L key) {
    final lang = _effectiveLanguage;
    final strings = _strings[lang] ?? _strings[AppLanguage.english]!;
    return strings[key] ?? key.name;
  }

  // Localized strings database
  static final Map<AppLanguage, Map<L, String>> _strings = {
    // English
    AppLanguage.english: {
      L.gameTitle: 'CYBER BLOCKX',
      L.startGame: 'START GAME',
      L.settings: 'SETTINGS',
      L.controls: 'CONTROLS',
      L.leaderboard: 'LEADERBOARD',
      L.quit: 'QUIT',
      L.paused: 'PAUSED',
      L.resume: 'RESUME',
      L.restart: 'RESTART',
      L.mainMenu: 'MAIN MENU',
      L.gameOver: 'GAME OVER',
      L.finalScore: 'Final Score',
      L.level: 'Level',
      L.lines: 'Lines',
      L.maxCombo: 'Max Combo',
      L.time: 'Time',
      L.playAgain: 'PLAY AGAIN',
      L.score: 'SCORE',
      L.next: 'NEXT',
      L.hold: 'HOLD',
      L.combo: 'COMBO',
      L.settingsTitle: 'SETTINGS',
      L.visual: 'VISUAL',
      L.glowIntensity: 'Glow Intensity',
      L.glitchEffects: 'Glitch Effects',
      L.audio: 'AUDIO',
      L.soundEffects: 'Sound Effects',
      L.volume: 'Volume',
      L.music: 'Music',
      L.musicVolume: 'Music Volume',
      L.hapticFeedback: 'Haptic Feedback',
      L.language: 'LANGUAGE',
      L.languageSettings: 'Language',
      L.controlsTitle: 'CONTROLS',
      L.moveLeft: 'Move Left',
      L.moveRight: 'Move Right',
      L.softDrop: 'Soft Drop',
      L.hardDrop: 'Hard Drop',
      L.rotateCW: 'Rotate CW',
      L.rotateCCW: 'Rotate CCW',
      L.holdPiece: 'Hold',
      L.pause: 'Pause',
      L.rank: 'Rank',
      L.playerName: 'Player',
      L.noRecords: 'No Records Yet',
      L.playToRecord: 'Play a game to set a record!',
      L.newHighScore: 'NEW HIGH SCORE',
      L.yourRank: 'Your Rank:',
      L.enterName: 'ENTER YOUR NAME',
      L.submit: 'SUBMIT',
      L.skip: 'SKIP',
      L.touchControls: 'Touch Controls',
      L.tips: 'Tips',
      L.tip1: 'Hold left/right buttons to move continuously',
      L.tip2: 'Use hard drop for quick placement',
      L.tip3: 'Hold piece to save for later',
      L.tapToResume: 'Tap RESUME to continue',
    },

    // Simplified Chinese
    AppLanguage.simplifiedChinese: {
      L.gameTitle: '赛博方块',
      L.startGame: '开始游戏',
      L.settings: '设置',
      L.controls: '操作说明',
      L.leaderboard: '排行榜',
      L.quit: '退出',
      L.paused: '暂停',
      L.resume: '继续',
      L.restart: '重新开始',
      L.mainMenu: '主菜单',
      L.gameOver: '游戏结束',
      L.finalScore: '最终得分',
      L.level: '等级',
      L.lines: '消除行数',
      L.maxCombo: '最大连击',
      L.time: '时间',
      L.playAgain: '再玩一次',
      L.score: '得分',
      L.next: '下一个',
      L.hold: '暂存',
      L.combo: '连击',
      L.settingsTitle: '设置',
      L.visual: '视觉',
      L.glowIntensity: '发光强度',
      L.glitchEffects: '故障效果',
      L.audio: '音频',
      L.soundEffects: '音效',
      L.volume: '音量',
      L.music: '音乐',
      L.musicVolume: '音乐音量',
      L.hapticFeedback: '触觉反馈',
      L.language: '语言',
      L.languageSettings: '语言设置',
      L.controlsTitle: '操作说明',
      L.moveLeft: '左移',
      L.moveRight: '右移',
      L.softDrop: '软降',
      L.hardDrop: '硬降',
      L.rotateCW: '顺时针旋转',
      L.rotateCCW: '逆时针旋转',
      L.holdPiece: '暂存',
      L.pause: '暂停',
      L.rank: '排名',
      L.playerName: '玩家',
      L.noRecords: '暂无记录',
      L.playToRecord: '开始游戏创建记录！',
      L.newHighScore: '新高分',
      L.yourRank: '你的排名：',
      L.enterName: '输入你的名字',
      L.submit: '提交',
      L.skip: '跳过',
      L.touchControls: '触摸操作',
      L.tips: '提示',
      L.tip1: '长按左/右按钮可连续移动',
      L.tip2: '使用硬降快速放置方块',
      L.tip3: '使用暂存保留方块稍后使用',
      L.tapToResume: '点击继续恢复游戏',
    },

    // Traditional Chinese
    AppLanguage.traditionalChinese: {
      L.gameTitle: '賽博方塊',
      L.startGame: '開始遊戲',
      L.settings: '設定',
      L.controls: '操作說明',
      L.leaderboard: '排行榜',
      L.quit: '退出',
      L.paused: '暫停',
      L.resume: '繼續',
      L.restart: '重新開始',
      L.mainMenu: '主選單',
      L.gameOver: '遊戲結束',
      L.finalScore: '最終得分',
      L.level: '等級',
      L.lines: '消除行數',
      L.maxCombo: '最大連擊',
      L.time: '時間',
      L.playAgain: '再玩一次',
      L.score: '得分',
      L.next: '下一個',
      L.hold: '暫存',
      L.combo: '連擊',
      L.settingsTitle: '設定',
      L.visual: '視覺',
      L.glowIntensity: '發光強度',
      L.glitchEffects: '故障效果',
      L.audio: '音訊',
      L.soundEffects: '音效',
      L.volume: '音量',
      L.music: '音樂',
      L.musicVolume: '音樂音量',
      L.hapticFeedback: '觸覺回饋',
      L.language: '語言',
      L.languageSettings: '語言設定',
      L.controlsTitle: '操作說明',
      L.moveLeft: '左移',
      L.moveRight: '右移',
      L.softDrop: '軟降',
      L.hardDrop: '硬降',
      L.rotateCW: '順時針旋轉',
      L.rotateCCW: '逆時針旋轉',
      L.holdPiece: '暫存',
      L.pause: '暫停',
      L.rank: '排名',
      L.playerName: '玩家',
      L.noRecords: '暫無記錄',
      L.playToRecord: '開始遊戲創建記錄！',
      L.newHighScore: '新高分',
      L.yourRank: '你的排名：',
      L.enterName: '輸入你的名字',
      L.submit: '提交',
      L.skip: '跳過',
      L.touchControls: '觸控操作',
      L.tips: '提示',
      L.tip1: '長按左/右按鈕可連續移動',
      L.tip2: '使用硬降快速放置方塊',
      L.tip3: '使用暫存保留方塊稍後使用',
      L.tapToResume: '點擊繼續恢復遊戲',
    },

    // Japanese
    AppLanguage.japanese: {
      L.gameTitle: 'サイバーブロック',
      L.startGame: 'ゲーム開始',
      L.settings: '設定',
      L.controls: '操作方法',
      L.leaderboard: 'ランキング',
      L.quit: '終了',
      L.paused: '一時停止',
      L.resume: '再開',
      L.restart: 'リスタート',
      L.mainMenu: 'メインメニュー',
      L.gameOver: 'ゲームオーバー',
      L.finalScore: '最終スコア',
      L.level: 'レベル',
      L.lines: 'ライン数',
      L.maxCombo: '最大コンボ',
      L.time: '時間',
      L.playAgain: 'もう一度',
      L.score: 'スコア',
      L.next: '次',
      L.hold: 'ホールド',
      L.combo: 'コンボ',
      L.settingsTitle: '設定',
      L.visual: 'ビジュアル',
      L.glowIntensity: 'グロー強度',
      L.glitchEffects: 'グリッチ効果',
      L.audio: 'オーディオ',
      L.soundEffects: '効果音',
      L.volume: '音量',
      L.music: '音楽',
      L.musicVolume: '音楽音量',
      L.hapticFeedback: '触覚フィードバック',
      L.language: '言語',
      L.languageSettings: '言語設定',
      L.controlsTitle: '操作方法',
      L.moveLeft: '左移動',
      L.moveRight: '右移動',
      L.softDrop: 'ソフトドロップ',
      L.hardDrop: 'ハードドロップ',
      L.rotateCW: '右回転',
      L.rotateCCW: '左回転',
      L.holdPiece: 'ホールド',
      L.pause: '一時停止',
      L.rank: '順位',
      L.playerName: 'プレイヤー',
      L.noRecords: '記録なし',
      L.playToRecord: 'ゲームをプレイして記録を作ろう！',
      L.newHighScore: 'ハイスコア更新',
      L.yourRank: 'あなたの順位：',
      L.enterName: '名前を入力',
      L.submit: '登録',
      L.skip: 'スキップ',
      L.touchControls: 'タッチ操作',
      L.tips: 'ヒント',
      L.tip1: '左/右ボタンを長押しで連続移動',
      L.tip2: 'ハードドロップで素早く配置',
      L.tip3: 'ホールドでピースを保持',
      L.tapToResume: '再開をタップして続ける',
    },

    // Korean
    AppLanguage.korean: {
      L.gameTitle: '사이버 블록',
      L.startGame: '게임 시작',
      L.settings: '설정',
      L.controls: '조작법',
      L.leaderboard: '랭킹',
      L.quit: '종료',
      L.paused: '일시정지',
      L.resume: '계속',
      L.restart: '다시 시작',
      L.mainMenu: '메인 메뉴',
      L.gameOver: '게임 오버',
      L.finalScore: '최종 점수',
      L.level: '레벨',
      L.lines: '라인',
      L.maxCombo: '최대 콤보',
      L.time: '시간',
      L.playAgain: '다시 플레이',
      L.score: '점수',
      L.next: '다음',
      L.hold: '홀드',
      L.combo: '콤보',
      L.settingsTitle: '설정',
      L.visual: '비주얼',
      L.glowIntensity: '글로우 강도',
      L.glitchEffects: '글리치 효과',
      L.audio: '오디오',
      L.soundEffects: '효과음',
      L.volume: '볼륨',
      L.music: '음악',
      L.musicVolume: '음악 볼륨',
      L.hapticFeedback: '햅틱 피드백',
      L.language: '언어',
      L.languageSettings: '언어 설정',
      L.controlsTitle: '조작법',
      L.moveLeft: '왼쪽 이동',
      L.moveRight: '오른쪽 이동',
      L.softDrop: '소프트 드롭',
      L.hardDrop: '하드 드롭',
      L.rotateCW: '시계방향 회전',
      L.rotateCCW: '반시계방향 회전',
      L.holdPiece: '홀드',
      L.pause: '일시정지',
      L.rank: '순위',
      L.playerName: '플레이어',
      L.noRecords: '기록 없음',
      L.playToRecord: '게임을 플레이하여 기록을 세우세요!',
      L.newHighScore: '신기록',
      L.yourRank: '당신의 순위:',
      L.enterName: '이름 입력',
      L.submit: '등록',
      L.skip: '건너뛰기',
      L.touchControls: '터치 조작',
      L.tips: '팁',
      L.tip1: '왼쪽/오른쪽 버튼을 길게 눌러 연속 이동',
      L.tip2: '하드 드롭으로 빠르게 배치',
      L.tip3: '홀드로 블록을 나중에 사용',
      L.tapToResume: '계속을 눌러 재개',
    },

    // French
    AppLanguage.french: {
      L.gameTitle: 'CYBER BLOCKX',
      L.startGame: 'COMMENCER',
      L.settings: 'PARAMÈTRES',
      L.controls: 'CONTRÔLES',
      L.leaderboard: 'CLASSEMENT',
      L.quit: 'QUITTER',
      L.paused: 'PAUSE',
      L.resume: 'REPRENDRE',
      L.restart: 'RECOMMENCER',
      L.mainMenu: 'MENU PRINCIPAL',
      L.gameOver: 'FIN DE PARTIE',
      L.finalScore: 'Score Final',
      L.level: 'Niveau',
      L.lines: 'Lignes',
      L.maxCombo: 'Combo Max',
      L.time: 'Temps',
      L.playAgain: 'REJOUER',
      L.score: 'SCORE',
      L.next: 'SUIVANT',
      L.hold: 'RÉSERVE',
      L.combo: 'COMBO',
      L.settingsTitle: 'PARAMÈTRES',
      L.visual: 'VISUEL',
      L.glowIntensity: 'Intensité du halo',
      L.glitchEffects: 'Effets glitch',
      L.audio: 'AUDIO',
      L.soundEffects: 'Effets sonores',
      L.volume: 'Volume',
      L.music: 'Musique',
      L.musicVolume: 'Volume musique',
      L.hapticFeedback: 'Retour haptique',
      L.language: 'LANGUE',
      L.languageSettings: 'Langue',
      L.controlsTitle: 'CONTRÔLES',
      L.moveLeft: 'Gauche',
      L.moveRight: 'Droite',
      L.softDrop: 'Descente douce',
      L.hardDrop: 'Descente rapide',
      L.rotateCW: 'Rotation horaire',
      L.rotateCCW: 'Rotation anti-horaire',
      L.holdPiece: 'Réserve',
      L.pause: 'Pause',
      L.rank: 'Rang',
      L.playerName: 'Joueur',
      L.noRecords: 'Aucun record',
      L.playToRecord: 'Jouez pour établir un record!',
      L.newHighScore: 'NOUVEAU RECORD',
      L.yourRank: 'Votre rang:',
      L.enterName: 'ENTREZ VOTRE NOM',
      L.submit: 'VALIDER',
      L.skip: 'PASSER',
      L.touchControls: 'Contrôles tactiles',
      L.tips: 'Conseils',
      L.tip1: 'Maintenez les boutons gauche/droite pour un déplacement continu',
      L.tip2: 'Utilisez la descente rapide pour un placement rapide',
      L.tip3: 'Gardez une pièce en réserve pour plus tard',
      L.tapToResume: 'Appuyez sur REPRENDRE pour continuer',
    },

    // German
    AppLanguage.german: {
      L.gameTitle: 'CYBER BLOCKX',
      L.startGame: 'SPIEL STARTEN',
      L.settings: 'EINSTELLUNGEN',
      L.controls: 'STEUERUNG',
      L.leaderboard: 'RANGLISTE',
      L.quit: 'BEENDEN',
      L.paused: 'PAUSIERT',
      L.resume: 'FORTSETZEN',
      L.restart: 'NEUSTART',
      L.mainMenu: 'HAUPTMENÜ',
      L.gameOver: 'SPIEL VORBEI',
      L.finalScore: 'Endpunktzahl',
      L.level: 'Level',
      L.lines: 'Linien',
      L.maxCombo: 'Max Kombo',
      L.time: 'Zeit',
      L.playAgain: 'NOCHMAL',
      L.score: 'PUNKTE',
      L.next: 'NÄCHSTES',
      L.hold: 'HALTEN',
      L.combo: 'KOMBO',
      L.settingsTitle: 'EINSTELLUNGEN',
      L.visual: 'VISUELL',
      L.glowIntensity: 'Leuchtintensität',
      L.glitchEffects: 'Glitch-Effekte',
      L.audio: 'AUDIO',
      L.soundEffects: 'Soundeffekte',
      L.volume: 'Lautstärke',
      L.music: 'Musik',
      L.musicVolume: 'Musiklautstärke',
      L.hapticFeedback: 'Haptisches Feedback',
      L.language: 'SPRACHE',
      L.languageSettings: 'Sprache',
      L.controlsTitle: 'STEUERUNG',
      L.moveLeft: 'Links',
      L.moveRight: 'Rechts',
      L.softDrop: 'Sanftes Fallen',
      L.hardDrop: 'Schnelles Fallen',
      L.rotateCW: 'Im Uhrzeigersinn',
      L.rotateCCW: 'Gegen Uhrzeigersinn',
      L.holdPiece: 'Halten',
      L.pause: 'Pause',
      L.rank: 'Rang',
      L.playerName: 'Spieler',
      L.noRecords: 'Keine Rekorde',
      L.playToRecord: 'Spiele um einen Rekord aufzustellen!',
      L.newHighScore: 'NEUER HIGHSCORE',
      L.yourRank: 'Dein Rang:',
      L.enterName: 'NAME EINGEBEN',
      L.submit: 'BESTÄTIGEN',
      L.skip: 'ÜBERSPRINGEN',
      L.touchControls: 'Touch-Steuerung',
      L.tips: 'Tipps',
      L.tip1: 'Halten Sie die Links/Rechts-Tasten für kontinuierliche Bewegung',
      L.tip2: 'Nutzen Sie schnelles Fallen für schnelle Platzierung',
      L.tip3: 'Halten Sie ein Teil für später bereit',
      L.tapToResume: 'Drücken Sie FORTSETZEN um weiterzuspielen',
    },
  };
}

// Convenience extension
extension LocalizationExtension on L {
  String get tr => LocalizationService.instance.tr(this);
}
