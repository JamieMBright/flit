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

/// Mission 1: Navigation / Borders — Indian aviation pioneer (1904–1993)
const Coach coachJRDTata = Coach(
  id: 'jrd_tata',
  name: 'J.R.D. Tata',
  nationality: 'Indian',
  countryCode: 'IN',
  title: 'Navigation Instructor',
  bio: 'First Indian to earn a pilot\'s licence in 1929, who pioneered '
      'commercial aviation in India and founded what became Air India.',
  introduction:
      'I am J.R.D. Tata. In 1929, I became the first Indian to earn a '
      'pilot\'s licence. I flew the first airmail in India — Karachi to '
      'Bombay in a tiny Puss Moth. Before you can fly a route, you must '
      'know your borders and neighbours. Let me teach you to navigate.',
  greeting:
      'You navigate with the confidence of an airline founder. Well done.',
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

/// Mission 7: Statistics / Data — Peruvian aviator (1887–1910)
const Coach coachJorgeChavez = Coach(
  id: 'jorge_chavez',
  name: 'Jorge Chávez',
  nationality: 'Peruvian',
  countryCode: 'PE',
  title: 'Statistics Analyst',
  bio: 'Peruvian aviator who became the first person to fly over the Alps '
      'in 1910 — Lima\'s international airport bears his name.',
  introduction:
      'I am Jorge Chávez. In 1910, I flew a Blériot monoplane over the '
      'Alps — the first person to cross those peaks by air. I calculated '
      'altitude, wind speed, and fuel to the decimal. Numbers are the '
      'language of the sky. Let me teach you to read them.',
  greeting: 'Your data analysis would make any flight engineer proud.',
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

/// Mission 9: World Tour / All Clues — Mexican aviator (1905–1928)
const Coach coachEmilioCarranza = Coach(
  id: 'emilio_carranza',
  name: 'Emilio Carranza',
  nationality: 'Mexican',
  countryCode: 'MX',
  title: 'Advanced Flight Instructor',
  bio: 'The "Lindbergh of Mexico" who flew nonstop from Mexico City to '
      'Washington D.C. on a goodwill mission in 1928, becoming a national hero.',
  introduction:
      'I am Captain Emilio Carranza. In 1928, I flew nonstop from Mexico '
      'City to Washington — a goodwill flight across mountains and storms. '
      'They called me the Lindbergh of Mexico, but my mission was peace '
      'between nations. Now every clue type is in play. Show me what you '
      'have learned.',
  greeting: 'You flew that like a captain on a goodwill mission. The world is '
      'yours to explore.',
);

/// Mission 10: License — Palestinian geographer (c. 946–c. 1000)
const Coach coachMuqaddasi = Coach(
  id: 'muqaddasi',
  name: 'Al-Muqaddasi',
  nationality: 'Palestinian',
  countryCode: 'PS',
  title: 'Geography & Regions Mentor',
  bio: 'Medieval Arab geographer born in Jerusalem who travelled the entire '
      'known world and authored the first scientific regional geography, '
      'complete with colour maps.',
  introduction:
      'I am al-Muqaddasi, the Jerusalemite. A thousand years ago, I walked '
      'every province of the known world and wrote the first true geography '
      '— mapping not just lands, but their trade, their people, and their '
      'worth. I will be your final instructor. Let us see if you are ready '
      'for your licence.',
  greeting:
      'You have earned your wings, just as I earned my knowledge — through '
      'patience, curiosity, and a refusal to leave any corner of the world '
      'unexplored. Fly well, pilot.',
);

/// Mission 11: Daily Prep — Filipino fighter ace (1914–1971)
const Coach coachVillamor = Coach(
  id: 'villamor',
  name: 'Jesús Villamor',
  nationality: 'Filipino',
  countryCode: 'PH',
  title: 'Daily Prep Instructor',
  bio: 'Filipino WWII fighter ace who led the aerial defence of Manila '
      'against the Japanese invasion, flying against overwhelming odds.',
  introduction: 'I am Captain Jesús Villamor. When the Japanese attacked the '
      'Philippines, I led five biplanes against their bombers — outnumbered '
      'but never outfought. Daily challenges are like combat: preparation '
      'is everything. Let me sharpen your reflexes.',
  greeting: 'You handled that pressure like a true ace. Ready for anything.',
);

/// Mission 12: Graduation — Indonesian aviation hero (1922–1947)
const Coach coachHalim = Coach(
  id: 'halim',
  name: 'Halim Perdanakusuma',
  nationality: 'Indonesian',
  countryCode: 'ID',
  title: 'Graduation Examiner',
  bio: 'Indonesian national hero who flew daring missions during the war '
      'of independence, giving his life for his country\'s freedom at age 25.',
  introduction:
      'I am Halim Perdanakusuma. I flew for Indonesia\'s freedom — daring '
      'missions against colonial forces in skies I refused to surrender. '
      'This is your graduation flight. Everything you have learned comes '
      'together here. Show me you are ready.',
  greeting:
      'You have earned your wings. Fly with the courage of those who fought '
      'for the freedom to explore.',
);

/// Mission 13: Ace Pilot — Barbadian RAF combat pilot (1920–1987)
const Coach coachErrolBarrow = Coach(
  id: 'errol_barrow',
  name: 'Errol Barrow',
  nationality: 'Barbadian',
  countryCode: 'BB',
  title: 'Ace Pilot Mentor',
  bio: 'Barbadian WWII RAF combat pilot who flew 45+ missions over Europe, '
      'then returned home to lead Barbados to independence as Prime Minister.',
  introduction:
      'I am Errol Barrow. I flew 45 combat missions with the RAF over '
      'Europe, then came home to lead Barbados to independence. I learned '
      'that true mastery means performing under any conditions. This is '
      'your final test — the ace challenge. Hold nothing back.',
  greeting: 'From combat pilot to prime minister, I have seen excellence — and '
      'you have it. Fly proud, ace.',
);

/// All available coaches indexed by [Coach.id].
const List<Coach> coaches = [
  coachJRDTata,
  coachLotfia,
  coachSantosDumont,
  coachSabiha,
  coachJeanBatten,
  coachSaintExupery,
  coachJorgeChavez,
  coachBerylMarkham,
  coachEmilioCarranza,
  coachMuqaddasi,
  coachVillamor,
  coachHalim,
  coachErrolBarrow,
];
