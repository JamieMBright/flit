import '../clues/clue_types.dart';
import 'campaign_mission.dart';
import 'coach.dart';

/// All clue types, used as a shorthand for missions that allow everything.
const Set<ClueType> _allClueTypes = {
  ClueType.flag,
  ClueType.outline,
  ClueType.borders,
  ClueType.capital,
  ClueType.stats,
  ClueType.sportsTeam,
  ClueType.leader,
  ClueType.nickname,
  ClueType.landmark,
  ClueType.flagDescription,
};

/// The ordered list of tutorial campaign missions.
const List<CampaignMission> campaignMissions = [
  // -----------------------------------------------------------------------
  // Mission 1 — First Flight (J.R.D. Tata)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'first_flight',
    order: 1,
    title: 'First Flight',
    subtitle: 'Learn the basics',
    description:
        'This is your first sortie, cadet. I\'ll show you a country\'s '
        'neighbours — your job is to fly to the country they all share a '
        'border with. We\'re heading to my homeland.',
    coach: coachJRDTata,
    allowedClues: {ClueType.borders},
    rounds: 1,
    maxDifficulty: 0.15,
    targetCountryCodes: ['IN'],
    fuelEnabled: false,
    xpReward: 50,
    coinReward: 25,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'These are the neighbouring countries. Pakistan, China, Nepal, '
            'Bhutan, Bangladesh, Myanmar — which great nation do they all '
            'share a border with? This is my homeland. Fly there!',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'India! My beloved homeland. I made my first flight from Karachi '
            'to Bombay in a tiny Puss Moth — and from that single flight, '
            'an airline was born. Welcome to the land that taught me to dream.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'Not quite, cadet. Look at those neighbours — Pakistan, China, '
            'Nepal. They surround one of the world\'s greatest nations. '
            'Head south-east towards Asia.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'When I planned my first airmail route, I studied every border '
            'and every neighbour. Six countries surround this one — and it\'s '
            'the second most populous nation on Earth. You know this.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 2 — Flag Spotter (Lotfia El Nadi)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'flag_spotter',
    order: 2,
    title: 'Flag Spotter',
    subtitle: 'Identify flags',
    description:
        'Every flag has a story. I\'ll show you a flag and you tell me '
        'which country flies it. Watch for colours, symbols, and patterns.',
    coach: coachLotfia,
    allowedClues: {ClueType.flag},
    rounds: 2,
    maxDifficulty: 0.20,
    fuelEnabled: false,
    xpReward: 75,
    coinReward: 50,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'Study the flag carefully — colours and symbols often represent '
            'the country\'s history and geography.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Sharp eye! You read that flag like a book.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'That flag belongs to a different part of the world. Think about '
            'which regions use those colour combinations.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Look at the flag\'s colours and symbols. Many regions share '
            'colour palettes — Pan-African, Pan-Arab, Scandinavian crosses. '
            'That\'s your starting point.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 3 — Capital Knowledge (Alberto Santos-Dumont)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'capital_knowledge',
    order: 3,
    title: 'Capital Knowledge',
    subtitle: 'Name the capitals',
    description: 'I\'ve flown over more capital cities than I can count. '
        'Now let\'s see if you can match a capital city to its country.',
    coach: coachSantosDumont,
    allowedClues: {ClueType.capital},
    rounds: 2,
    maxDifficulty: 0.25,
    fuelEnabled: false,
    xpReward: 75,
    coinReward: 50,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'Here\'s the capital city. Think about where in the world this '
            'city sits and fly there!',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Touchdown! You know your capitals. I\'d hire you as my co-pilot.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'Halfway through — you\'re building a solid mental map. Keep it up.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Don\'t know this capital? Think about the language — does it '
            'sound French, Spanish, Arabic? That narrows the region.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 4 — Mixed Signals (Sabiha Gökçen)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'mixed_signals',
    order: 4,
    title: 'Mixed Signals',
    subtitle: 'Multiple clue types',
    description:
        'In combat you must read instruments, terrain, and instinct all at '
        'once. This mission gives you borders AND flags — combine them to '
        'find your target.',
    coach: coachSabiha,
    allowedClues: {ClueType.borders, ClueType.flag},
    rounds: 2,
    maxDifficulty: 0.30,
    fuelEnabled: false,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'You\'ll receive more than one type of clue now. Use them '
            'together — each one narrows the possibilities.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'You read those signals like a true pilot. Well done.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'Cross-reference your clues. The flag and borders should point '
            'to the same region.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Use both clues together. If the flag looks European but the '
            'borders mention Asian neighbours, rethink your approach.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 5 — Fuel Management (Jean Batten)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'fuel_management',
    order: 5,
    title: 'Fuel Management',
    subtitle: 'Master your fuel',
    description:
        'On my solo flights, fuel was everything. This mission enables the '
        'fuel gauge — fly efficiently or you\'ll never make it.',
    coach: coachJeanBatten,
    allowedClues: {ClueType.borders, ClueType.flag, ClueType.capital},
    rounds: 2,
    maxDifficulty: 0.25,
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'Watch your fuel gauge — it burns as you fly. '
            'Faster speed means more fuel consumed.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'Fuel\'s getting low! Descend to low altitude — it uses only '
            '25% fuel.',
      ),
      CoachTip(
        trigger: 'fuelEmpty',
        message: 'You\'re running on fumes! Make your best guess now before '
            'the engine quits.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Don\'t wander — every mile burns fuel. Study your clues, pick '
            'a direction, and commit. Efficiency is survival.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 6 — Hint Strategy (Antoine de Saint-Exupéry)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'hint_strategy',
    order: 6,
    title: 'Hint Strategy',
    subtitle: 'Use hints wisely',
    description:
        'What is essential is invisible to the eye — but sometimes you need '
        'a hint to find it. Every hint costs points, so choose wisely.',
    coach: coachSaintExupery,
    allowedClues: {ClueType.flag, ClueType.capital},
    rounds: 2,
    maxDifficulty: 0.35,
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    unlockMessage: 'Daily Briefing unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'Stuck? Use hints to narrow it down. But each hint reduces '
            'your score.',
      ),
      CoachTip(
        trigger: 'firstHint',
        message: 'Good call — sometimes a hint early saves fuel and time. '
            'Just don\'t rely on them every round.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Nicely done. Knowing when to ask for help is a skill in itself.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Remember — hints exist for a reason. Sometimes spending a few '
            'points on a hint saves you fuel and time in the long run.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 7 — Stats & Facts (Jorge Chávez)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'stats_and_facts',
    order: 7,
    title: 'Stats & Facts',
    subtitle: 'Read the numbers',
    description: 'To fly over the Alps, I calculated altitude, wind, and fuel '
        'to the decimal. Population, area, GDP — each statistic is a '
        'fingerprint. Let\'s see if you can decode them.',
    coach: coachJorgeChavez,
    allowedClues: {ClueType.stats},
    rounds: 2,
    maxDifficulty: 0.30,
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'Look at the statistics carefully. A large population with a '
            'small area? That narrows it down fast.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'You\'re getting a feel for the numbers. Remember — context is '
            'everything in data analysis.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'Check the numbers again. Compare them to countries you know '
            'in different regions.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Use the numbers as elimination. Very high population? Only a '
            'handful of countries qualify. Very small area? Even fewer.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 8 — Shape Shifter (Beryl Markham)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'shape_shifter',
    order: 8,
    title: 'Shape Shifter',
    subtitle: 'Recognize outlines',
    description:
        'I\'ve flown over every shape the Earth has to offer. Now I\'ll '
        'show you a country\'s outline — can you name it from its silhouette?',
    coach: coachBerylMarkham,
    allowedClues: {ClueType.outline},
    rounds: 2,
    maxDifficulty: 0.25,
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'Study the outline. Look for distinctive coastlines, peninsulas, '
            'and proportions.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'You\'ve got the eye of a bush pilot! That silhouette didn\'t '
            'fool you.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'Think about the shape\'s proportions. Is it wide? Tall? '
            'Does it have islands?',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Focus on distinctive features: long coastlines, island chains, '
            'peninsulas. Even a vague shape can rule out entire continents.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 9 — World Tour (Emilio Carranza)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'world_tour',
    order: 9,
    title: 'World Tour',
    subtitle: 'Use all clue types',
    description:
        'Time to put it all together. Every clue type is in play — flags, '
        'borders, capitals, stats, outlines. Show me what you\'ve learned.',
    coach: coachEmilioCarranza,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.45,
    fuelEnabled: true,
    xpReward: 125,
    coinReward: 100,
    unlockMessage: 'Daily Challenge unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'All clue types are live. Use each one to cross-reference and '
            'zero in on the target.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'Fuel is dropping. Commit to your best guess rather than '
            'searching aimlessly.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Outstanding — you flew that like a seasoned captain.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'With all clue types active, start by narrowing the continent. '
            'Then use each clue to zoom in further. Process of elimination.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 10 — License to Fly (Al-Muqaddasi)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'license_to_fly',
    order: 10,
    title: 'License to Fly',
    subtitle: 'Understand your license',
    description:
        'Your pilot licence isn\'t just a badge — it represents your journey. '
        'Learn how XP, coins, and stars work so you can progress efficiently.',
    coach: coachMuqaddasi,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.50,
    fuelEnabled: true,
    xpReward: 125,
    coinReward: 100,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'Every correct answer earns XP and coins. Stars depend on your '
            'overall score — aim high for three stars.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'You\'re halfway through. Remember, speed and accuracy both '
            'contribute to your final score.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Solid work. That\'s more XP in the bank for your licence.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Think about efficiency — the faster and more accurately you '
            'answer, the more XP and coins you earn. Don\'t rush, but '
            'don\'t dawdle.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 11 — Daily Prep (Jesús Villamor)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'daily_prep',
    order: 11,
    title: 'Daily Prep',
    subtitle: 'Prepare for daily modes',
    description:
        'The daily modes are tougher — timed, competitive, and unforgiving. '
        'This mission simulates real conditions so you\'re ready for anything.',
    coach: coachVillamor,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.55,
    fuelEnabled: true,
    xpReward: 150,
    coinReward: 100,
    unlockMessage: 'Dogfight unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'This is as close to a real daily challenge as it gets. '
            'Stay focused and trust your training.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'In competitive modes, running out of fuel means zero points. '
            'Make your move now.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'That\'s the precision I expect. You\'re almost ready for '
            'the real thing.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'This simulates competitive conditions. In the real daily modes, '
            'every second matters. Trust your instincts and commit.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 12 — Ready for Takeoff (Halim Perdanakusuma)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'ready_for_takeoff',
    order: 12,
    title: 'Ready for Takeoff',
    subtitle: 'Graduation flight',
    description:
        'This is your graduation flight, cadet. Everything you\'ve learned '
        'comes together here. Pass this and the entire world opens up.',
    coach: coachHalim,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.60,
    fuelEnabled: true,
    xpReward: 200,
    coinReward: 150,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'This is it — your graduation flight. Use every skill you\'ve '
            'learned. I believe in you.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'Halfway to your wings. Keep the momentum — you\'re flying '
            'beautifully.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'You fly with the courage of a freedom fighter. Well done.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'This is your graduation flight — everything you\'ve learned is '
            'here. Combine clues, manage fuel, and trust the skills you\'ve '
            'built. You\'re ready.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 13 — Ace Pilot (Errol Barrow)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'ace_pilot',
    order: 13,
    title: 'Ace Pilot',
    subtitle: 'The ultimate test',
    description:
        'I flew 45 combat missions over Europe and led a nation to freedom. '
        'This is the ace challenge — maximum difficulty, all clues, no mercy. '
        'Show me you belong in the sky.',
    coach: coachErrolBarrow,
    allowedClues: _allClueTypes,
    rounds: 4,
    maxDifficulty: 0.70,
    fuelEnabled: true,
    xpReward: 250,
    coinReward: 200,
    unlockMessage: 'All game modes unlocked! Fly safe, ace.',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'This is the ace challenge. No safety net. Use everything you '
            'know and trust your instincts.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'Fuel is critical. In combat, hesitation costs lives. '
            'Commit to your best answer now.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'That\'s ace-level flying. Outstanding.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Even aces get lost sometimes. Narrow the continent first, then '
            'cross-reference every clue. You have the skills — use them all.',
      ),
    ],
  ),
];
