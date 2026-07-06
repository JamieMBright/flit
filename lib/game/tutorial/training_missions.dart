import 'dart:math';

import '../clues/clue_types.dart';
import 'campaign_mission.dart';
import 'coach.dart';
import 'mode_requirements.dart';

/// Basic + Advanced Training — the new-pilot funnel.
///
/// Level-1 pilots see exactly three Basic Training missions (flight, recon,
/// briefing). Each one unlocks its matching daily mode immediately;
/// completing all three grants Level 2 and unlocks every base mode (see
/// `mode_requirements.dart`). Advanced Training then introduces the systems
/// a new pilot meets next — rated sorties, hints, the license, fuel,
/// the shop, and head-to-head challenges — as optional one-time-reward
/// missions on the same surface.
///
/// Progress persists through the existing campaign path: every training
/// mission records a [CampaignMissionResult] in `campaign_progress`
/// (`AccountNotifier.completeCampaignMission`), so
/// `AccountState.completedMissionIds` picks them up with no new columns.

/// What a training mission asks the pilot to do, and therefore how it is
/// launched and how completion is detected.
enum TrainingMissionKind {
  /// A coached flight through `PlayScreen` (completion recorded by the
  /// existing campaign-mission path via [TrainingMission.flightMission]).
  flight,

  /// A one-round Recon (triangulation) game.
  recon,

  /// A short tap-the-country briefing quiz.
  briefing,

  /// Fly one rated Standard Sortie run.
  sortie,

  /// Visit the Pilot License hangar.
  license,

  /// Browse the Supply Shop.
  shop,

  /// Send or accept a head-to-head challenge.
  challenge,
}

/// A single Basic/Advanced Training mission.
class TrainingMission {
  const TrainingMission({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.objective,
    required this.coach,
    required this.kind,
    required this.isBasic,
    required this.xpReward,
    required this.coinReward,
    this.unlockMessage,
    this.unlockPreview,
    this.flightMission,
  });

  /// Mission ID — recorded in `campaign_progress` on completion and matched
  /// against `mode_requirements.dart` gates.
  final String id;

  /// Position in the training trail (1-based across basic + advanced).
  final int order;

  final String title;
  final String subtitle;

  /// Coach's briefing speech shown before starting.
  final String description;

  /// One-line completion objective shown on the mission card.
  final String objective;

  final Coach coach;
  final TrainingMissionKind kind;

  /// True for the three required Basic Training missions.
  final bool isBasic;

  /// One-time rewards granted on first completion.
  final int xpReward;
  final int coinReward;

  /// Shown when completing this mission unlocks something.
  final String? unlockMessage;

  /// Shown on the mission card before completion (e.g. "Unlocks Daily
  /// Scramble") so pilots can see what each mission is worth.
  final String? unlockPreview;

  /// Gameplay payload for [TrainingMissionKind.flight] missions — passed to
  /// `PlayScreen`, which records completion through the campaign path.
  /// Its id and rewards always match this mission's.
  final CampaignMission? flightMission;
}

// ---------------------------------------------------------------------------
// Training coaches — same instructors (and the owner's portrait art) as the
// Pilot Training campaign, with copy written for the training arc.
// ---------------------------------------------------------------------------

/// Basic Training flight instructor — J.R.D. Tata with a teaser pointing at
/// the rest of Basic Training instead of the campaign roster.
const Coach trainingCoachTata = Coach(
  id: 'jrd_tata_basic',
  name: 'J.R.D. Tata',
  nationality: 'Indian',
  countryCode: 'IN',
  title: 'Basic Flight Instructor',
  bio: 'First Indian to earn a pilot\'s licence in 1929, who pioneered '
      'commercial aviation in India and founded what became Air India.',
  introduction:
      'I am J.R.D. Tata, and this is Basic Training. In 1929, I became the '
      'first Indian to earn a pilot\'s licence. Every airline begins with a '
      'single flight — yours begins now. Take the stick and find your first '
      'countries.',
  greeting: 'A clean first flight. You fly like you were born to it, cadet.',
  farewell: 'This reminds me of my very first solo — hands steady, eyes on the '
      'horizon, a whole world of routes waiting below. You have taken your '
      'first real flight today, and it was a fine one. Your Daily Scramble '
      'clearance has come through — the mission board is open.',
  nextCoachTeaser:
      'Two more Basic Training missions await: Sabiha Gökçen — the world\'s '
      'first female combat pilot — will teach you Recon by compass bearing, '
      'and Lotfia El Nadi will run your first Briefing. Finish both and you '
      'earn your wings.',
  imageAsset: 'assets/images/coaches/Jrd tata.PNG',
);

