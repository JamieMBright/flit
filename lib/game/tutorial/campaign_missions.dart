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
        'My father said a woman had no place in the cockpit. I enrolled in '
        'secret and proved him wrong. Now — can you identify the flag of my '
        'homeland from its colours and symbol alone?',
    coach: coachLotfia,
    allowedClues: {ClueType.flag},
    rounds: 2,
    maxDifficulty: 0.20,
    targetCountryCodes: ['EG'],
    fuelEnabled: false,
    xpReward: 75,
    coinReward: 50,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'Three horizontal stripes — red, white, black — with a golden '
            'eagle at the centre. That eagle has watched over my homeland for '
            'centuries. Which nation flies this flag?',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Egypt! The Eagle of Saladin stands proud on our flag, just as I '
            'stood proud becoming the first Arab woman to earn a pilot\'s '
            'licence. This nation soars — and so do we.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'Not that region, cadet. Those Pan-Arab colours — red, white, '
            'black — belong to North Africa. Look towards the northeast '
            'corner of the continent.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Red above, white in the middle, black below — and a golden eagle '
            'that has symbolised power since the time of Saladin. This is one '
            'of the oldest civilisations on Earth. Think pyramids.',
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
    description:
        'I circled the Eiffel Tower to prove flight was possible — then '
        'flew home to my beloved Brazil. Everyone thinks Rio is our capital. '
        'They are wrong. Can you name the true capital of my homeland?',
    coach: coachSantosDumont,
    allowedClues: {ClueType.capital},
    rounds: 2,
    maxDifficulty: 0.25,
    targetCountryCodes: ['BR'],
    fuelEnabled: false,
    xpReward: 75,
    coinReward: 50,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'The capital is Brasília — not Rio de Janeiro, as many assume. '
            'It was purpose-built and inaugurated in 1960. Now fly to the '
            'great South American nation that built a capital from nothing!',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Brasil! I was born in São Paulo state and dreamed my whole life '
            'of flight. When I circled the Eiffel Tower in 1906, I did it '
            'for this country. Remember — Brasília, not Rio!',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'You\'re building a solid mental map, cadet — just as I charted '
            'the skies over Paris before conquering them. Keep going.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Think of the largest country in South America — that\'s where '
            'you\'re headed. Its capital sits in the interior highlands, '
            'not on the famous coastline. Brasília is your target.',
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
        'I flew 22 combat missions and logged over 8,000 hours — you learn '
        'to read every signal at once. Borders AND flag together. Cross-'
        'reference them and find my homeland.',
    coach: coachSabiha,
    allowedClues: {ClueType.borders, ClueType.flag},
    rounds: 2,
    maxDifficulty: 0.30,
    targetCountryCodes: ['TR'],
    fuelEnabled: false,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'You have two signals: the neighbours and the flag. My homeland '
            'touches Europe and Asia both — Greece, Bulgaria, Georgia, '
            'Armenia, Iran, Iraq, Syria. And the flag is red with a crescent.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Turkey! The red flag with crescent and star is one of the most '
            'recognised in the world. I was proud to defend it in the cockpit '
            'as the world\'s first female combat pilot.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'Cross-reference both clues. The red crescent flag and those '
            'neighbours — Europe to the west, Middle East to the south — '
            'point to one nation straddling two continents.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'In combat, I never had the luxury of guessing. Use the flag: '
            'solid red, white crescent and star. Then use the borders: '
            'eight neighbours from the Balkans to the Caucasus to Arabia.',
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
        'I flew 14,000 miles solo from England to my homeland in a single-'
        'engine Percival Gull. Over open ocean, every drop of fuel was life '
        'itself. Now the gauge is live — fly smart or you won\'t arrive.',
    coach: coachJeanBatten,
    allowedClues: {ClueType.borders, ClueType.flag, ClueType.capital},
    rounds: 2,
    maxDifficulty: 0.25,
    targetCountryCodes: ['NZ'],
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'My homeland is an island nation — no land borders, so neighbours '
            'won\'t help you here. Use the flag and capital: Wellington. '
            'It sits at the bottom of the world, far from everything.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message:
            'Fuel\'s getting low — exactly how it felt mid-Pacific with no '
            'runway in sight. Descend to conserve and commit to your answer. '
            'Wellington, New Zealand.',
      ),
      CoachTip(
        trigger: 'fuelEmpty',
        message: 'Running on fumes! I once nearly ditched in the Tasman Sea. '
            'Make your best guess now — fly south into the Pacific.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'No neighbours means isolation — and isolation means fuel '
            'discipline. Think remote Pacific, capital Wellington, flag with '
            'Union Jack and Southern Cross. That\'s New Zealand.',
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
        'What is essential is invisible to the eye — yet the flag and capital '
        'of my homeland are plain to see, if you know where to look. I flew '
        'mail across the Sahara by starlight. Fly now to the land of the '
        'tricolour.',
    coach: coachSaintExupery,
    allowedClues: {ClueType.flag, ClueType.capital},
    rounds: 2,
    maxDifficulty: 0.35,
    targetCountryCodes: ['FR'],
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    unlockMessage: 'Daily Briefing unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'Blue, white, red — three vertical stripes, the tricolour. And '
            'the capital is Paris, city of lights I once circled by night '
            'carrying the mail. Which homeland flies this flag?',
      ),
      CoachTip(
        trigger: 'firstHint',
        message: 'A good pilot knows when to consult the chart. I used every '
            'star in the Saharan sky when my instruments failed. Use your '
            'hint — but keep the cost in mind.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'France! My dear homeland. I wrote The Little Prince in exile, '
            'dreaming of her skies. To land in Paris is to come home — '
            'the essential things were never invisible after all.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'The tricolour and the capital of romance point to one nation. '
            'I survived a crash in the Libyan desert thinking of France. '
            'Look to Western Europe — Paris is waiting.',
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
    description: 'Before I crossed the Alps I measured everything — altitude, '
        'wind speed, fuel to the gram. My homeland has roughly 34 million '
        'people and 1.28 million square kilometres. Numbers don\'t lie. '
        'Read them and fly to Peru.',
    coach: coachJorgeChavez,
    allowedClues: {ClueType.stats},
    rounds: 2,
    maxDifficulty: 0.30,
    targetCountryCodes: ['PE'],
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'Study the figures — roughly 34 million people, 1.28 million '
            'square kilometres, currency the Sol, capital Lima. Every number '
            'is a coordinate. Plot your course.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'Arriba, siempre arriba — higher, always higher. Those were my '
            'last words after crossing the Alps. Keep climbing through the '
            'data; you\'re getting closer.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'The numbers point to South America — mid-sized population, '
            'large Andean nation, currency the Sol. Lima airport bears my '
            'name. Think about that.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'I calculated every variable before Simplon Pass and still '
            'nearly paid with my life. Use the stats: South America, '
            'capital Lima, ~34 million people. That is Peru.',
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
        'I grew up on the Kenyan plains, tracking animals by the shape '
        'of their silhouettes from the air. Every country has a shape as '
        'distinctive as a lion\'s profile. Study the outline and find my '
        'homeland.',
    coach: coachBerylMarkham,
    allowedClues: {ClueType.outline},
    rounds: 2,
    maxDifficulty: 0.25,
    targetCountryCodes: ['KE'],
    fuelEnabled: true,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'East Africa — a shape bordered by Tanzania, Uganda, Somalia, '
            'Ethiopia, and South Sudan, with a coastline on the Indian Ocean. '
            'I tracked elephants over this land from a bush plane. Recognise it?',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Kenya! I learned to read this landscape before I could read '
            'a map — the Nandi taught me to see the savannah from above. '
            'You have the same instinct. Well flown.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'Look to East Africa. In "West with the Night" I wrote of '
            'hunting elephants by silhouette at dawn — this country\'s '
            'outline is just as unmistakable on the map.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'A bush pilot survives by reading shapes — terrain, cloud, '
            'animal. This outline sits on the equator in East Africa, '
            'touching the Indian Ocean coast. That is Kenya.',
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
        'In 1928 I flew nonstop from Mexico City to Washington D.C. on a '
        'goodwill mission — using every skill I had. Now every clue type '
        'is live. Cross-reference flag, shape, borders, stats, and capital '
        'to find my homeland and prove you\'re ready.',
    coach: coachEmilioCarranza,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.45,
    targetCountryCodes: ['MX'],
    fuelEnabled: true,
    xpReward: 125,
    coinReward: 100,
    unlockMessage: 'Daily Challenge unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'All clues are open — use them all. Green, white, and red flag '
            'with an eagle on a cactus. Capital is Mexico City. Distinctive '
            'shape bordering the USA to the north. Where am I from?',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'My goodwill flight had no room for hesitation either. Commit '
            'to the answer your clues are pointing to — cross the border '
            'south of the United States.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Mexico! The nation I carried a message of friendship for across '
            'two thousand miles of sky. The eagle on the cactus never looked '
            'so proud. Outstanding flying, cadet.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Cross-reference everything: the eagle-and-cactus flag, the '
            'borders with the USA, Guatemala, and Belize, the capital Mexico '
            'City. That combination points to one country.',
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
        'A thousand years ago, I walked every province of the known world '
        'and wrote the first true geography. Your licence is your '
        'accumulated knowledge — XP, coins, and stars. Fly to the land '
        'of Mecca and Medina, the heart of my travels.',
    coach: coachMuqaddasi,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.50,
    targetCountryCodes: ['SA'],
    fuelEnabled: true,
    xpReward: 125,
    coinReward: 100,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'I documented every land from the Nile to the Oxus. This nation '
            'holds Mecca and Medina — the centre of my world. Study your '
            'clues and fly to the Arabian Peninsula.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'Halfway — just as I was when I reached Baghdad on my great '
            'journey. Every correct answer earns XP for your licence. '
            'Keep building your knowledge.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Saudi Arabia! The land of the two holy mosques. I walked '
            'these sands a millennium ago and mapped them for the world. '
            'Your licence grows with every correct answer.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'The largest country on the Arabian Peninsula, home to Mecca '
            'and Medina, capital Riyadh. Bordered by Jordan, Iraq, Kuwait, '
            'Qatar, UAE, Oman, and Yemen. That is Saudi Arabia.',
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
        'I defended Manila with five biplanes against Japanese bombers. '
        'Outnumbered, outgunned — but never outfought. The daily modes are '
        'like combat: timed, unforgiving, and no second chances. This mission '
        'prepares you for the skies above my Philippine homeland.',
    coach: coachVillamor,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.55,
    targetCountryCodes: ['PH'],
    fuelEnabled: true,
    xpReward: 150,
    coinReward: 100,
    unlockMessage: 'Dogfight unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'My homeland is an archipelago of over 7,000 islands in Southeast '
            'Asia. Its flag bears a sun and three stars — and it taught me that '
            'courage matters more than numbers.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'I flew until my engines quit over Manila Bay. Fuel low means '
            'commit now — pick your target and go, just as I did against '
            'those bombers.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'The Philippines! My beloved archipelago. I defended her skies '
            'with everything I had. That\'s the precision and heart I expect '
            'from you.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Think of an island nation in Southeast Asia — thousands of '
            'islands, capital Manila, flag with a white triangle and a golden '
            'sun. I fought and bled for every one of those islands.',
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
        'I died at 25 flying for Indonesian independence — earning your wings '
        'means everything to those who never got the chance. This is your '
        'graduation flight. Navigate the skies of my homeland, the world\'s '
        'largest archipelago, and prove you\'ve earned the right to fly.',
    coach: coachHalim,
    allowedClues: _allClueTypes,
    rounds: 3,
    maxDifficulty: 0.60,
    targetCountryCodes: ['ID'],
    fuelEnabled: true,
    xpReward: 200,
    coinReward: 150,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'My homeland is the world\'s largest archipelago — over 17,000 '
            'islands stretching across Southeast Asia, from Sumatra to Papua. '
            'Find the vast island nation whose capital is Jakarta.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'Halfway to your wings. I fought for Indonesian freedom so that '
            'others could fly freely. Keep the momentum — you\'re almost '
            'there.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Indonesia! Merdeka — freedom! I flew those missions so my '
            'nation could be free. You\'ve earned your wings today, cadet. '
            'The world is yours.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'Think of the archipelago nation between the Indian and Pacific '
            'oceans — it borders Malaysia, Papua New Guinea, and Timor-Leste. '
            'Over 17,000 islands. Capital Jakarta. That\'s Indonesia.',
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
        'I flew 45 combat missions over Europe, then led my island nation to '
        'independence. The broken trident on our flag is no accident — it '
        'marks our break from the past. This is the ace challenge: maximum '
        'difficulty, all clues, no mercy. Show me you belong in the sky.',
    coach: coachErrolBarrow,
    allowedClues: _allClueTypes,
    rounds: 4,
    maxDifficulty: 0.70,
    targetCountryCodes: ['BB'],
    fuelEnabled: true,
    xpReward: 250,
    coinReward: 200,
    unlockMessage: 'All game modes unlocked! Fly safe, ace.',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'My homeland is a small Caribbean island with a striking flag — '
            'a broken trident on blue and gold, symbolising our break from '
            'colonial rule. Find Barbados in the Lesser Antilles.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'I flew 45 missions over occupied Europe and never hesitated. '
            'Fuel is critical — commit to your answer now, just as I committed '
            'to every bombing run.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Barbados! The broken trident flies free. I fought in the sky '
            'over Europe so that island could one day govern herself. '
            'Ace-level flying — well done.',
      ),
      CoachTip(
        trigger: 'lost',
        message:
            'A small island in the eastern Caribbean — capital Bridgetown, '
            'flag with a broken trident on blue and gold. I led this nation '
            'to independence in 1966. Cross-reference every clue.',
      ),
    ],
  ),
];
