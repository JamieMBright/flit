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
          'White field with red and blue taegeuk symbol in center and four black trigrams in corners',
    ),
    'KW': AsiaClueData(
      nickname: 'The Pearl of the Gulf',
      famousLandmark: 'Kuwait Towers',
      famousPerson: 'Sheikh Abdullah Al-Salem Al-Sabah',
      flag:
          'Horizontal green, white, and red stripes with black trapezoid at hoist',
    ),
    'KZ': AsiaClueData(
      nickname: 'The Land of the Great Steppe',
      famousLandmark: 'Bayterek Tower',
      famousPerson: 'Al-Farabi',
      flag:
          'Sky blue field with golden sun and soaring eagle in center and national ornament at hoist',
    ),
    'LA': AsiaClueData(
      nickname: 'The Land of a Million Elephants',
      famousLandmark: 'Luang Prabang',
      famousPerson: 'Kaysone Phomvihane',
      flag:
          'Blue stripe between two red stripes with white circle in center of blue stripe',
    ),
    'LB': AsiaClueData(
      nickname: 'The Paris of the Middle East',
      famousLandmark: 'Baalbek Temples',
      famousPerson: 'Khalil Gibran',
      flag:
          'Horizontal red, white, and red stripes with green cedar tree on white center stripe',
    ),
    'LK': AsiaClueData(
      nickname: 'The Pearl of the Indian Ocean',
      famousLandmark: 'Sigiriya Rock Fortress',
      famousPerson: 'Arthur C. Clarke',
      flag:
          'Dark red panel with gold lion holding sword, green and orange vertical stripes at hoist, gold border',
    ),
    'MM': AsiaClueData(
      nickname: 'The Golden Land',
      famousLandmark: 'Shwedagon Pagoda',
      famousPerson: 'Aung San',
      flag:
          'Horizontal yellow, green, and red stripes with large white five-pointed star in center',
    ),
    'MN': AsiaClueData(
      nickname: 'The Land of Eternal Blue Sky',
      famousLandmark: 'Genghis Khan Equestrian Statue',
      famousPerson: 'Genghis Khan',
      flag:
          'Vertical red, blue, and red stripes with yellow Soyombo symbol on hoist-side red stripe',
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
          'Fourteen alternating red and white horizontal stripes with blue canton bearing yellow crescent and star',
    ),
    'NP': AsiaClueData(
      nickname: 'The Roof of the World',
      famousLandmark: 'Mount Everest',
      famousPerson: 'Tenzing Norgay',
      flag:
          'Two stacked crimson red triangles with blue borders bearing white moon and sun symbols',
    ),
    'OM': AsiaClueData(
      nickname: 'The Jewel of Arabia',
      famousLandmark: 'Sultan Qaboos Grand Mosque',
      famousPerson: 'Sultan Qaboos bin Said',
      flag:
          'Horizontal white, red, and green stripes with vertical red stripe at hoist and national emblem at upper hoist',
    ),
    'PH': AsiaClueData(
      nickname: 'The Pearl of the Orient Seas',
      famousLandmark: 'Chocolate Hills',
      famousPerson: 'Jose Rizal',
      flag:
          'Horizontal blue and red stripes with white triangle at hoist bearing golden sun and three stars',
    ),
    'PK': AsiaClueData(
      nickname: 'The Land of the Pure',
      famousLandmark: 'Badshahi Mosque',
      famousPerson: 'Muhammad Ali Jinnah',
      flag:
          'Dark green field with white vertical stripe at hoist and white crescent and star on green',
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
          'White field at hoist and maroon field at fly separated by serrated line of nine points',
    ),
    'SA': AsiaClueData(
      nickname: 'The Land of the Two Holy Mosques',
      famousLandmark: 'Masjid al-Haram (Grand Mosque of Mecca)',
      famousPerson: 'King Abdulaziz ibn Saud',
      flag:
          'Green field with white Arabic inscription and white sword below it',
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
          'Horizontal red, white, and black stripes with two green five-pointed stars on white stripe',
    ),
    'TH': AsiaClueData(
      nickname: 'The Land of Smiles',
      famousLandmark: 'Grand Palace',
      famousPerson: 'King Bhumibol Adulyadej',
      flag:
          'Five horizontal stripes of red, white, blue, white, and red with wider blue center stripe',
    ),
    'TJ': AsiaClueData(
      nickname: 'The Roof of the World',
      famousLandmark: 'Ismoil Somoni Peak',
      famousPerson: 'Ismoil Somoni',
      flag:
          'Horizontal red, white, and green stripes with golden crown and seven stars on white stripe',
    ),
    'TL': AsiaClueData(
      nickname: 'The Land of the Rising Sun of Southeast Asia',
      famousLandmark: 'Cristo Rei of Dili',
      famousPerson: 'Xanana Gusmao',
      flag:
          'Red field with black and yellow triangles at hoist and white star on black triangle',
    ),
    'TM': AsiaClueData(
      nickname: 'The Land of the White Horse',
      famousLandmark: 'Darvaza Gas Crater',
      famousPerson: 'Saparmurat Niyazov',
      flag:
          'Green field with vertical carpet pattern stripe at hoist in red and white, white crescent and five stars',
    ),
    'TW': AsiaClueData(
      nickname: 'The Beautiful Island',
      famousLandmark: 'Taipei 101',
      famousPerson: 'Sun Yat-sen',
      flag:
          'Red field with blue canton bearing white twelve-rayed sun at upper hoist',
    ),
    'UZ': AsiaClueData(
      nickname: 'The Land of the Blue Domes',
      famousLandmark: 'Registan Square',
      famousPerson: 'Amir Timur (Tamerlane)',
      flag:
          'Horizontal blue, white, and green stripes separated by thin red borders with white crescent and stars on blue',
    ),
    'VN': AsiaClueData(
      nickname: 'The Land of the Ascending Dragon',
      famousLandmark: 'Ha Long Bay',
      famousPerson: 'Ho Chi Minh',
      flag: 'Red field with large yellow five-pointed star in center',
    ),
    'YE': AsiaClueData(
      nickname: 'The Land of Sheba',
      famousLandmark: 'Old Walled City of Shibam',
      famousPerson: 'Queen of Sheba',
      flag: 'Horizontal red, white, and black stripes',
    ),
  };
}
