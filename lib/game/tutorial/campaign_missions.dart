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
  // Mission 1 — First Flight
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'first_flight',
    order: 1,
    title: 'First Flight',
    subtitle: 'Learn the basics',
    description:
        'This is your first sortie, cadet. I\'ll show you a country\'s '
        'neighbours — your job is to fly to the country they all share a '
        'border with.',
    coach: coachNadia,
    allowedClues: {ClueType.borders},
    rounds: 1,
    maxDifficulty: 0.15,
    fuelEnabled: false,
    xpReward: 50,
    coinReward: 25,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'This is your first clue — it shows the neighbouring countries. '
            'Fly to the country they all border!',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Excellent navigation! You found it.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'Not quite — look at the neighbours again and think about which '
            'region of the world they share.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 2 — Flag Spotter
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'flag_spotter',
    order: 2,
    title: 'Flag Spotter',
    subtitle: 'Identify flags',
    description:
        'Every flag has a story. I\'ll show you a flag and you tell me '
        'which country flies it. Watch for colours, symbols, and patterns.',
    coach: coachAmara,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 3 — Capital Knowledge
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'capital_knowledge',
    order: 3,
    title: 'Capital Knowledge',
    subtitle: 'Name the capitals',
    description: 'I\'ve landed in 140 capitals and I remember every runway. '
        'Now let\'s see if you can match a capital city to its country.',
    coach: coachMateo,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 4 — Mixed Signals
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'mixed_signals',
    order: 4,
    title: 'Mixed Signals',
    subtitle: 'Multiple clue types',
    description: 'In the steppe you must read wind, stars, and land together. '
        'This mission gives you borders AND flags — combine them to find '
        'your target.',
    coach: coachBayarmaa,
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
        message: 'You read those signals like a true nomad. Well done.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'Cross-reference your clues. The flag and borders should point '
            'to the same region.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 5 — Fuel Management
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'fuel_management',
    order: 5,
    title: 'Fuel Management',
    subtitle: 'Master your fuel',
    description:
        'Out in the islands, fuel is life. This mission enables the fuel '
        'gauge — fly efficiently or you\'ll be swimming home.',
    coach: coachRizal,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 6 — Hint Strategy
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'hint_strategy',
    order: 6,
    title: 'Hint Strategy',
    subtitle: 'Use hints wisely',
    description:
        'Sometimes you need a nudge. I\'ll teach you when to spend a hint '
        'and when to trust your instincts. Every hint costs points, so '
        'choose wisely.',
    coach: coachSiobhan,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 7 — Stats & Facts
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'stats_and_facts',
    order: 7,
    title: 'Stats & Facts',
    subtitle: 'Read the numbers',
    description:
        'Numbers don\'t lie. Population, area, GDP — each statistic is a '
        'fingerprint. Let\'s see if you can decode them.',
    coach: coachLina,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 8 — Shape Shifter
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'shape_shifter',
    order: 8,
    title: 'Shape Shifter',
    subtitle: 'Recognize outlines',
    description:
        'I\'ve flown over every shape the Earth has to offer. Now I\'ll '
        'show you a country\'s outline — can you name it from its silhouette?',
    coach: coachDiego,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 9 — World Tour
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'world_tour',
    order: 9,
    title: 'World Tour',
    subtitle: 'Use all clue types',
    description:
        'Time to put it all together. Every clue type is in play — flags, '
        'borders, capitals, stats, outlines. Show me what you\'ve learned.',
    coach: coachAyu,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 10 — License to Fly
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'license_to_fly',
    order: 10,
    title: 'License to Fly',
    subtitle: 'Understand your license',
    description: 'Your pilot licence isn\'t just a badge — it\'s your economy. '
        'Learn how XP, coins, and stars work so you can progress efficiently.',
    coach: coachHarpa,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 11 — Daily Prep
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'daily_prep',
    order: 11,
    title: 'Daily Prep',
    subtitle: 'Prepare for daily modes',
    description:
        'The daily modes are tougher — timed, competitive, and unforgiving. '
        'This mission simulates real conditions so you\'re ready for anything.',
    coach: coachNadia,
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
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 12 — Ready for Takeoff
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'ready_for_takeoff',
    order: 12,
    title: 'Ready for Takeoff',
    subtitle: 'Graduation flight',
    description:
        'This is your graduation flight, cadet. Everything you\'ve learned '
        'comes together here. Pass this and the entire world opens up.',
    coach: coachNadia,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.60,
    fuelEnabled: true,
    xpReward: 200,
    coinReward: 150,
    unlockMessage: 'All game modes unlocked! Fly safe, pilot.',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'This is it — your final exam. Use every skill you\'ve learned. '
            'I believe in you.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'Halfway to your wings. Keep the momentum — you\'re flying '
            'beautifully.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Welcome to the skies, pilot. You\'ve earned your wings.',
      ),
    ],
  ),
];
