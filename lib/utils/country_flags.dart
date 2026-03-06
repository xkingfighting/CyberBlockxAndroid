/// Convert ISO 3166-1 Alpha-2 country code to emoji flag.
///
/// Uses Unicode Regional Indicator Symbols:
/// Each letter is mapped to its regional indicator (🇦 = U+1F1E6, etc.)
/// Two regional indicators together form a flag emoji.
///
/// Example: "US" → 🇺🇸, "CN" → 🇨🇳, "JP" → 🇯🇵
String countryCodeToEmoji(String countryCode) {
  if (countryCode.length != 2) return '🏳️';

  final code = countryCode.toUpperCase();
  final first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;

  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// Get country name from ISO code (common countries)
String countryCodeToName(String countryCode) {
  return _countryNames[countryCode.toUpperCase()] ?? countryCode.toUpperCase();
}

const Map<String, String> _countryNames = {
  'US': 'United States',
  'CN': 'China',
  'JP': 'Japan',
  'KR': 'South Korea',
  'GB': 'United Kingdom',
  'DE': 'Germany',
  'FR': 'France',
  'BR': 'Brazil',
  'IN': 'India',
  'RU': 'Russia',
  'CA': 'Canada',
  'AU': 'Australia',
  'MX': 'Mexico',
  'ES': 'Spain',
  'IT': 'Italy',
  'TW': 'Taiwan',
  'HK': 'Hong Kong',
  'SG': 'Singapore',
  'TH': 'Thailand',
  'VN': 'Vietnam',
  'PH': 'Philippines',
  'ID': 'Indonesia',
  'MY': 'Malaysia',
  'TR': 'Turkey',
  'PL': 'Poland',
  'NL': 'Netherlands',
  'SE': 'Sweden',
  'NO': 'Norway',
  'FI': 'Finland',
  'DK': 'Denmark',
  'AR': 'Argentina',
  'CL': 'Chile',
  'CO': 'Colombia',
  'PE': 'Peru',
  'ZA': 'South Africa',
  'NG': 'Nigeria',
  'EG': 'Egypt',
  'SA': 'Saudi Arabia',
  'AE': 'UAE',
  'IL': 'Israel',
  'UA': 'Ukraine',
  'CZ': 'Czech Republic',
  'AT': 'Austria',
  'CH': 'Switzerland',
  'PT': 'Portugal',
  'IE': 'Ireland',
  'NZ': 'New Zealand',
};
