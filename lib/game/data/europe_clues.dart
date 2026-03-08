/// European country clue data for the regional game mode.
library;

class EuropeClueData {
  const EuropeClueData({
    required this.nickname,
    required this.famousLandmark,
    required this.famousPerson,
    required this.flag,
    required this.motto,
    required this.footballTeam,
  });

  final String nickname;
  final String famousLandmark;
  final String famousPerson;
  final String flag;
  final String motto;
  final String footballTeam;
}

abstract class EuropeClues {
  static const Map<String, EuropeClueData> data = {
    'AD': EuropeClueData(
      nickname: 'The Pyrenean Principality',
      famousLandmark: 'Vall del Madriu-Perafita-Claror',
      famousPerson: 'Boris Skossyreff',
      flag:
          'Three vertical stripes: blue, yellow, red with coat of arms on yellow',
      motto: 'Virtus Unita Fortior',
      footballTeam: 'FC Andorra',
    ),
    'AL': EuropeClueData(
      nickname: 'The Land of the Eagles',
      famousLandmark: 'Butrint',
      famousPerson: 'Mother Teresa',
      flag: 'Red field with black double-headed eagle in centre',
      motto: 'Ti Shqiperi, me jep nder, me jep emrin Shqipetar',
      footballTeam: 'Kuq e Zi',
    ),
    'AT': EuropeClueData(
      nickname: 'The Land of Music',
      famousLandmark: 'Schoenbrunn Palace',
      famousPerson: 'Wolfgang Amadeus Mozart',
      flag: 'Three horizontal stripes: red, white, red',
      motto: '',
      footballTeam: 'Das Team',
    ),
    'BA': EuropeClueData(
      nickname: 'The Heart-Shaped Land',
      famousLandmark: 'Stari Most (Old Bridge of Mostar)',
      famousPerson: 'Ivo Andric',
      flag: 'Blue field with yellow triangle and white stars along hypotenuse',
      motto: '',
      footballTeam: 'Zmajevi',
    ),
    'BE': EuropeClueData(
      nickname: 'The Battleground of Europe',
      famousLandmark: 'Grand Place',
      famousPerson: 'Audrey Hepburn',
      flag: 'Three vertical stripes: black, yellow, red',
      motto: 'Eendracht maakt macht / L\'union fait la force',
      footballTeam: 'De Rode Duivels',
    ),
    'BG': EuropeClueData(
      nickname: 'The Land of Roses',
      famousLandmark: 'Alexander Nevsky Cathedral',
      famousPerson: 'Hristo Stoichkov',
      flag: 'Three horizontal stripes: white, green, red',
      motto: 'Saединението прави силата (Unity makes strength)',
      footballTeam: 'The Lions',
    ),
    'BY': EuropeClueData(
      nickname: 'White Rus',
      famousLandmark: 'Mir Castle',
      famousPerson: 'Marc Chagall',
      flag:
          'Two horizontal stripes red and green with white and red ornament pattern on hoist',
      motto: '',
      footballTeam: 'FC BATE Borisov',
    ),
    'CH': EuropeClueData(
      nickname: 'The Playground of Europe',
      famousLandmark: 'Matterhorn',
      famousPerson: 'Albert Einstein',
      flag: 'Red square field with white cross in centre',
      motto: 'Unus pro omnibus, omnes pro uno (One for all, all for one)',
      footballTeam: 'Nati',
    ),
    'CY': EuropeClueData(
      nickname: 'The Island of Aphrodite',
      famousLandmark: 'Tombs of the Kings',
      famousPerson: 'Zeno of Citium',
      flag:
          'White field with copper-coloured island silhouette above two olive branches',
      motto: '',
      footballTeam: 'APOEL FC',
    ),
    'CZ': EuropeClueData(
      nickname: 'The Heart of Europe',
      famousLandmark: 'Prague Castle',
      famousPerson: 'Franz Kafka',
      flag: 'Two horizontal stripes white and red with blue triangle at hoist',
      motto: 'Pravda vitezi (Truth prevails)',
      footballTeam: 'Narodni tym',
    ),
    'DE': EuropeClueData(
      nickname: 'Das Land der Dichter und Denker',
      famousLandmark: 'Brandenburg Gate',
      famousPerson: 'Albert Einstein',
      flag: 'Three horizontal stripes: black, red, gold',
      motto: 'Einigkeit und Recht und Freiheit (Unity and Justice and Freedom)',
      footballTeam: 'Die Mannschaft',
    ),
    'DK': EuropeClueData(
      nickname: 'The Land of the Danes',
      famousLandmark: 'The Little Mermaid',
      famousPerson: 'Hans Christian Andersen',
      flag: 'Red field with white Scandinavian cross (Dannebrog)',
      motto: '',
      footballTeam: 'Danish Dynamite',
    ),
    'EE': EuropeClueData(
      nickname: 'The Digital Nation',
      famousLandmark: 'Tallinn Old Town',
      famousPerson: 'Arvo Part',
      flag: 'Three horizontal stripes: blue, black, white',
      motto: '',
      footballTeam: 'FC Flora Tallinn',
    ),
    'ES': EuropeClueData(
      nickname: 'The Kingdom of the Sun',
      famousLandmark: 'Sagrada Familia',
      famousPerson: 'Pablo Picasso',
      flag:
          'Three horizontal stripes: red, yellow (double width), red with coat of arms',
      motto: 'Plus Ultra (Further Beyond)',
      footballTeam: 'La Roja',
    ),
    'FI': EuropeClueData(
      nickname: 'The Land of a Thousand Lakes',
      famousLandmark: 'Suomenlinna Fortress',
      famousPerson: 'Jean Sibelius',
      flag: 'White field with blue Scandinavian cross',
      motto: '',
      footballTeam: 'Huuhkajat',
    ),
    'FR': EuropeClueData(
      nickname: 'L\'Hexagone',
      famousLandmark: 'Eiffel Tower',
      famousPerson: 'Napoleon Bonaparte',
      flag: 'Three vertical stripes: blue, white, red',
      motto: 'Liberte, Egalite, Fraternite',
      footballTeam: 'Les Bleus',
    ),
    'GB': EuropeClueData(
      nickname: 'Blighty',
      famousLandmark: 'Big Ben',
      famousPerson: 'William Shakespeare',
      flag:
          'Blue field with red and white crosses of St George, St Andrew, and St Patrick (Union Jack)',
      motto: 'Dieu et mon droit (God and my right)',
      footballTeam: 'The Three Lions',
    ),
    'GR': EuropeClueData(
      nickname: 'The Cradle of Western Civilisation',
      famousLandmark: 'Parthenon',
      famousPerson: 'Aristotle',
      flag:
          'Nine horizontal stripes alternating blue and white with white cross on blue canton',
      motto: 'Eleftheria i Thanatos (Freedom or Death)',
      footballTeam: 'Ethniki',
    ),
    'HR': EuropeClueData(
      nickname: 'The Land of a Thousand Islands',
      famousLandmark: 'Dubrovnik Old Town',
      famousPerson: 'Nikola Tesla',
      flag:
          'Three horizontal stripes: red, white, blue with chequered coat of arms',
      motto: '',
      footballTeam: 'Vatreni',
    ),
    'HU': EuropeClueData(
      nickname: 'The Land of Thermal Waters',
      famousLandmark: 'Hungarian Parliament Building',
      famousPerson: 'Franz Liszt',
      flag: 'Three horizontal stripes: red, white, green',
      motto: '',
      footballTeam: 'Magyarok',
    ),
    'IE': EuropeClueData(
      nickname: 'The Emerald Isle',
      famousLandmark: 'Cliffs of Moher',
      famousPerson: 'Oscar Wilde',
      flag: 'Three vertical stripes: green, white, orange',
      motto: '',
      footballTeam: 'Boys in Green',
    ),
    'IS': EuropeClueData(
      nickname: 'The Land of Fire and Ice',
      famousLandmark: 'Hallgrimskirkja',
      famousPerson: 'Bjork',
      flag: 'Blue field with red Scandinavian cross outlined in white',
      motto: '',
      footballTeam: 'Strakarnir okkar',
    ),
    'IT': EuropeClueData(
      nickname: 'The Boot',
      famousLandmark: 'Colosseum',
      famousPerson: 'Leonardo da Vinci',
      flag: 'Three vertical stripes: green, white, red',
      motto: '',
      footballTeam: 'Gli Azzurri',
    ),
    'LI': EuropeClueData(
      nickname: 'The Doubly Landlocked Principality',
      famousLandmark: 'Vaduz Castle',
      famousPerson: 'Hans-Adam II',
      flag:
          'Two horizontal stripes: blue and red with gold crown on blue stripe',
      motto: 'Fur Gott, Furst und Vaterland (For God, Prince, and Fatherland)',
      footballTeam: 'FC Vaduz',
    ),
    'LT': EuropeClueData(
      nickname: 'The Land of Amber',
      famousLandmark: 'Gediminas Tower',
      famousPerson: 'Violeta Urmana',
      flag: 'Three horizontal stripes: yellow, green, red',
      motto:
          'Tautos jega, vienybe teze (The strength of the nation lies in unity)',
      footballTeam: 'FK Zalgiris Vilnius',
    ),
    'LU': EuropeClueData(
      nickname: 'The Grand Duchy',
      famousLandmark: 'Casemates du Bock',
      famousPerson: 'Robert Schuman',
      flag: 'Three horizontal stripes: red, white, light blue',
      motto: 'Mir welle bleiwe wat mir sinn (We want to remain what we are)',
      footballTeam: 'F91 Dudelange',
    ),
    'LV': EuropeClueData(
      nickname: 'The Land of Blue Lakes',
      famousLandmark: 'Riga Old Town',
      famousPerson: 'Mikhail Eisenstein',
      flag: 'Dark red field with narrow white horizontal stripe through centre',
      motto: 'Tiesu tiesai (For justice)',
      footballTeam: 'FK RFS',
    ),
    'MC': EuropeClueData(
      nickname: 'The Rock',
      famousLandmark: 'Monte Carlo Casino',
      famousPerson: 'Grace Kelly',
      flag: 'Two horizontal stripes: red over white',
      motto: 'Deo Juvante (With God\'s Help)',
      footballTeam: 'AS Monaco',
    ),
    'MD': EuropeClueData(
      nickname: 'The Land Between Rivers',
      famousLandmark: 'Orheiul Vechi',
      famousPerson: 'Eugen Doga',
      flag:
          'Three vertical stripes: blue, yellow, red with coat of arms on yellow',
      motto: '',
      footballTeam: 'Sheriff Tiraspol',
    ),
    'ME': EuropeClueData(
      nickname: 'The Pearl of the Mediterranean',
      famousLandmark: 'Bay of Kotor',
      famousPerson: 'Petar II Petrovic-Njegos',
      flag:
          'Red field with gold border and gold double-headed eagle coat of arms',
      motto: '',
      footballTeam: 'Hrabri Sokoli',
    ),
    'MK': EuropeClueData(
      nickname: 'The Land of the Sun',
      famousLandmark: 'Lake Ohrid',
      famousPerson: 'Mother Teresa',
      flag:
          'Red field with yellow sun and eight broadening rays extending to edges',
      motto: '',
      footballTeam: 'FK Vardar',
    ),
    'MT': EuropeClueData(
      nickname: 'The George Cross Island',
      famousLandmark: 'Megalithic Temples of Malta',
      famousPerson: 'Dom Mintoff',
      flag: 'Two vertical halves: white and red with George Cross on white',
      motto: '',
      footballTeam: 'Valletta FC',
    ),
    'NL': EuropeClueData(
      nickname: 'The Low Countries',
      famousLandmark: 'Anne Frank House',
      famousPerson: 'Vincent van Gogh',
      flag: 'Three horizontal stripes: red, white, blue',
      motto: 'Je maintiendrai (I will maintain)',
      footballTeam: 'Oranje',
    ),
    'NO': EuropeClueData(
      nickname: 'The Land of the Midnight Sun',
      famousLandmark: 'Geirangerfjord',
      famousPerson: 'Edvard Munch',
      flag: 'Red field with blue Scandinavian cross outlined in white',
      motto: 'Alt for Norge (Everything for Norway)',
      footballTeam: 'Landslaget',
    ),
    'PL': EuropeClueData(
      nickname: 'The Land of the White Eagle',
      famousLandmark: 'Wawel Castle',
      famousPerson: 'Marie Curie',
      flag: 'Two horizontal stripes: white over red',
      motto: '',
      footballTeam: 'Bialo-Czerwoni',
    ),
    'PT': EuropeClueData(
      nickname: 'The Land of Explorers',
      famousLandmark: 'Tower of Belem',
      famousPerson: 'Cristiano Ronaldo',
      flag:
          'Two vertical sections green and red with coat of arms on dividing line',
      motto: '',
      footballTeam: 'Selecao das Quinas',
    ),
    'RO': EuropeClueData(
      nickname: 'The Land of Dracula',
      famousLandmark: 'Bran Castle',
      famousPerson: 'Nadia Comaneci',
      flag: 'Three vertical stripes: blue, yellow, red',
      motto: '',
      footballTeam: 'Tricolorii',
    ),
    'RS': EuropeClueData(
      nickname: 'The Land of Raspberries',
      famousLandmark: 'Belgrade Fortress',
      famousPerson: 'Nikola Tesla',
      flag:
          'Three horizontal stripes: red, blue, white with coat of arms on hoist side',
      motto: '',
      footballTeam: 'Orlovi',
    ),
    'RU': EuropeClueData(
      nickname: 'The Motherland',
      famousLandmark: 'Saint Basil\'s Cathedral',
      famousPerson: 'Leo Tolstoy',
      flag: 'Three horizontal stripes: white, blue, red',
      motto: '',
      footballTeam: 'Sbornaya',
    ),
    'SE': EuropeClueData(
      nickname: 'The Land of the Vikings',
      famousLandmark: 'Vasa Museum',
      famousPerson: 'Alfred Nobel',
      flag: 'Blue field with yellow Scandinavian cross',
      motto: 'For Sverige i tiden (For Sweden, with the times)',
      footballTeam: 'Blagult',
    ),
    'SI': EuropeClueData(
      nickname: 'The Sunny Side of the Alps',
      famousLandmark: 'Lake Bled',
      famousPerson: 'Slavoj Zizek',
      flag:
          'Three horizontal stripes: white, blue, red with coat of arms on upper hoist',
      motto: '',
      footballTeam: 'Zmajceki',
    ),
    'SK': EuropeClueData(
      nickname: 'The Tatra Tiger',
      famousLandmark: 'Spis Castle',
      famousPerson: 'Andy Warhol',
      flag:
          'Three horizontal stripes: white, blue, red with coat of arms on hoist side',
      motto: '',
      footballTeam: 'Repre',
    ),
    'SM': EuropeClueData(
      nickname: 'The Most Serene Republic',
      famousLandmark: 'Guaita Tower',
      famousPerson: 'Saint Marinus',
      flag:
          'Two horizontal stripes: white over light blue with coat of arms in centre',
      motto: 'Libertas (Liberty)',
      footballTeam: 'San Marino Calcio',
    ),
    'TR': EuropeClueData(
      nickname: 'The Bridge Between East and West',
      famousLandmark: 'Hagia Sophia',
      famousPerson: 'Mustafa Kemal Ataturk',
      flag: 'Red field with white crescent moon and star',
      motto: 'Yurtta sulh, cihanda sulh (Peace at home, peace in the world)',
      footballTeam: 'Ay-Yildizlilar',
    ),
    'UA': EuropeClueData(
      nickname: 'The Breadbasket of Europe',
      famousLandmark: 'Saint Sophia\'s Cathedral, Kyiv',
      famousPerson: 'Taras Shevchenko',
      flag: 'Two horizontal stripes: blue over yellow',
      motto: '',
      footballTeam: 'Zbirna',
    ),
    'VA': EuropeClueData(
      nickname: 'The Holy See',
      famousLandmark: 'St. Peter\'s Basilica',
      famousPerson: 'Pope Francis',
      flag:
          'Two vertical halves: yellow and white with papal tiara and keys on white',
      motto: '',
      footballTeam: '',
    ),
    'XK': EuropeClueData(
      nickname: 'The Young European Nation',
      famousLandmark: 'Gjakova Bazaar',
      famousPerson: 'Ibrahim Rugova',
      flag: 'Blue field with gold map of Kosovo and six white stars above',
      motto: '',
      footballTeam: 'Dardanet',
    ),
  };
}
