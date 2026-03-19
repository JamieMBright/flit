/// Asian country clue data for the regional game mode.
/// Covers all 47 Asian nations.
library;

class AsiaClueData {
  const AsiaClueData({
    required this.nickname,
    required this.famousLandmark,
    required this.famousPerson,
    required this.flag,
  });

  final String nickname;
  final String famousLandmark;
  final String famousPerson;
  final String flag;
}

abstract class AsiaClues {
  static const Map<String, AsiaClueData> data = {
    'AE': AsiaClueData(
      nickname: 'The Land of the Emirates',
      famousLandmark: 'Burj Khalifa',
      famousPerson: 'Sheikh Zayed bin Sultan Al Nahyan',
      flag:
          'The red represents courage, the green symbolises fertility, the white represents peace, and the black represents the defeat of enemies — the Pan-Arab colours also reflect unity among the seven emirates and the broader Arab world',
    ),
    'AF': AsiaClueData(
      nickname: 'The Graveyard of Empires',
      famousLandmark: 'Buddhas of Bamiyan',
      famousPerson: 'Ahmad Shah Durrani',
      flag:
          'Vertical black, red, and green stripes with white national emblem in center',
    ),
    'AM': AsiaClueData(
      nickname: 'The Land of Noah',
      famousLandmark: 'Geghard Monastery',
      famousPerson: 'Charles Aznavour',
      flag:
          'The red symbolises the Armenian Highland, the struggle for survival, and Christian faith; the blue represents the will to live under peaceful skies; the orange represents the creative nature and hard-working character of the Armenian people',
    ),
    'AZ': AsiaClueData(
      nickname: 'The Land of Fire',
      famousLandmark: 'Flame Towers',
      famousPerson: 'Heydar Aliyev',
      flag:
          'The blue represents Turkic heritage, the red symbolises modernisation and progress, the green represents Islam; the crescent and eight-pointed star reflect the Turkic world — the eight points represent the eight Turkic peoples',
    ),
    'BD': AsiaClueData(
      nickname: 'The Land of Rivers',
      famousLandmark: 'Sundarbans Mangrove Forest',
      famousPerson: 'Sheikh Mujibur Rahman',
      flag:
          'The dark green represents the lush vegetation of Bangladesh, and the red disc symbolises the rising sun and the blood shed in the 1971 Liberation War — the disc is offset toward the hoist so it appears centred when the flag flies',
    ),
    'BH': AsiaClueData(
      nickname: 'The Pearl of the Gulf',
      famousLandmark: 'Bahrain World Trade Center',
      famousPerson: 'Salman bin Hamad Al Khalifa',
      flag:
          'White field at hoist with red field at fly separated by serrated line of five points',
    ),
    'BN': AsiaClueData(
      nickname: 'The Abode of Peace',
      famousLandmark: 'Omar Ali Saifuddien Mosque',
      famousPerson: 'Sultan Hassanal Bolkiah',
      flag:
          'The yellow field represents the Sultan, the white and black diagonal stripes symbolise the chief ministers, and the national crest bears the crescent of Islam with the motto "Always in service with God\'s guidance" — reflecting Brunei\'s Islamic monarchy',
    ),
    'BT': AsiaClueData(
      nickname: 'The Land of the Thunder Dragon',
      famousLandmark: 'Tiger\'s Nest Monastery',
      famousPerson: 'Jigme Singye Wangchuck',
      flag:
          'The dragon (Druk, the Thunder Dragon) gives Bhutan its native name "Druk Yul"; the orange represents the Buddhist spiritual tradition, the saffron-yellow represents the secular authority of the king, and the jewels in the dragon\'s claws symbolise national wealth',
    ),
    'CN': AsiaClueData(
      nickname: 'The Middle Kingdom',
      famousLandmark: 'Great Wall of China',
      famousPerson: 'Confucius',
      flag:
          'The red symbolises the Communist revolution, the large gold star represents the Communist Party of China, and the four smaller stars represent the four social classes — workers, peasants, petty bourgeoisie, and national bourgeoisie — united under the Party',
    ),
    'GE': AsiaClueData(
      nickname: 'The Balcony of Europe',
      famousLandmark: 'Jvari Monastery',
      famousPerson: 'Joseph Stalin',
      flag:
          'The white field represents purity and innocence, and the five red crosses (one large St. George\'s cross and four smaller Bolnisi crosses) are ancient Georgian Christian symbols — the design recalls medieval Georgian kingdom banners',
    ),
    'ID': AsiaClueData(
      nickname: 'The Emerald of the Equator',
      famousLandmark: 'Borobudur Temple',
      famousPerson: 'Sukarno',
      flag:
          'The red and white bicolour derives from the 13th-century Majapahit Empire; red symbolises courage and white represents purity — the simplicity reflects the national motto "Unity in Diversity"',
    ),
    'IL': AsiaClueData(
      nickname: 'The Holy Land',
      famousLandmark: 'Western Wall',
      famousPerson: 'David Ben-Gurion',
      flag:
          'The blue and white represent the traditional Jewish prayer shawl (tallit), and the blue Star of David (Magen David) has been a symbol of Jewish identity since the Middle Ages — the flag was designed by the Zionist movement in 1891',
    ),
    'IN': AsiaClueData(
      nickname: 'The Land of Spices',
      famousLandmark: 'Taj Mahal',
      famousPerson: 'Mahatma Gandhi',
      flag:
          'The saffron represents courage and sacrifice, the white represents truth and peace, the green represents faith and fertility; the Ashoka Chakra (24-spoke wheel) in the centre symbolises dharma (righteousness) and was adopted from the Lion Capital of Ashoka',
    ),
    'IQ': AsiaClueData(
      nickname: 'The Cradle of Civilization',
      famousLandmark: 'Ziggurat of Ur',
      famousPerson: 'Hammurabi',
      flag:
          'The red-white-black horizontal tricolour uses Pan-Arab colours; the Takbir ("Allahu Akbar" — God is Greatest) in green Kufic script was added to the white stripe — the current script version was adopted in 2008 to replace Saddam-era handwriting',
    ),
    'IR': AsiaClueData(
      nickname: 'The Land of the Aryans',
      famousLandmark: 'Persepolis',
      famousPerson: 'Cyrus the Great',
      flag:
          'The green represents Islam, the white symbolises peace, the red represents courage; the stylised word "Allah" is repeated 22 times along the stripe borders (commemorating the revolution on 22 Bahman), and the central emblem represents "La ilaha illallah" (There is no God but Allah)',
    ),
    'JO': AsiaClueData(
      nickname: 'The Hashemite Kingdom',
      famousLandmark: 'Petra',
      famousPerson: 'King Hussein',
      flag:
          'The black, white, and green horizontal stripes represent the Abbasid, Umayyad, and Fatimid dynasties; the red triangle represents the Hashemite dynasty and the Arab Revolt of 1916, and the seven-pointed star symbolises the seven verses of the opening sura of the Quran',
    ),
    'JP': AsiaClueData(
      nickname: 'The Land of the Rising Sun',
      famousLandmark: 'Mount Fuji',
      famousPerson: 'Emperor Meiji',
      flag:
          'The white field represents honesty and purity, and the red circle (Hinomaru) symbolises the sun — Japan is known as "Nippon" (origin of the sun), and the design has been used for centuries by feudal lords and imperial courts',
    ),
    'KG': AsiaClueData(
      nickname: 'The Switzerland of Central Asia',
      famousLandmark: 'Issyk-Kul Lake',
      famousPerson: 'Chingiz Aitmatov',
      flag:
          'The red field represents the banner of the legendary hero Manas, the golden sun with 40 rays represents the 40 Kyrgyz tribes united by Manas, and the symbol inside the sun depicts the tunduk — the crown of a traditional Kyrgyz yurt, symbolising family and the universe',
    ),
    'KH': AsiaClueData(
      nickname: 'The Kingdom of Wonder',
      famousLandmark: 'Angkor Wat',
      famousPerson: 'Norodom Sihanouk',
      flag:
          'The blue stripes represent royalty, the red symbolises the nation and its people, and the white Angkor Wat temple in the centre is a source of immense national pride — Cambodia is the only country in the world to feature a building on its flag',
    ),
    'KP': AsiaClueData(
      nickname: 'The Hermit Kingdom',
      famousLandmark: 'Kumsusan Palace of the Sun',
      famousPerson: 'Kim Il-sung',
      flag:
          'The red field represents revolutionary traditions and patriotism, the blue stripes symbolise sovereignty and peace, the white stripes represent purity, and the red star on the white disc represents the ideals of communism',
    ),
    'KR': AsiaClueData(
      nickname: 'The Land of the Morning Calm',
      famousLandmark: 'Gyeongbokgung Palace',
      famousPerson: 'King Sejong the Great',
      flag:
          'The white background represents peace and purity; the central Taeguk (yin-yang) symbolises the balance of cosmic forces; the four black trigrams from the I Ching represent heaven, earth, water, and fire — the design reflects Korean philosophical and cosmological traditions',
    ),
    'KW': AsiaClueData(
      nickname: 'The Pearl of the Gulf',
      famousLandmark: 'Kuwait Towers',
      famousPerson: 'Sheikh Abdullah Al-Salem Al-Sabah',
      flag:
          'The green represents fertile land, the white symbolises peace, the red represents the blood of enemies, and the black trapezoid represents the defeat of enemies — colours drawn from a verse by the Iraqi poet Safie Al-Deen Al-Hilli about Arab virtues',
    ),
    'KZ': AsiaClueData(
      nickname: 'The Land of the Great Steppe',
      famousLandmark: 'Bayterek Tower',
      famousPerson: 'Al-Farabi',
      flag:
          'The sky blue represents the Turkic peoples and the endless sky, the golden sun with 32 rays represents abundance and life, the soaring steppe eagle symbolises freedom, and the ornamental pattern along the hoist is a traditional Kazakh "koshkar-muiz" (ram\'s horn) design',
    ),
    'LA': AsiaClueData(
      nickname: 'The Land of a Million Elephants',
      famousLandmark: 'Luang Prabang',
      famousPerson: 'Kaysone Phomvihane',
      flag:
          'The red stripes represent the blood shed in the struggle for freedom, the blue symbolises prosperity, and the white disc represents the full moon over the Mekong River — also symbolising the promise of a bright future under the new regime',
    ),
    'LB': AsiaClueData(
      nickname: 'The Paris of the Middle East',
      famousLandmark: 'Baalbek Temples',
      famousPerson: 'Khalil Gibran',
      flag:
          'The red stripes represent the blood shed for liberation, the white represents peace and snow of the mountains, and the green cedar tree is the symbol of Lebanon — an ancient emblem representing holiness, eternity, and peace, referenced throughout the Bible',
    ),
    'LK': AsiaClueData(
      nickname: 'The Pearl of the Indian Ocean',
      famousLandmark: 'Sigiriya Rock Fortress',
      famousPerson: 'Arthur C. Clarke',
      flag:
          'The golden lion holding a sword is the ancient symbol of the Sinhalese people and represents bravery; the green and orange stripes represent the Tamil and Muslim minorities; the four bo-tree leaves in the corners symbolise Buddhist concepts of loving-kindness, compassion, equanimity, and happiness',
    ),
    'MM': AsiaClueData(
      nickname: 'The Golden Land',
      famousLandmark: 'Shwedagon Pagoda',
      famousPerson: 'Aung San',
      flag:
          'The yellow represents solidarity, the green symbolises peace, tranquility, and lush vegetation, the red represents courage and decisiveness, and the large white star represents the significance of the union of the country',
    ),
    'MN': AsiaClueData(
      nickname: 'The Land of Eternal Blue Sky',
      famousLandmark: 'Genghis Khan Equestrian Statue',
      famousPerson: 'Genghis Khan',
      flag:
          'The red symbolises progress and prosperity, the blue represents the eternal blue sky (a sacred concept in Mongol culture), and the golden Soyombo symbol contains sun, moon, fire, and yin-yang elements representing the Mongol people\'s eternal existence',
    ),
    'MV': AsiaClueData(
      nickname: 'The Sunny Side of Life',
      famousLandmark: 'Ithaa Undersea Restaurant',
      famousPerson: 'Mohamed Amin Didi',
      flag: 'Red field with green rectangle in center bearing white crescent',
    ),
    'MY': AsiaClueData(
      nickname: 'The Tiger of Asia',
      famousLandmark: 'Petronas Twin Towers',
      famousPerson: 'Tunku Abdul Rahman',
      flag:
          'The 14 red and white stripes represent the 14 member states, the blue canton symbolises unity, the crescent represents Islam, and the 14-pointed gold star represents the unity of the states — the design was inspired by the American flag due to shared federalist ideals',
    ),
    'NP': AsiaClueData(
      nickname: 'The Roof of the World',
      famousLandmark: 'Mount Everest',
      famousPerson: 'Tenzing Norgay',
      flag:
          'The world\'s only non-rectangular national flag; the two stacked triangles represent the Himalaya Mountains and the two major religions (Hinduism and Buddhism); the moon symbolises the calm demeanour of Nepalis and the sun represents fierce resolve',
    ),
    'OM': AsiaClueData(
      nickname: 'The Jewel of Arabia',
      famousLandmark: 'Sultan Qaboos Grand Mosque',
      famousPerson: 'Sultan Qaboos bin Said',
      flag:
          'The white represents peace and the Imam, the red is the traditional colour of the Omani people, the green represents the Green Mountains (Al Hajar) and fertility; the national emblem (khanjar dagger and crossed swords) symbolises the historical Omani defense',
    ),
    'PH': AsiaClueData(
      nickname: 'The Pearl of the Orient Seas',
      famousLandmark: 'Chocolate Hills',
      famousPerson: 'Jose Rizal',
      flag:
          'The blue stands for peace, truth, and justice; the red represents patriotism and valour; the white triangle symbolises equality and fraternity; the sun represents independence with eight rays for the first eight revolting provinces; and three stars represent Luzon, Visayas, and Mindanao',
    ),
    'PK': AsiaClueData(
      nickname: 'The Land of the Pure',
      famousLandmark: 'Badshahi Mosque',
      famousPerson: 'Muhammad Ali Jinnah',
      flag:
          'The green represents the Muslim majority, the white stripe represents religious minorities, the crescent symbolises progress, and the five-pointed star represents light and knowledge — designed to represent all citizens of Pakistan',
    ),
    'PS': AsiaClueData(
      nickname: 'The Holy Land',
      famousLandmark: 'Dome of the Rock',
      famousPerson: 'Yasser Arafat',
      flag:
          'Horizontal black, white, and green stripes with red triangle at hoist',
    ),
    'QA': AsiaClueData(
      nickname: 'The Thumb of the Gulf',
      famousLandmark: 'The Pearl-Qatar',
      famousPerson: 'Sheikh Tamim bin Hamad Al Thani',
      flag:
          'The maroon colour (originally red, darkened by the desert sun) is unique among national flags and represents the blood shed in Qatar\'s wars; the white represents peace; the nine-pointed serrated line records Qatar as the ninth member of the "reconciled Emirates" after the 1916 treaty',
    ),
    'SA': AsiaClueData(
      nickname: 'The Land of the Two Holy Mosques',
      famousLandmark: 'Masjid al-Haram (Grand Mosque of Mecca)',
      famousPerson: 'King Abdulaziz ibn Saud',
      flag:
          'The green represents Islam, the Arabic inscription is the Shahada ("There is no god but Allah, Muhammad is the messenger of Allah"), and the sword symbolises the House of Saud\'s military strength — this is the only national flag that cannot be flown at half-mast due to its sacred inscription',
    ),
    'SG': AsiaClueData(
      nickname: 'The Lion City',
      famousLandmark: 'Marina Bay Sands',
      famousPerson: 'Lee Kuan Yew',
      flag:
          'Horizontal red and white halves with white crescent and five white stars at upper hoist',
    ),
    'SY': AsiaClueData(
      nickname: 'The Cradle of Civilizations',
      famousLandmark: 'Ancient City of Damascus',
      famousPerson: 'Queen Zenobia',
      flag:
          'The red-white-black horizontal tricolour uses Pan-Arab colours representing the Hashemite dynasty, the Umayyad dynasty, and the Abbasid dynasty; the two green stars originally represented Egypt and Syria in the United Arab Republic',
    ),
    'TH': AsiaClueData(
      nickname: 'The Land of Smiles',
      famousLandmark: 'Grand Palace',
      famousPerson: 'King Bhumibol Adulyadej',
      flag:
          'The red represents the nation and the blood of life, the white symbolises the purity of Buddhism, and the blue represents the monarchy — the "Trairanga" (tricolour) was adopted in 1917 and the blue was said to honour the Allies of World War I',
    ),
    'TJ': AsiaClueData(
      nickname: 'The Roof of the World',
      famousLandmark: 'Ismoil Somoni Peak',
      famousPerson: 'Ismoil Somoni',
      flag:
          'The red represents the sun and victory, the white symbolises purity and cotton (a major crop), the green represents agriculture and spring; the golden crown and seven stars above it represent the Tajik people — "Tajik" is said to derive from the word for "crown"',
    ),
    'TL': AsiaClueData(
      nickname: 'The Land of the Rising Sun of Southeast Asia',
      famousLandmark: 'Cristo Rei of Dili',
      famousPerson: 'Xanana Gusmao',
      flag:
          'The red represents the struggle for national liberation, the black symbolises the obscurantism that needs to be overcome, the yellow triangle represents the traces of colonialism; the white star is the guiding light for peace',
    ),
    'TM': AsiaClueData(
      nickname: 'The Land of the White Horse',
      famousLandmark: 'Darvaza Gas Crater',
      famousPerson: 'Saparmurat Niyazov',
      flag:
          'The green field represents Islam, the crescent and five stars symbolise the five provinces; the unique carpet gul stripe along the hoist displays five traditional Turkmen carpet designs representing the five major tribes — the only national flag featuring carpet patterns',
    ),
    'TW': AsiaClueData(
      nickname: 'The Beautiful Island',
      famousLandmark: 'Taipei 101',
      famousPerson: 'Sun Yat-sen',
      flag:
          'The blue canton with white Sun represents the Kuomintang party and the twelve hours of the day (symbolising continuous progress); the red field represents the blood of revolutionaries who overthrew the Qing dynasty — the flag was originally designed by Lu Haodong for Sun Yat-sen\'s revolutionary movement',
    ),
    'UZ': AsiaClueData(
      nickname: 'The Land of the Blue Domes',
      famousLandmark: 'Registan Square',
      famousPerson: 'Amir Timur (Tamerlane)',
      flag:
          'The blue represents water and the sky (echoing Tamerlane\'s banner), the white symbolises peace, the green represents nature and Islam; the crescent represents the new nation reborn, and the twelve stars represent the months and the twelve regions',
    ),
    'VN': AsiaClueData(
      nickname: 'The Land of the Ascending Dragon',
      famousLandmark: 'Ha Long Bay',
      famousPerson: 'Ho Chi Minh',
      flag:
          'The red background represents the revolution and the blood of martyrs, and the five-pointed gold star represents the five classes of Vietnamese society — workers, peasants, soldiers, intellectuals, and business people — united under communism',
    ),
    'YE': AsiaClueData(
      nickname: 'The Land of Sheba',
      famousLandmark: 'Old Walled City of Shibam',
      famousPerson: 'Queen of Sheba',
      flag:
          'The red-white-black horizontal tricolour uses Pan-Arab colours; the red represents the blood of martyrs and unity, the white symbolises hope for the future, and the black represents the dark past that has been overcome',
    ),
  };
}
