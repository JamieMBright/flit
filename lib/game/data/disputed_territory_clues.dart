/// Clue data for disputed, partially recognised, and de facto territories.
///
/// These territories are included for educational purposes, presenting
/// factual geographic and political information in a neutral, balanced way.
library;

class DisputedTerritoryClueData {
  const DisputedTerritoryClueData({
    required this.disputeDescription,
    required this.parties,
    required this.recognitionStatus,
    required this.nickname,
    required this.famousLandmark,
    required this.flag,
  });

  /// A brief, neutral description of the territorial dispute.
  final String disputeDescription;

  /// The parties involved in the dispute (e.g. 'Taiwan vs. PRC').
  final String parties;

  /// Current international recognition status.
  final String recognitionStatus;

  /// Common nickname or informal name.
  final String nickname;

  /// A notable landmark or geographic feature.
  final String famousLandmark;

  /// Description of the territory's flag for quiz use.
  final String flag;
}

abstract class DisputedTerritoryClues {
  static const Map<String, DisputedTerritoryClueData> data = {
    // =========================================================================
    // TIER 1: Active De Facto States
    // =========================================================================
    'TW': DisputedTerritoryClueData(
      disputeDescription:
          'Both this island democracy and the People\'s Republic of China '
          'claim to be the legitimate government of "China". Self-governing '
          'since 1949, it has its own military, currency, and democratic '
          'elections, but is recognised by only about a dozen UN member states.',
      parties: 'Republic of China (Taiwan) vs. People\'s Republic of China',
      recognitionStatus: 'Recognised by ~12 UN member states',
      nickname: 'Ilha Formosa',
      famousLandmark: 'Taipei 101',
      flag: 'A red field bearing a white sun on a blue canton — the "Blue Sky, '
          'White Sun, and a Wholly Red Earth" — designed in 1928 and symbolising '
          'the Three Principles of the People: nationalism, democracy, and '
          'livelihood of the people.',
    ),
    'PS': DisputedTerritoryClueData(
      disputeDescription:
          'This territory encompasses the West Bank and Gaza Strip, claimed as '
          'a sovereign state with East Jerusalem as its capital. A two-state '
          'solution has been sought for decades but remains unresolved.',
      parties: 'Palestinian Authority vs. Israel',
      recognitionStatus:
          'Recognised by 146 UN member states; UN observer state',
      nickname: 'The Holy Land',
      famousLandmark: 'Dome of the Rock',
      flag: 'Three horizontal stripes of black, white, and green with a red '
          'triangle at the hoist — the Pan-Arab colours representing the '
          'Abbasid, Umayyad, and Fatimid dynasties, united by the red '
          'triangle symbolising the Hashemite dynasty.',
    ),
    'XK': DisputedTerritoryClueData(
      disputeDescription:
          'This territory declared independence in 2008 after NATO intervention '
          'ended a 1998–99 conflict. Its former sovereign, backed by Russia and '
          'China, still considers it an integral part of its territory.',
      parties: 'Kosovo vs. Serbia',
      recognitionStatus: 'Recognised by 101 UN member states',
      nickname: 'The Young Europeans',
      famousLandmark: 'Gračanica Monastery',
      flag: 'A blue field bearing a gold silhouette map of the territory below '
          'six white stars representing its six major ethnic communities — '
          'designed to be ethnically neutral, deliberately avoiding the '
          'Albanian eagle or Serbian cross.',
    ),
    'EH': DisputedTerritoryClueData(
      disputeDescription:
          'This former Spanish colony in northwest Africa has been contested '
          'since 1975. One party administers about 80% of the territory while '
          'a liberation front controls the rest from exile. A UN-promised '
          'independence referendum has never been held.',
      parties: 'SADR / Polisario Front vs. Morocco',
      recognitionStatus:
          'Recognised by 46 UN member states; African Union member',
      nickname: 'Africa\'s Last Colony',
      famousLandmark: 'The Berm — a 2,700 km sand wall dividing the territory',
      flag:
          'Black, white, and green horizontal stripes with a red crescent and '
          'star on a red triangle at the hoist — Pan-Arab colours shared with '
          'the Palestinian and Jordanian flags, reflecting solidarity with '
          'the broader Arab independence movement.',
    ),
    'NC': DisputedTerritoryClueData(
      disputeDescription:
          'The northern third of a Mediterranean island has been under Turkish '
          'military control since 1974. It declared independence in 1983 but '
          'is recognised only by Turkey. The southern Republic is an EU member '
          'and claims sovereignty over the entire island.',
      parties: 'Turkish Republic of Northern Cyprus vs. Republic of Cyprus',
      recognitionStatus: 'Recognised only by Turkey',
      nickname: 'The TRNC',
      famousLandmark: 'Kyrenia Castle',
      flag:
          'A white field with a red crescent and star flanked by two horizontal '
          'red stripes — an inversion of the Turkish flag, deliberately echoing '
          'the relationship with its sole recognising state while maintaining '
          'a distinct identity.',
    ),
    'SL': DisputedTerritoryClueData(
      disputeDescription:
          'This northwest African territory declared independence in 1991 '
          'after the collapse of its parent state. It has maintained stable '
          'democratic governance for over 30 years with peaceful transfers of '
          'power, but has almost no international recognition.',
      parties: 'Republic of Somaliland vs. Federal Republic of Somalia',
      recognitionStatus: 'Recognised by Israel (2025); no other UN member',
      nickname: 'The Horn\'s Hidden Democracy',
      famousLandmark: 'Laas Geel cave paintings',
      flag:
          'Three horizontal stripes of green (bearing the Shahada), white, and '
          'red, with a black star on the white stripe — the green represents '
          'Islam and prosperity, white represents peace, and red represents '
          'the blood of those who fought for independence.',
    ),
    'TR': DisputedTerritoryClueData(
      disputeDescription:
          'A narrow strip of land east of the Dniester River that broke away '
          'from its parent state in 1990 with Russian military backing. It has '
          'operated as a de facto independent state for over 30 years with '
          'Russian troops present, but is recognised by no UN member state.',
      parties: 'Pridnestrovian Moldavian Republic vs. Moldova',
      recognitionStatus: 'Recognised by no UN member state',
      nickname: 'The Last Soviet Republic',
      famousLandmark: 'Bender Fortress',
      flag: 'A red field with a green horizontal stripe and a gold hammer and '
          'sickle with a star — the only territory outside Russia still using '
          'Soviet-era symbolism on its flag, reflecting its nostalgia for the '
          'USSR and its resistance to post-Soviet reforms.',
    ),
    'AB': DisputedTerritoryClueData(
      disputeDescription:
          'This Black Sea coastal territory broke from its parent state in a '
          '1992–93 war with Russian support. It was formally recognised by '
          'Russia after a brief 2008 war, but most of the world considers it '
          'occupied territory.',
      parties: 'Abkhazia vs. Georgia',
      recognitionStatus:
          'Recognised by Russia, Nicaragua, Venezuela, Syria, North Korea',
      nickname: 'The Land of the Soul',
      famousLandmark: 'New Athos Monastery',
      flag:
          'Seven green and white alternating stripes with a red canton bearing '
          'an open white hand and seven stars — the hand represents the '
          'Abkhazian greeting "welcome", while the seven stripes and stars '
          'represent the seven historic regions of Abkhazia.',
    ),
    'SO': DisputedTerritoryClueData(
      disputeDescription:
          'A small mountainous Caucasus territory that broke from its parent '
          'state in 1991–92 with Russian support. Russia recognised it after '
          'the brief 2008 war. It applied to join Russia in 2022 but was '
          'declined.',
      parties: 'South Ossetia vs. Georgia',
      recognitionStatus:
          'Recognised by Russia, Nicaragua, Venezuela, Syria, North Korea',
      nickname: 'The Mountain Republic',
      famousLandmark: 'Tskhinvali — the divided capital',
      flag: 'Three horizontal stripes of white, red, and yellow — identical to '
          'the North Ossetian flag within Russia, symbolising the pan-Ossetian '
          'aspiration for reunification. White represents moral purity, red '
          'represents military valour, and yellow represents prosperity.',
    ),

    // =========================================================================
    // TIER 2: Major Autonomy & Referendum Cases
    // =========================================================================
    'KR': DisputedTerritoryClueData(
      disputeDescription:
          'The world\'s largest ethnic group without a state, numbering over '
          '40 million people across four countries. The autonomous region within '
          'Iraq held an independence referendum in 2017 that passed with 93%, '
          'but it was rejected internationally and by Baghdad.',
      parties: 'Kurdish Regional Government vs. Iraq, Turkey, Iran, Syria',
      recognitionStatus: 'Autonomous region within Iraq; no sovereignty',
      nickname: 'The Land of the Kurds',
      famousLandmark: 'Erbil Citadel — continuously inhabited for 6,000+ years',
      flag: 'Three horizontal stripes of red, white, and green with a golden '
          'sun with 21 rays at the centre — the sun is the ancient Zoroastrian '
          'symbol of light and renewal, while 21 represents March 21st '
          '(Nowruz), the Kurdish New Year.',
    ),
    'CR': DisputedTerritoryClueData(
      disputeDescription:
          'This peninsula was annexed from Ukraine in 2014 after a disputed '
          'referendum, citing its Russian-speaking majority. Ukraine and almost '
          'all UN member states consider the annexation illegal. The territory '
          'is central to the ongoing Russo-Ukrainian War.',
      parties: 'Russia vs. Ukraine',
      recognitionStatus: 'Recognised as Russian by a handful of states',
      nickname: 'The Pearl of the Black Sea',
      famousLandmark: 'Livadia Palace — site of the 1945 Yalta Conference',
      flag: 'Three horizontal stripes of blue, white, and red — adopted under '
          'Russian administration. The blue represents the Black Sea, white '
          'represents peace, and red echoes the flags of both Russia and the '
          'historical Crimean Khanate.',
    ),
    'BG': DisputedTerritoryClueData(
      disputeDescription:
          'This Pacific island region of Papua New Guinea held a non-binding '
          'independence referendum in 2019 that produced a 98.3% vote for '
          'independence — one of the most decisive in history. A target '
          'independence date of 2027 has been proposed but not ratified.',
      parties: 'Autonomous Bougainville Government vs. Papua New Guinea',
      recognitionStatus: 'Autonomous region; independence pending ratification',
      nickname: 'The Copper Island',
      famousLandmark:
          'Panguna Mine — once the world\'s largest open-cut copper mine',
      flag:
          'A blue field with a red upe (traditional wide-brimmed hat) centred '
          'on a black disc — the upe represents the Bougainvillean people, '
          'the black disc represents the dark skin of the islanders, and the '
          'blue field represents the surrounding Pacific Ocean.',
    ),
    'TB': DisputedTerritoryClueData(
      disputeDescription:
          'This high-altitude plateau was an independent state (or at minimum '
          'autonomous) until it was incorporated into China in 1950–51. The '
          'government-in-exile, based in India, seeks genuine autonomy. The '
          'spiritual leader fled in 1959 after a failed uprising.',
      parties: 'Central Tibetan Administration vs. People\'s Republic of China',
      recognitionStatus: 'Administered as an autonomous region of China',
      nickname: 'The Roof of the World',
      famousLandmark: 'Potala Palace',
      flag:
          'The Snow Lion flag features two snow lions holding a flaming jewel '
          'atop a snow mountain, with a rising sun and alternating red and blue '
          'rays — the snow lions represent the nation\'s fearlessness, the '
          'jewel represents the Three Jewels of Buddhism. Illegal to display '
          'in China.',
    ),

    // =========================================================================
    // TIER 3: Historical / Dissolved
    // =========================================================================
    'NK': DisputedTerritoryClueData(
      disputeDescription:
          'This Armenian-populated enclave within Azerbaijan declared '
          'independence in 1991. After wars in the 1990s and 2020, a final '
          'military offensive in September 2023 ended the republic. Over '
          '100,000 ethnic Armenians fled, and it formally dissolved in 2024.',
      parties: 'Republic of Artsakh (backed by Armenia) vs. Azerbaijan',
      recognitionStatus: 'Dissolved — January 2024',
      nickname: 'Artsakh',
      famousLandmark: 'Dadivank Monastery',
      flag: 'An Armenian tricolor of red, blue, and orange with a white zigzag '
          'pattern extending from the fly — the zigzag represents the Armenian '
          'population separated from their homeland, while the colours match '
          'the Armenian national flag.',
    ),
  };
}