/// Basic Training recon instructor — Antoine de Saint-Exupéry, who flew real
/// reconnaissance sorties over France. His recon lesson (Training Recon) is a
/// fully guided walkthrough, so his copy teaches the triangulation mechanic
/// from first principles.
const Coach trainingCoachSaintExuperyRecon = Coach(
  id: 'saint_exupery_recon',
  name: 'Antoine de Saint-Exupéry',
  nationality: 'French',
  countryCode: 'FR',
  title: 'Recon Instructor',
  bio: 'French aviator and author of The Little Prince, who flew wartime '
      'reconnaissance missions over France and mail routes across the Sahara.',
  introduction:
      'I am Antoine de Saint-Exupéry. I flew reconnaissance over my own '
      'France — reading the land below to fix where the enemy, and I, truly '
      'were. Recon is exactly that: you cannot see the target, but you know '
      'the directions to places you recognise. Follow those bearings to where '
      'they cross. Come — I will walk you through every step.',
  greeting: 'You read the bearings like a true reconnaissance pilot. France, '
      'found without a single doubt.',
  farewell: 'This reminds me of a dawn sortie over the Rhône valley — no map '
      'in my lap, only the shapes of the land and the directions home. You '
      'triangulated France today the way I once found my way back: by trusting '
      'what the known places told you. Your Daily Recon clearance is through — '
      'the compass is yours to command.',
  nextCoachTeaser:
      'One Basic Training mission remains: Lotfia El Nadi — the first woman in '
      'Africa and the Arab world to earn her wings — will run your first '
      'Briefing. Finish it and you earn your wings.',
  imageAsset: 'assets/images/coaches/Antoine de Saint-Exupery.PNG',
);

/// Advanced Training hints instructor — Saint-Exupéry, teasing the license
/// lesson next in the Advanced track.
const Coach trainingCoachSaintExupery = Coach(
  id: 'saint_exupery_advanced',
  name: 'Antoine de Saint-Exupéry',
  nationality: 'French',
  countryCode: 'FR',
  title: 'Hint School Instructor',
  bio: 'French aviator and author of The Little Prince, who flew mail '
      'routes across the Sahara and survived multiple crashes in the desert.',
  introduction:
      'I am Antoine de Saint-Exupéry. Over the Sahara I learned that even '
      'the best pilot sometimes needs a hint from the stars. This lesson is '
      'about knowing when to ask — and what it costs. Cycle your clues, '
      'spend a hint, and find the target.',
  greeting: 'You asked the sky the right questions. Well navigated.',
  farewell: 'This reminds me of a night over the desert with no chart that '
      'mattered — only the hints the stars offered to those willing to pay '
      'attention. You used your tools wisely today. Remember: each hint '
      'costs more than the last, so spend them like water in the Sahara.',
  nextCoachTeaser:
      'Next in Advanced Training: Al-Muqaddasi will walk you through your '
      'Pilot License — heat, pity, and the free reroll that refreshes every '
      'day. Knowledge compounds, cadet.',
  imageAsset: 'assets/images/coaches/Antoine de Saint-Exupery.PNG',
);

/// Advanced Training fuel instructor — Jean Batten, teasing the shop lesson
/// next in the Advanced track.
const Coach trainingCoachBatten = Coach(
  id: 'jean_batten_advanced',
  name: 'Jean Batten',
  nationality: 'New Zealander',
  countryCode: 'NZ',
  title: 'Fuel Discipline Coach',
  bio: 'Record-breaking New Zealand aviator who flew solo from England '
      'to New Zealand — 14,000 miles in a single-engine Percival Gull.',
  introduction:
      'I\'m Jean Batten. I crossed oceans on a fuel plan measured to the '
      'drop. This lesson puts a real tank under you: reach both targets '
      'before it runs dry, and land with fuel to spare for the bonus. '
      'When you want to earn coins at your own pace, Free Flight pays for '
      'every country you find — no tank pressure, just the open sky.',
  greeting: 'Landed with fuel in the tank — that\'s how records are set.',
  farewell: 'This reminds me of the Tasman crossing — dark water in every '
      'direction and the gauge ticking down, trusting the plan. You flew '
      'with that same discipline today. Take Free Flight out whenever you '
      'want to farm coins and learn the map: every find pays.',
  nextCoachTeaser:
      'Next in Advanced Training: Jorge Chávez opens the Supply Shop — '
      'consumables, the weekly hangar, and how to make every coin count.',
  imageAsset: 'assets/images/coaches/Jean batten.PNG',
);

