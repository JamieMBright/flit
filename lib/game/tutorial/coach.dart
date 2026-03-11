/// Aviator instructor model for the tutorial campaign.
///
/// Each coach represents a diverse aviation professional who guides
/// the player through campaign missions.
class Coach {
  const Coach({
    required this.id,
    required this.name,
    required this.nationality,
    required this.countryCode,
    required this.title,
    required this.bio,
    required this.greeting,
  });

  /// Unique identifier used to reference this coach.
  final String id;

  /// Full name, e.g. "Captain Nadia Al-Masri".
  final String name;

  /// Nationality descriptor, e.g. "Palestinian".
  final String nationality;

  /// ISO 3166-1 alpha-2 country code for flag emoji, e.g. "PS".
  final String countryCode;

  /// Role title, e.g. "Navigation Instructor".
  final String title;

  /// Short one-line biography.
  final String bio;

  /// Introduction line spoken when the coach first appears.
  final String greeting;

  /// Country flag emoji derived from [countryCode].
  String get flagEmoji {
    final codeUnits = countryCode.toUpperCase().codeUnits;
    if (codeUnits.length != 2) return '';
    return String.fromCharCodes([
      codeUnits[0] + 0x1F1A5,
      codeUnits[1] + 0x1F1A5,
    ]);
  }
}

// ---------------------------------------------------------------------------
// Coach roster
// ---------------------------------------------------------------------------

const Coach coachNadia = Coach(
  id: 'nadia',
  name: 'Captain Nadia Al-Masri',
  nationality: 'Palestinian',
  countryCode: 'PS',
  title: 'Navigation Instructor',
  bio:
      'Former UN humanitarian pilot who navigated aid routes across conflict zones',
  greeting:
      'Welcome aboard, cadet. I flew supplies into places most pilots avoid — '
      "now I'll teach you to find them on a globe.",
);

const Coach coachAmara = Coach(
  id: 'amara',
  name: 'Amara Bekele',
  nationality: 'Ethiopian',
  countryCode: 'ET',
  title: 'Flag Expert',
  bio: 'Third-generation pilot from Addis Ababa, specializes in vexillology',
  greeting:
      'Every nation tells its story through its flag. Let me show you how to read them.',
);

const Coach coachMateo = Coach(
  id: 'mateo',
  name: 'Mateo Restrepo',
  nationality: 'Colombian',
  countryCode: 'CO',
  title: 'Capital Cities Specialist',
  bio: "Ex-cargo pilot who's landed in more capitals than anyone alive",
  greeting: "I've touched down in 140 capitals and counting. "
      'Time to see how many you can name!',
);

const Coach coachBayarmaa = Coach(
  id: 'bayarmaa',
  name: 'Bayarmaa Tserendorj',
  nationality: 'Mongolian',
  countryCode: 'MN',
  title: 'Mixed Signals Instructor',
  bio: 'Eagle hunter\'s daughter who learned to fly over the Altai Mountains',
  greeting:
      'In the steppe you read the wind, the stars, and the land all at once. '
      "I'll teach you to combine clues the same way.",
);

const Coach coachRizal = Coach(
  id: 'rizal',
  name: 'Rizal Santos',
  nationality: 'Filipino',
  countryCode: 'PH',
  title: 'Fuel Management Coach',
  bio:
      'Island-hopper who mastered fuel efficiency flying between 7,000 islands',
  greeting: 'Out here, running dry means swimming. '
      "Let's make sure every drop of fuel counts.",
);

const Coach coachSiobhan = Coach(
  id: 'siobhan',
  name: 'Siobhán O\'Reilly',
  nationality: 'Irish',
  countryCode: 'IE',
  title: 'Hint Strategy Advisor',
  bio:
      'Former Shannon ATC controller who guided thousands of transatlantic flights',
  greeting:
      'I spent years talking pilots through bad weather over the Atlantic. '
      "Now I'll talk you through tricky clues.",
);

const Coach coachLina = Coach(
  id: 'lina',
  name: 'Lina Haddad',
  nationality: 'Jordanian',
  countryCode: 'JO',
  title: 'Statistics Analyst',
  bio: 'Jordanian Air Force meteorologist turned geography data expert',
  greeting: 'Numbers tell a story if you know how to listen. '
      "Population, area, GDP — they're all clues.",
);

const Coach coachDiego = Coach(
  id: 'diego',
  name: 'Diego Ferreira',
  nationality: 'Brazilian',
  countryCode: 'BR',
  title: 'Outline Recognition Expert',
  bio: 'Amazonian bush pilot who can identify any landmass from the air',
  greeting: "I've flown over every shape the Earth has to offer. "
      "Let's see if you can match my eye.",
);

const Coach coachAyu = Coach(
  id: 'ayu',
  name: 'Ayu Wulandari',
  nationality: 'Indonesian',
  countryCode: 'ID',
  title: 'Advanced Flight Instructor',
  bio: 'Youngest female captain in Indonesian aviation history',
  greeting: 'They said I was too young. I proved them wrong at 10,000 metres. '
      'Ready to prove yourself?',
);

const Coach coachHarpa = Coach(
  id: 'harpa',
  name: 'Harpa Sigurðardóttir',
  nationality: 'Icelandic',
  countryCode: 'IS',
  title: 'License & Economy Tutor',
  bio: 'Former Icelandair training captain specializing in fuel management',
  greeting: 'In Iceland we fly through storms that ground other airlines. '
      "Efficiency isn't optional — it's survival.",
);

/// All available coaches indexed by [Coach.id].
const List<Coach> coaches = [
  coachNadia,
  coachAmara,
  coachMateo,
  coachBayarmaa,
  coachRizal,
  coachSiobhan,
  coachLina,
  coachDiego,
  coachAyu,
  coachHarpa,
];
