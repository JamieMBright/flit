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
        'secret and proved him wrong. Before I take you to my homeland, '
        'let\'s study some of the world\'s most recognisable flags — '
        'starting with two nations whose banners everyone knows.',
    coach: coachLotfia,
    allowedClues: {ClueType.flag},
    rounds: 3,
    maxDifficulty: 0.20,
    targetCountryCodes: ['US', 'GB', 'EG'],
    fuelEnabled: false,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message:
            'Let\'s start with the most famous flag in the world. Thirteen '
            'red and white stripes for the original colonies, fifty white '
            'stars on a blue field — one for every state. The red stands for '
            'hardiness and valour, white for purity, blue for vigilance and '
            'justice. Which nation flies the Stars and Stripes?',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'Now a flag made of three crosses layered into one — the Union '
            'Jack. The red cross of St George for England, the white saltire '
            'of St Andrew for Scotland, and the red saltire of St Patrick '
            'for Ireland — all woven together. It flies over the nation that '
            'once ruled a quarter of the globe. Where does it fly?',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Well spotted! Now for my homeland — three horizontal stripes: '
            'red for sacrifice, white for the bright future, black for the '
            'dark colonial past. The golden Eagle of Saladin at the centre '
            'has guarded Egypt since my foremothers\' time. I was proud to '
            'become the first Arab woman with a pilot\'s licence under that '
            'eagle\'s gaze.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'Study the colours and symbols carefully, cadet. Every element '
            'on a flag tells a story — stripes, stars, crosses, eagles. '
            'Read the story and you\'ll find the nation.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Flags are a nation\'s identity stitched into cloth. Look at '
            'the arrangement — horizontal or vertical stripes? Stars or '
            'crescents? Each design is unique. Match the pattern to the '
            'country you know it belongs to.',
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
        'flew home to my beloved Brazil. But capitals are tricky, cadet. '
        'The biggest city is rarely the capital. Let me show you three '
        'nations where everyone gets the capital wrong.',
    coach: coachSantosDumont,
    allowedClues: {ClueType.capital},
    rounds: 3,
    maxDifficulty: 0.25,
    targetCountryCodes: ['AU', 'ZA', 'BR'],
    fuelEnabled: false,
    xpReward: 100,
    coinReward: 75,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'Everyone says Sydney — the Opera House, the Harbour Bridge. '
            'But Sydney is not the capital. When the new nation federated '
            'in 1901, Sydney and Melbourne couldn\'t agree on who should '
            'be capital, so they built a brand new city between them — '
            'Canberra. Fly to the land down under!',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'Here\'s a nation with not one but THREE capitals! Pretoria '
            'is the administrative capital, Cape Town the legislative, and '
            'Bloemfontein the judicial. People guess Johannesburg because '
            'it\'s the biggest city — but Jo\'burg holds none of those '
            'titles. Fly to the rainbow nation at Africa\'s southern tip.',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'Excellent! Now for my homeland. Everyone thinks Rio de Janeiro '
            'is Brazil\'s capital — the carnival, Copacabana, Christ the '
            'Redeemer. But Rio lost that title in 1960 when President '
            'Kubitschek built Brasília from scratch in the interior '
            'highlands. A capital born from nothing but vision — just like '
            'my flying machines. Remember: Brasília, not Rio!',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message:
            'The biggest city tricks you every time, cadet. The capital is '
            'often a compromise — built fresh or chosen precisely because '
            'it wasn\'t the obvious city. Think carefully.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'Capitals fool even seasoned travellers. Australia\'s capital '
            'is Canberra (not Sydney), South Africa\'s is Pretoria (not '
            'Johannesburg), and Brazil\'s is Brasília (not Rio). Which '
            'one are you looking for right now?',
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
        'to read every signal at once. Borders AND flags together. Before '
        'we reach my homeland, I\'ll test you on two nations first — use '
        'their borders and flags to cross-reference your way there.',
    coach: coachSabiha,
    allowedClues: {ClueType.borders, ClueType.flag},
    rounds: 3,
    maxDifficulty: 0.30,
    targetCountryCodes: ['FR', 'MX', 'TR'],
    fuelEnabled: false,
    xpReward: 125,
    coinReward: 100,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'First target — a European heavyweight. Check the borders: '
            'Spain, Belgium, Luxembourg, Germany, Switzerland, Italy, '
            'Monaco, and Andorra. Eight neighbours! And the flag is a '
            'simple vertical tricolour — blue, white, red. That '
            'combination of borders and flag points to one nation.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message:
            'Now cross the Atlantic. This nation\'s flag has three vertical '
            'stripes — green, white, red — with an eagle perched on a '
            'cactus devouring a serpent at the centre. Its neighbours are '
            'the USA to the north and Guatemala and Belize to the south. '
            'Borders and flag together — where are you heading?',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'Now for my homeland. The red flag with a white crescent and '
            'star is one of the most recognised in the world. Eight '
            'neighbours spanning two continents — Greece and Bulgaria to '
            'the west, Georgia and Armenia to the northeast, Iran, Iraq, '
            'and Syria to the south. Turkey — the nation I defended as '
            'the world\'s first female combat pilot.',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'Cross-reference both signals, cadet. The flag tells you the '
            'identity, the borders tell you the neighbourhood. When both '
            'agree, you have your answer. Don\'t guess — deduce.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'In combat, I never had the luxury of guessing. Read the flag '
            'for the nation\'s identity, then confirm with the borders. '
            'France, Mexico, Turkey — each has a distinctive flag and '
            'a unique set of neighbours. Match them.',
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
        'engine Percival Gull — across continents, over open ocean, through '
        'storms. Every drop of fuel was life itself. I\'m taking you on '
        'the same kind of journey: far-flung corners of the globe before '
        'we head home. Watch that gauge, cadet.',
    coach: coachJeanBatten,
    allowedClues: {ClueType.borders, ClueType.flag, ClueType.capital},
    rounds: 4,
    maxDifficulty: 0.25,
    targetCountryCodes: ['IS', 'MG', 'FJ', 'NZ'],
    fuelEnabled: true,
    xpReward: 125,
    coinReward: 100,
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'We\'re heading to the far reaches of the world — places most '
            'pilots never see. First stop: a volcanic island in the North '
            'Atlantic, land of fire and ice, geysers and glaciers. Use your '
            'clues and watch your fuel — it\'s a long way from anywhere.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'Now we swing to the other side of the world. An enormous '
            'island off the southeast coast of Africa — the fourth largest '
            'island on Earth, home to lemurs and baobabs. Then onward to '
            'a scattering of islands in the South Pacific. Keep an eye on '
            'that fuel gauge — we\'re far from home.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'Fuel\'s getting low — just like mine over the Tasman Sea! '
            'We need to reach my homeland: New Zealand, capital Wellington, '
            'at the bottom of the world. The more fuel you have when you '
            'land, the higher your score — up to 5,000 bonus points. '
            'Commit now and fly south into the Pacific.',
      ),
      CoachTip(
        trigger: 'fuelEmpty',
        message: 'Running on fumes! I nearly ditched in the Tasman Sea on my '
            'record flight. Make your best guess now — my homeland sits '
            'at the bottom of the Pacific. Wellington, New Zealand. Go!',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message: 'New Zealand! After all those far-flung stops — Iceland, '
            'Madagascar, Fiji — you made it home with fuel to spare. '
            'That\'s how I felt touching down after 14,000 miles of solo '
            'flight. Welcome to my homeland, cadet.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'We\'ve been to Iceland in the North Atlantic, Madagascar off '
            'Africa, and Fiji in the South Pacific. Now I need you to find '
            'my homeland — an island nation even further south, capital '
            'Wellington, flag with Union Jack and Southern Cross. That\'s '
            'New Zealand.',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  // Mission 6 — The Sahara Mail Run (Antoine de Saint-Exupéry)
  // -----------------------------------------------------------------------
  CampaignMission(
    id: 'hint_strategy',
    order: 6,
    title: 'The Sahara Mail Run',
    subtitle: 'Deliver the post',
    description:
        'In 1927 I became airmail chief for the Casablanca–Dakar route — '
        'flying alone over the Sahara at night, navigating by starlight '
        'and instinct. Today you\'ll retrace my route. We start over the '
        'Atlantic flying east. Watch the country names as you cross them '
        '— you\'ll need that memory when the mail starts moving.',
    coach: coachSaintExupery,
    allowedClues: {ClueType.flag, ClueType.capital},
    rounds: 7,
    maxDifficulty: 0.35,
    targetCountryCodes: ['EG', 'MA', 'TD', 'DZ', 'SN', 'LY', 'FR'],
    fuelEnabled: true,
    xpReward: 200,
    coinReward: 150,
    unlockMessage: 'Daily Briefing unlocked!',
    tips: [
      CoachTip(
        trigger: 'firstClue',
        message: 'We are now approaching the Sahara desert — the vast golden '
            'ocean I once flew over alone in a rattling Bréguet 14. Below '
            'us, sand dunes stretch to the horizon. Keep your eyes on the '
            'country names as they appear — you\'ll need that memory. Our '
            'first stop is Cairo to collect the mail. Head east!',
      ),
      CoachTip(
        trigger: 'correctAnswer',
        message:
            'We\'ve got the mail! Cairo, the city where the Nile meets the '
            'desert. Now our first shipment goes to Morocco — can you '
            'remember where it was? Morocco\'s flag is solid red with a '
            'green pentagram at the centre. The red represents the ruling '
            'Alaouite dynasty and the descendants of the Prophet, while '
            'the green star — the Seal of Solomon — stands for life, '
            'health, and wisdom. Head to the capital: Rabat, not '
            'Casablanca or Marrakech! And remember — slower speeds give '
            'you much finer control, and descending makes steering even '
            'easier. Use both when you need precision.',
      ),
      CoachTip(
        trigger: 'halfwayDone',
        message: 'Halfway through the mail run! Next shipment heads deep into '
            'the heart of Africa. The Sahara swallowed many pilots before '
            'me — I myself crashed in the Libyan desert and nearly died '
            'of thirst. But the mail must go through. Use your flag and '
            'capital clues to find each destination. Every hint costs '
            'more than the last: −500, −1,000, −1,500, up to −2,500 for '
            'auto-navigate. Spend them wisely!',
      ),
      CoachTip(
        trigger: 'firstHint',
        message: 'A good pilot knows when to consult the chart — but each hint '
            'costs more than the last. I once flew the entire Sahara route '
            'with nothing but a compass and the stars. You have more tools '
            'than I ever did — use them wisely, cadet.',
      ),
      CoachTip(
        trigger: 'fuelLow',
        message: 'Fuel\'s running low! I remember the terror of watching my '
            'gauge drop over the empty Sahara with no airstrip for five '
            'hundred miles. Our final shipment brings us home to France — '
            'the tricolour, blue-white-red, capital Paris. Commit now and '
            'fly north to the land I wrote The Little Prince dreaming of.',
      ),
      CoachTip(
        trigger: 'fuelEmpty',
        message: 'Running on fumes — just as I was when I crash-landed in the '
            'Libyan desert! Head north to France. Paris is waiting. The '
            'mail must arrive!',
      ),
      CoachTip(
        trigger: 'wrongRegion',
        message: 'You\'ve drifted off the route, cadet. My mail runs crossed '
            'North and West Africa — Morocco, Algeria, Senegal, Libya, '
            'Chad, and Egypt are all in that belt. Check your flag and '
            'capital clues to get your bearings.',
      ),
      CoachTip(
        trigger: 'lost',
        message: 'When I was lost in the desert, I followed the stars. Follow '
            'your clues — the flag tells you the nation, the capital tells '
            'you where to land. Our mail route covers Egypt, Morocco, '
            'Chad, Algeria, Senegal, Libya, and finally home to France.',
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
            'Arriba, siempre arriba — higher, always higher! Harder countries '
            'earn a higher score multiplier. An obscure nation can be worth '
            'nearly double a well-known one. Risk and reward, cadet.',
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
        message: 'Wrong region — and every wrong approach burns fuel. Flying '
            'accurately matters: less fuel wasted means a bigger fuel bonus. '
            'Look to East Africa — this silhouette is unmistakable.',
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
        message: 'Fuel low — and stars are on the line! Score 80% or above for '
            '3 stars, 50% for 2. My goodwill flight had no room for '
            'hesitation either. Commit now — south of the United States.',
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
        message: 'Halfway — just as I was when I reached Baghdad. Every flight '
            'earns XP and coins. Level up your Pilot Licence to boost fuel '
            'capacity and coin earnings. Knowledge compounds, cadet.',
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
        message: 'In daily challenges, speed is score — land within 10 seconds '
            'for full points, or lose up to 5,000 to the clock. Fuel low '
            'means commit now, just as I did over Manila Bay.',
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
        message: 'Halfway to your wings. Remember everything: fuel bonus, hint '
            'costs, difficulty multiplier, star thresholds, and your licence. '
            'Master them all and the world is yours.',
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