// ---------------------------------------------------------------------------
// Basic Training — the three required missions (whole set ≤ ~5 minutes)
// ---------------------------------------------------------------------------

/// Flight payload for Training Flight: two easy, adjacent targets with
/// generous fuel-free flying and the interactive controls tutorial.
const CampaignMission trainingFlightMission = CampaignMission(
  id: trainingFlightMissionId,
  order: 1,
  title: 'Training Flight',
  subtitle: 'Learn to fly and find',
  description:
      'Welcome to Basic Training, cadet. Two targets, no fuel pressure. '
      'Read the clue, bank towards the answer, and descend when the country '
      'is below you. That is the whole job — fly and find.',
  coach: trainingCoachTata,
  allowedClues: {ClueType.flag, ClueType.capital},
  rounds: 2,
  maxDifficulty: 0.15,
  targetCountryCodes: ['FR', 'ES'],
  fuelEnabled: false,
  xpReward: 40,
  coinReward: 25,
  unlockMessage: 'Daily Scramble unlocked!',
  // Start over the Bay of Biscay, facing east — France, then Spain next door.
  startLat: 46.0,
  startLng: -9.0,
  startHeading: 0, // east
  tips: [
    CoachTip(
      trigger: 'firstClue',
      message: 'Here is your first clue: the tricolour — blue, white, red — '
          'capital Paris. The country is dead ahead of you. Fly east and '
          'descend over it.',
    ),
    CoachTip(
      trigger: 'correctAnswer',
      message: 'France — well found! One more: red and gold flag, capital '
          'Madrid. It shares a border with the country you just found. '
          'Bank south-west, cadet.',
    ),
    CoachTip(
      trigger: 'wrongRegion',
      message: 'You\'ve drifted off course. Both targets are in western '
          'Europe, side by side. Check the clue and turn back.',
    ),
    CoachTip(
      trigger: 'lost',
      message: 'Steady, cadet. The flag and the capital name the country. '
          'France first, then its neighbour Spain — both on Europe\'s '
          'Atlantic edge.',
    ),
  ],
);

/// The three required Basic Training missions.
const List<TrainingMission> basicTrainingMissions = [
  TrainingMission(
    id: trainingFlightMissionId,
    order: 1,
    title: 'Training Flight',
    subtitle: 'Learn to fly and find',
    description:
        'Welcome to Basic Training, cadet. Two targets, no fuel pressure. '
        'Read the clue, bank towards the answer, and descend when the '
        'country is below you. That is the whole job — fly and find.',
    objective: 'Fly to 2 easy targets',
    coach: trainingCoachTata,
    kind: TrainingMissionKind.flight,
    isBasic: true,
    xpReward: 40,
    coinReward: 25,
    unlockMessage: 'Daily Scramble unlocked!',
    unlockPreview: 'Unlocks Daily Scramble',
    flightMission: trainingFlightMission,
  ),
  TrainingMission(
    id: trainingReconMissionId,
    order: 2,
    title: 'Training Recon',
    subtitle: 'Find France by its neighbours',
    description:
        'You cannot see the target — but you know the countries around it. '
        'I will walk you through it, one clue at a time: Spain to the '
        'south-west, the United Kingdom across the Channel, Algeria over the '
        'sea, Germany and Belgium to the east. Follow those bearings to where '
        'they cross and you will find France. A gentle, guided lesson — no '
        'pressure, just learning to read the compass.',
    objective: 'Learn recon — find France',
    coach: trainingCoachSaintExuperyRecon,
    kind: TrainingMissionKind.recon,
    isBasic: true,
    xpReward: 40,
    coinReward: 25,
    unlockMessage: 'Daily Recon unlocked!',
    unlockPreview: 'Unlocks Daily Recon',
  ),
  TrainingMission(
    id: trainingBriefingMissionId,
    order: 3,
    title: 'Training Briefing',
    subtitle: 'Tap the map, answer the briefing',
    description:
        'Every pilot starts the day with a briefing. I\'ll read you three '
        'short questions about Europe — you answer by tapping the right '
        'country on the map. Quick, calm, precise. That is how briefings '
        'are done.',
    objective: 'Answer a 3-question map quiz',
    coach: coachLotfia,
    kind: TrainingMissionKind.briefing,
    isBasic: true,
    xpReward: 40,
    coinReward: 25,
    unlockMessage: 'Daily Briefing unlocked!',
    unlockPreview: 'Unlocks Daily Briefing',
  ),
];

