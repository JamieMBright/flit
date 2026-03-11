/// Aviator / explorer instructor model for the tutorial campaign.
///
/// Each coach represents a real, historically notable figure from aviation,
/// exploration, or geography who guides the player through campaign missions.
class Coach {
  const Coach({
    required this.id,
    required this.name,
    required this.nationality,
    required this.countryCode,
    required this.title,
    required this.bio,
    required this.introduction,
    required this.greeting,
    this.imageAsset,
  });

  /// Unique identifier used to reference this coach.
  final String id;

  /// Full name, e.g. "Amelia Earhart".
  final String name;

  /// Nationality descriptor, e.g. "American".
  final String nationality;

  /// ISO 3166-1 alpha-2 country code for flag emoji, e.g. "US".
  final String countryCode;

  /// Role title, e.g. "Navigation Instructor".
  final String title;

  /// Short one-line biography describing their real achievement.
  final String bio;

  /// First-person self-introduction (2-3 sentences) referencing their real
  /// achievements and teasing why they were chosen to coach this mission.
  final String introduction;

  /// Congratulations line spoken when the player completes the mission.
  final String greeting;

  /// Optional asset path to a cartoonised portrait.
  /// Falls back to a styled initial circle when null.
  final String? imageAsset;

  /// Country flag emoji derived from [countryCode].
  String get flagEmoji {
    final codeUnits = countryCode.toUpperCase().codeUnits;
    if (codeUnits.length != 2) return '';
    return String.fromCharCodes([
      codeUnits[0] + 0x1F1A5,
      codeUnits[1] + 0x1F1A5,
    ]);
  }

  /// Short first name or surname for compact displays.
  String get shortName {
    // Use first name for single-word names, otherwise last segment.
    final parts = name.split(' ');
    return parts.length <= 2 ? parts.first : parts.last;
  }
}

// ---------------------------------------------------------------------------
// Coach roster — all real, researchable historical figures
// ---------------------------------------------------------------------------

/// Mission 1: Navigation / Borders — Chinese admiral (1371–1433)
const Coach coachZhengHe = Coach(
  id: 'zheng_he',
  name: 'Zheng He',
  nationality: 'Chinese',
  countryCode: 'CN',
  title: 'Navigation Instructor',
  bio: 'Ming Dynasty admiral who commanded 300 ships and 28,000 sailors '
      'across the Indian Ocean — the largest fleet the world had ever seen.',
  introduction:
      'I am Zheng He. I once commanded the largest fleet the world had ever '
      'seen — 300 ships sailing from Nanjing to the coast of Africa. If I '
      'can navigate those seas with nothing but the stars, you can learn to '
      'read a globe. Let me show you how borders and neighbours guide you '
      'to your destination.',
  greeting:
      'You navigate with the confidence of a Ming Dynasty admiral. Well done.',
);

/// Mission 2: Flags — Egyptian aviator (1907–2002)
const Coach coachLotfia = Coach(
  id: 'lotfia',
  name: 'Lotfia El Nadi',
  nationality: 'Egyptian',
  countryCode: 'EG',
  title: 'Flag Expert',
  bio: 'First woman in Africa and the Arab world to earn a pilot\'s '
      'licence, secretly enrolling in flight school in Cairo in 1933.',
  introduction:
      'I\'m Lotfia El Nadi. In 1933, I secretly enrolled in flight school '
      'without my father knowing — and became the first woman in the Arab '
      'world to earn her wings. Every flag tells the story of a nation\'s '
      'spirit. Let me teach you to read them.',
  greeting: 'You read those flags like poetry. I\'m proud of you.',
);

/// Mission 3: Capital Cities — Brazilian aviation pioneer (1873–1932)
const Coach coachSantosDumont = Coach(
  id: 'santos_dumont',
  name: 'Alberto Santos-Dumont',
  nationality: 'Brazilian',
  countryCode: 'BR',
  title: 'Capital Cities Specialist',
  bio: 'Brazilian aviation pioneer who made the first public heavier-than-air '
      'flight in Europe in 1906 and circled the Eiffel Tower in an airship.',
  introduction:
      'I am Alberto Santos-Dumont. In 1906, I flew my 14-bis over the fields '
      'of Paris — the first public flight in history. I\'ve circled the '
      'Eiffel Tower in an airship and landed near capitals across Europe. '
      'Knowing where you are is just as important as knowing how to fly.',
  greeting: 'Bravo! You know your capitals like a true aviator of the world.',
);

/// Mission 4: Mixed Signals — Turkish fighter pilot (1913–2001)
const Coach coachSabiha = Coach(
  id: 'sabiha',
  name: 'Sabiha Gökçen',
  nationality: 'Turkish',
  countryCode: 'TR',
  title: 'Mixed Signals Instructor',
  bio: 'World\'s first female fighter pilot, who flew 22 combat missions '
      'and logged over 8,000 hours of flight time.',
  introduction:
      'I am Sabiha Gökçen. At 23, I became the world\'s first female combat '
      'pilot. In the cockpit, you must read instruments, terrain, and '
      'instinct all at once. I\'ll teach you to combine every signal into '
      'one clear picture.',
  greeting: 'You combined those clues like a true combat pilot. Exceptional.',
);

