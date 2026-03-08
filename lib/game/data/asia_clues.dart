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
          'Horizontal green, white, and black stripes with vertical red stripe at hoist',
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
      flag: 'Horizontal red, blue, and orange stripes',
    ),
    'AZ': AsiaClueData(
      nickname: 'The Land of Fire',
      famousLandmark: 'Flame Towers',
      famousPerson: 'Heydar Aliyev',
      flag:
          'Horizontal blue, red, and green stripes with white crescent and eight-pointed star on red stripe',
    ),
    'BD': AsiaClueData(
      nickname: 'The Land of Rivers',
      famousLandmark: 'Sundarbans Mangrove Forest',
      famousPerson: 'Sheikh Mujibur Rahman',
      flag: 'Dark green field with red circle offset slightly toward hoist',
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
          'Yellow field with white and black diagonal stripes and red national crest in center',
    ),
    'BT': AsiaClueData(
      nickname: 'The Land of the Thunder Dragon',
      famousLandmark: 'Tiger\'s Nest Monastery',
      famousPerson: 'Jigme Singye Wangchuck',
      flag:
          'Diagonally divided yellow and orange halves with white dragon in center',
    ),
    'CN': AsiaClueData(
      nickname: 'The Middle Kingdom',
      famousLandmark: 'Great Wall of China',
      famousPerson: 'Confucius',
      flag:
          'Red field with five yellow stars at upper hoist, one large and four small',
    ),
    'GE': AsiaClueData(
      nickname: 'The Balcony of Europe',
      famousLandmark: 'Jvari Monastery',
      famousPerson: 'Joseph Stalin',
      flag:
          'White field with large red cross and four red crosses in each quadrant',
    ),
    'ID': AsiaClueData(
      nickname: 'The Emerald of the Equator',
      famousLandmark: 'Borobudur Temple',
      famousPerson: 'Sukarno',
      flag: 'Horizontal red and white halves',
    ),
    'IL': AsiaClueData(
      nickname: 'The Holy Land',
      famousLandmark: 'Western Wall',
      famousPerson: 'David Ben-Gurion',
      flag:
          'White field with blue horizontal stripes near top and bottom and blue Star of David in center',
    ),
    'IN': AsiaClueData(
      nickname: 'The Land of Spices',
      famousLandmark: 'Taj Mahal',
      famousPerson: 'Mahatma Gandhi',
      flag:
          'Horizontal saffron, white, and green stripes with blue Ashoka Chakra wheel on white stripe',
    ),
    'IQ': AsiaClueData(
      nickname: 'The Cradle of Civilization',
      famousLandmark: 'Ziggurat of Ur',
      famousPerson: 'Hammurabi',
      flag:
          'Horizontal red, white, and black stripes with green Takbir script on white stripe',
    ),
    'IR': AsiaClueData(
      nickname: 'The Land of the Aryans',
      famousLandmark: 'Persepolis',
      famousPerson: 'Cyrus the Great',
      flag:
          'Horizontal green, white, and red stripes with red emblem in center and Takbir script along stripe edges',
    ),
    'JO': AsiaClueData(
      nickname: 'The Hashemite Kingdom',
      famousLandmark: 'Petra',
      famousPerson: 'King Hussein',
      flag:
          'Horizontal black, white, and green stripes with red triangle at hoist bearing white seven-pointed star',
    ),
    'JP': AsiaClueData(
      nickname: 'The Land of the Rising Sun',
      famousLandmark: 'Mount Fuji',
      famousPerson: 'Emperor Meiji',
      flag: 'White field with red circle in center',
    ),
    'KG': AsiaClueData(
      nickname: 'The Switzerland of Central Asia',
      famousLandmark: 'Issyk-Kul Lake',
      famousPerson: 'Chingiz Aitmatov',
      flag:
          'Red field with yellow sun containing forty rays and a tunduk symbol in center',
    ),
    'KH': AsiaClueData(
      nickname: 'The Kingdom of Wonder',
      famousLandmark: 'Angkor Wat',
      famousPerson: 'Norodom Sihanouk',
      flag:
          'Blue and red horizontal stripes with white depiction of Angkor Wat in center',
    ),
    'KP': AsiaClueData(
      nickname: 'The Hermit Kingdom',
      famousLandmark: 'Kumsusan Palace of the Sun',
      famousPerson: 'Kim Il-sung',
      flag:
          'Blue, red, and white horizontal stripes with white circle and red star at hoist side',
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