// ---------------------------------------------------------------------------
// Advanced Training — optional one-time-reward missions after the basics
// ---------------------------------------------------------------------------

/// Flight payload for Hint School: one target, hints encouraged.
const CampaignMission advancedHintSchoolMission = CampaignMission(
  id: 'adv_hint_school',
  order: 5,
  title: 'Hint School',
  subtitle: 'Clue types and hint costs',
  description:
      'Over the Sahara I navigated by starlight and instinct — you have '
      'better tools. Cycle between clue types to cross-reference, and when '
      'you are truly stuck, buy a hint. Each one costs more than the last: '
      '−500, −1,000, −1,500, up to −2,500 for auto-navigate. One target: '
      'the red flag with the green pentagram, capital Rabat.',
  coach: trainingCoachSaintExupery,
  allowedClues: {ClueType.flag, ClueType.capital, ClueType.borders},
  rounds: 1,
  maxDifficulty: 0.25,
  targetCountryCodes: ['MA'],
  fuelEnabled: false,
  xpReward: 60,
  coinReward: 50,
  // Start over the Atlantic west of Morocco, facing east.
  startLat: 31.0,
  startLng: -18.0,
  startHeading: 0, // east
  tips: [
    CoachTip(
      trigger: 'firstClue',
      message: 'Cycle your clues, cadet — flag, capital, and borders each '
          'tell part of the story. Cross-reference them before you commit.',
    ),
    CoachTip(
      trigger: 'firstHint',
      message: 'A good pilot knows when to consult the chart. Remember: '
          'each hint costs more than the last, so ask early or not at all.',
    ),
    CoachTip(
      trigger: 'correctAnswer',
      message: 'Morocco — Rabat, not Casablanca! You read the signs like a '
          'mail pilot. The desert keeps no secrets from you.',
    ),
    CoachTip(
      trigger: 'lost',
      message: 'North-west Africa, cadet. A red flag with a green star, '
          'capital Rabat, coastline on two seas. Spend a hint if you must — '
          'that is what this lesson is for.',
    ),
  ],
);

/// Flight payload for Fuel Run: two targets with a live fuel tank.
const CampaignMission advancedFuelRunMission = CampaignMission(
  id: 'adv_fuel_run',
  order: 7,
  title: 'Fuel Run',
  subtitle: 'Fuel discipline and Free Flight',
  description:
      'Time to fly with a real tank under you. Two island targets: land of '
      'fire and ice first, then the emerald one south of it. Wasted turns '
      'burn fuel, and the fuel you land with pays a bonus — up to 5,000 '
      'points. And remember Free Flight: no tank pressure, coins for every '
      'country you find.',
  coach: trainingCoachBatten,
  allowedClues: {ClueType.flag, ClueType.capital},
  rounds: 2,
  maxDifficulty: 0.25,
  targetCountryCodes: ['IS', 'IE'],
  fuelEnabled: true,
  xpReward: 60,
  coinReward: 50,
  // Start over the North Atlantic, facing north-east toward Iceland.
  startLat: 56.0,
  startLng: -28.0,
  startHeading: -pi / 4, // north-east
  tips: [
    CoachTip(
      trigger: 'firstClue',
      message: 'Watch the gauge from the first second, cadet. Fly straight '
          'lines — every wasted turn is fuel you won\'t get back. First '
          'target: geysers and glaciers, capital Reykjavík.',
    ),
    CoachTip(
      trigger: 'fuelLow',
      message: 'Fuel\'s getting low — commit now! The second target is the '
          'green island with the harp on its arms, capital Dublin. Straight '
          'line, no detours.',
    ),
    CoachTip(
      trigger: 'fuelEmpty',
      message: 'Running on fumes — just like me over the Tasman! Best guess '
          'now: Ireland, south-east of you. Go!',
    ),
    CoachTip(
      trigger: 'correctAnswer',
      message: 'That\'s the discipline! The fuel left in your tank just '
          'became bonus points. When you want coins without the pressure, '
          'take Free Flight out — every find pays.',
    ),
  ],
);