/// Mission 5: Fuel Management — New Zealand aviator (1909–1982)
const Coach coachJeanBatten = Coach(
  id: 'jean_batten',
  name: 'Jean Batten',
  nationality: 'New Zealander',
  countryCode: 'NZ',
  title: 'Fuel Management Coach',
  bio: 'Record-breaking New Zealand aviator who flew solo from England '
      'to New Zealand — 14,000 miles in a single-engine Percival Gull.',
  introduction:
      'I\'m Jean Batten. I flew solo from England to New Zealand — 14,000 '
      'miles with nothing but my Percival Gull and a very careful fuel plan. '
      'Out over the ocean, every drop counts. I\'ll teach you the same '
      'discipline.',
  greeting: 'Efficient and precise. You\'d have made it across the Tasman with '
      'fuel to spare.',
);

/// Mission 6: Hint Strategy — French aviator & author (1900–1944)
const Coach coachSaintExupery = Coach(
  id: 'saint_exupery',
  name: 'Antoine de Saint-Exupéry',
  nationality: 'French',
  countryCode: 'FR',
  title: 'Hint Strategy Advisor',
  bio: 'French aviator and author of The Little Prince, who flew mail '
      'routes across the Sahara and survived multiple crashes in the desert.',
  introduction: 'I am Antoine de Saint-Exupéry. I flew mail across the Sahara, '
      'crashed in the Libyan desert, and wrote The Little Prince from what '
      'I learned up there. That book taught me: what is essential is '
      'invisible to the eye — but sometimes you need a hint to find it.',
  greeting: 'You found your way with grace. As I once wrote: "It is only with '
      'the heart that one can see rightly."',
);

/// Mission 7: Statistics / Data — Soviet cosmonaut (1937–)
const Coach coachTereshkova = Coach(
  id: 'tereshkova',
  name: 'Valentina Tereshkova',
  nationality: 'Russian',
  countryCode: 'RU',
  title: 'Statistics Analyst',
  bio: 'First woman in space, orbiting Earth 48 times aboard Vostok 6 '
      'in June 1963 — a record that stood for 19 years.',
  introduction:
      'I am Valentina Tereshkova. In 1963, I orbited the Earth 48 times '
      'aboard Vostok 6 — the first woman to see our planet from space. '
      'From up there, you see the world in numbers: orbital speed, altitude, '
      'atmospheric pressure. Numbers are clues if you know how to read them.',
  greeting: 'Your data analysis is stellar — worthy of mission control.',
);

/// Mission 8: Outline / Shape Recognition — Kenyan-British aviator (1902–1986)
const Coach coachBerylMarkham = Coach(
  id: 'beryl_markham',
  name: 'Beryl Markham',
  nationality: 'Kenyan',
  countryCode: 'KE',
  title: 'Outline Recognition Expert',
  bio: 'First person to fly solo across the Atlantic from east to west, '
      'and a bush pilot in Kenya who could spot wildlife from the air.',
  introduction:
      'I\'m Beryl Markham. I grew up in Kenya, learned to track from the '
      'Nandi people, and became the first person to fly the Atlantic east '
      'to west. From the cockpit of my Vega Gull, I learned to read the '
      'shape of every landmass below. Each country has a silhouette as '
      'distinctive as a fingerprint.',
  greeting:
      'You\'ve got the eye of a bush pilot. That silhouette didn\'t fool you.',
);

/// Mission 9: World Tour / All Clues — American aviator (1897–1937)
const Coach coachAmelia = Coach(
  id: 'amelia',
  name: 'Amelia Earhart',
  nationality: 'American',
  countryCode: 'US',
  title: 'Advanced Flight Instructor',
  bio: 'First woman to fly solo across the Atlantic Ocean in 1932, '
      'who disappeared during an attempt to circumnavigate the globe.',
  introduction:
      'I\'m Amelia Earhart. In 1932, I flew solo across the Atlantic — '
      'the first woman to do it. I spent my life proving that adventure '
      'knows no gender. Now every clue type is in play. Let\'s see if you '
      'can handle everything the world throws at you.',
  greeting:
      'You flew that like a seasoned world navigator. Adventure suits you.',
);

/// Missions 10–12: License, Daily Prep, Graduation — Palestinian-American
/// scholar (1935–2003)
const Coach coachEdwardSaid = Coach(
  id: 'edward_said',
  name: 'Edward Said',
  nationality: 'Palestinian',
  countryCode: 'PS',
  title: 'Geography & Identity Mentor',
  bio: 'Palestinian-American scholar whose groundbreaking work on geography, '
      'place, and cultural identity reshaped how the world understands '
      'borders and belonging.',
  introduction:
      'I am Edward Said. I spent my life studying how maps, borders, and '
      'names shape the way we see each other. Geography is never neutral — '
      'it tells the story of who we are and where we belong. In these final '
      'missions, I\'ll help you see the world with new eyes.',
  greeting: 'You\'ve proven that understanding geography means understanding '
      'people. Fly on, pilot.',
);

/// All available coaches indexed by [Coach.id].
const List<Coach> coaches = [
  coachZhengHe,
  coachLotfia,
  coachSantosDumont,
  coachSabiha,
  coachJeanBatten,
  coachSaintExupery,
  coachTereshkova,
  coachBerylMarkham,
  coachAmelia,
  coachEdwardSaid,
];