/// The six optional Advanced Training missions, in trail order.
const List<TrainingMission> advancedTrainingMissions = [
  TrainingMission(
    id: 'adv_rated_sortie',
    order: 4,
    title: 'First Sortie',
    subtitle: 'Rated runs and tiers',
    description:
        'The Standard Sortie is where pilots earn their rank: five rated '
        'rounds, one score, a tier ladder that remembers you. They called '
        'me the Lindbergh of Mexico after one flight — your reputation '
        'starts with one run too. Fly a sortie and post a score. The result '
        'matters less than the wheels leaving the ground.',
    objective: 'Complete 1 rated Standard Sortie run',
    coach: coachEmilioCarranza,
    kind: TrainingMissionKind.sortie,
    isBasic: false,
    xpReward: 60,
    coinReward: 75,
  ),
  TrainingMission(
    id: 'adv_hint_school',
    order: 5,
    title: 'Hint School',
    subtitle: 'Clue types and hint costs',
    description:
        'Over the Sahara I navigated by starlight and instinct — you have '
        'better tools. Cycle between clue types to cross-reference, and '
        'when you are truly stuck, buy a hint. Each one costs more than '
        'the last. One target: the red flag with the green pentagram, '
        'capital Rabat.',
    objective: 'Find Morocco using clues and hints',
    coach: trainingCoachSaintExupery,
    kind: TrainingMissionKind.flight,
    isBasic: false,
    xpReward: 60,
    coinReward: 50,
    flightMission: advancedHintSchoolMission,
  ),
  TrainingMission(
    id: 'adv_license',
    order: 6,
    title: 'License Check',
    subtitle: 'Heat, pity and the free reroll',
    description:
        'A thousand years ago I earned my knowledge province by province — '
        'your Pilot License works the same way. Visit the hangar and study '
        'it: heat builds as you play and raises your luck, pity guarantees '
        'a reward when fortune stalls, and one reroll is free every day. '
        'Never let a free reroll go to waste.',
    objective: 'Open the Pilot License hangar',
    coach: coachMuqaddasi,
    kind: TrainingMissionKind.license,
    isBasic: false,
    xpReward: 50,
    coinReward: 50,
  ),
  TrainingMission(
    id: 'adv_fuel_run',
    order: 7,
    title: 'Fuel Run',
    subtitle: 'Fuel discipline and Free Flight',
    description:
        'Time to fly with a real tank under you. Two island targets — land '
        'with fuel to spare and it pays a bonus. And remember Free Flight: '
        'no tank pressure, coins for every country you find.',
    objective: 'Complete a 2-target flight with fuel on',
    coach: trainingCoachBatten,
    kind: TrainingMissionKind.flight,
    isBasic: false,
    xpReward: 60,
    coinReward: 50,
    flightMission: advancedFuelRunMission,
  ),
  TrainingMission(
    id: 'adv_shop',
    order: 8,
    title: 'Supply Line',
    subtitle: 'The shop and the weekly hangar',
    description:
        'Before the Alps, I checked every supply to the gram. Do the same: '
        'browse the Supply Shop — consumables for tough days, the weekly '
        'hangar rotation, and prices worth planning around. Know what your '
        'coins can buy before you need it.',
    objective: 'Browse the Supply Shop',
    coach: coachJorgeChavez,
    kind: TrainingMissionKind.shop,
    isBasic: false,
    xpReward: 50,
    coinReward: 50,
  ),
  TrainingMission(
    id: 'adv_challenge',
    order: 9,
    title: 'Wingman Duel',
    subtitle: 'Head-to-head challenges',
    description:
        'I led five biplanes against an invasion force — you only need one '
        'rival. Open Friends and send a head-to-head challenge (or accept '
        'one waiting for you). The duel counts from the moment the gauntlet '
        'is thrown.',
    objective: 'Send or accept a head-to-head challenge',
    coach: coachVillamor,
    kind: TrainingMissionKind.challenge,
    isBasic: false,
    xpReward: 75,
    coinReward: 75,
  ),
];

/// Every training mission in trail order (basic first, then advanced).
const List<TrainingMission> allTrainingMissions = [
  ...basicTrainingMissions,
  ...advancedTrainingMissions,
];

/// Look up a training mission by ID.
TrainingMission? getTrainingMission(String id) {
  for (final mission in allTrainingMissions) {
    if (mission.id == id) return mission;
  }
  return null;
}
