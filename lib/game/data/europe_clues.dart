/// European country clue data for the regional game mode.
library;

class EuropeClueData {
  const EuropeClueData({
    required this.nickname,
    required this.famousLandmark,
    required this.famousPeople,
    required this.flag,
    required this.motto,
    required this.footballTeam,
  });

  final String nickname;
  final String famousLandmark;
  final List<String> famousPeople;
  final String flag;
  final String motto;
  final String footballTeam;
}

abstract class EuropeClues {
  static const Map<String, EuropeClueData> data = {
    'AD': EuropeClueData(
      nickname: 'The Pyrenean Principality',
      famousLandmark: 'Vall del Madriu-Perafita-Claror',
      famousPeople: ['Boris Skossyreff'],
      flag:
          'Three vertical stripes: blue, yellow, red with coat of arms on yellow',
      motto: 'Virtus Unita Fortior',
      footballTeam: 'FC Andorra',
    ),
    'AL': EuropeClueData(
      nickname: 'The Land of the Eagles',
      famousLandmark: 'Butrint',
      famousPeople: ['Mother Teresa', 'Dua Lipa', 'Rita Ora'],
      flag: 'Red field with black double-headed eagle in centre',
      motto: 'Ti Shqiperi, me jep nder, me jep emrin Shqipetar',
      footballTeam: 'Kuq e Zi',
    ),
    'AT': EuropeClueData(
      nickname: 'The Land of Music',
      famousLandmark: 'Schoenbrunn Palace',
      famousPeople: [
        'Wolfgang Amadeus Mozart',
        'Arnold Schwarzenegger',
        'Sigmund Freud',
      ],
      flag: 'Three horizontal stripes: red, white, red',
      motto: '',
      footballTeam: 'Das Team',
    ),
    'BA': EuropeClueData(
      nickname: 'The Heart-Shaped Land',
      famousLandmark: 'Stari Most (Old Bridge of Mostar)',
      famousPeople: ['Ivo Andric', 'Edin Dzeko'],
      flag: 'Blue field with yellow triangle and white stars along hypotenuse',
      motto: '',
      footballTeam: 'Zmajevi',
    ),
    'BE': EuropeClueData(
      nickname: 'The Battleground of Europe',
      famousLandmark: 'Grand Place',
      famousPeople: [
        'Audrey Hepburn',
        'Jean-Claude Van Damme',
        'Tintin (Herge)'
      ],
      flag: 'Three vertical stripes: black, yellow, red',
      motto: 'Eendracht maakt macht / L\'union fait la force',
      footballTeam: 'De Rode Duivels',
    ),
    'BG': EuropeClueData(
      nickname: 'The Land of Roses',
      famousLandmark: 'Alexander Nevsky Cathedral',
      famousPeople: ['Hristo Stoichkov', 'Grigor Dimitrov'],
      flag: 'Three horizontal stripes: white, green, red',
      motto: 'Saединението прави силата (Unity makes strength)',
      footballTeam: 'The Lions',
    ),
    'BY': EuropeClueData(
      nickname: 'White Rus',
      famousLandmark: 'Mir Castle',
      famousPeople: ['Marc Chagall', 'Victoria Azarenka'],
      flag:
          'Two horizontal stripes red and green with white and red ornament pattern on hoist',
      motto: '',
      footballTeam: 'FC BATE Borisov',
    ),
    'CH': EuropeClueData(
      nickname: 'The Playground of Europe',
      famousLandmark: 'Matterhorn',
      famousPeople: ['Albert Einstein', 'Roger Federer', 'William Tell'],
      flag: 'Red square field with white cross in centre',
      motto: 'Unus pro omnibus, omnes pro uno (One for all, all for one)',
      footballTeam: 'Nati',
    ),
    'CY': EuropeClueData(
      nickname: 'The Island of Aphrodite',
      famousLandmark: 'Tombs of the Kings',
      famousPeople: ['Zeno of Citium'],
      flag:
          'White field with copper-coloured island silhouette above two olive branches',
      motto: '',
      footballTeam: 'APOEL FC',
    ),
    'CZ': EuropeClueData(
      nickname: 'The Heart of Europe',
      famousLandmark: 'Prague Castle',
      famousPeople: ['Franz Kafka', 'Jaromir Jagr', 'Antonin Dvorak'],
      flag: 'Two horizontal stripes white and red with blue triangle at hoist',
      motto: 'Pravda vitezi (Truth prevails)',
      footballTeam: 'Narodni tym',
    ),
    'DE': EuropeClueData(
      nickname: 'Das Land der Dichter und Denker',
      famousLandmark: 'Brandenburg Gate',
      famousPeople: [
        'Albert Einstein',
        'Ludwig van Beethoven',
        'Angela Merkel'
      ],
      flag: 'Three horizontal stripes: black, red, gold',
      motto: 'Einigkeit und Recht und Freiheit (Unity and Justice and Freedom)',
      footballTeam: 'Die Mannschaft',
    ),
    'DK': EuropeClueData(
      nickname: 'The Land of the Danes',
      famousLandmark: 'The Little Mermaid',
      famousPeople: ['Hans Christian Andersen', 'Mads Mikkelsen', 'Niels Bohr'],
      flag: 'Red field with white Scandinavian cross (Dannebrog)',
      motto: '',
      footballTeam: 'Danish Dynamite',
    ),
    'EE': EuropeClueData(
      nickname: 'The Digital Nation',
      famousLandmark: 'Tallinn Old Town',
      famousPeople: ['Arvo Part', 'Ott Tanak'],
      flag: 'Three horizontal stripes: blue, black, white',
      motto: '',
      footballTeam: 'FC Flora Tallinn',
    ),
    'ES': EuropeClueData(
      nickname: 'The Kingdom of the Sun',
      famousLandmark: 'Sagrada Familia',
      famousPeople: [
        'Pablo Picasso',
        'Rafael Nadal',
        'Antonio Banderas',
        'Salvador Dali',
      ],
      flag:
          'Three horizontal stripes: red, yellow (double width), red with coat of arms',
      motto: 'Plus Ultra (Further Beyond)',
      footballTeam: 'La Roja',
    ),
    'FI': EuropeClueData(
      nickname: 'The Land of a Thousand Lakes',
      famousLandmark: 'Suomenlinna Fortress',
      famousPeople: ['Jean Sibelius', 'Kimi Raikkonen', 'Linus Torvalds'],
      flag: 'White field with blue Scandinavian cross',
      motto: '',
      footballTeam: 'Huuhkajat',
    ),
    'FR': EuropeClueData(
      nickname: 'L\'Hexagone',
      famousLandmark: 'Eiffel Tower',
      famousPeople: [
        'Napoleon Bonaparte',
        'Zinedine Zidane',
        'Coco Chanel',
        'Victor Hugo',
      ],
      flag: 'Three vertical stripes: blue, white, red',
      motto: 'Liberte, Egalite, Fraternite',
      footballTeam: 'Les Bleus',
    ),
    'GB': EuropeClueData(
      nickname: 'Blighty',
      famousLandmark: 'Big Ben',
      famousPeople: [
        'William Shakespeare',
        'Queen Elizabeth II',
        'David Beckham',
        'Adele',
      ],
      flag:
          'Blue field with red and white crosses of St George, St Andrew, and St Patrick (Union Jack)',
      motto: 'Dieu et mon droit (God and my right)',
      footballTeam: 'The Three Lions',
    ),
    'GR': EuropeClueData(
      nickname: 'The Cradle of Western Civilisation',
      famousLandmark: 'Parthenon',
      famousPeople: ['Aristotle', 'Socrates', 'Alexander the Great'],
      flag:
          'Nine horizontal stripes alternating blue and white with white cross on blue canton',
      motto: 'Eleftheria i Thanatos (Freedom or Death)',
      footballTeam: 'Ethniki',
    ),
    'HR': EuropeClueData(
      nickname: 'The Land of a Thousand Islands',
      famousLandmark: 'Dubrovnik Old Town',
      famousPeople: ['Nikola Tesla', 'Luka Modric'],
      flag:
          'Three horizontal stripes: red, white, blue with chequered coat of arms',
      motto: '',
      footballTeam: 'Vatreni',
    ),
    'HU': EuropeClueData(
      nickname: 'The Land of Thermal Waters',
      famousLandmark: 'Hungarian Parliament Building',
      famousPeople: ['Franz Liszt', 'Rubik Erno (inventor of Rubik\'s Cube)'],
      flag: 'Three horizontal stripes: red, white, green',
      motto: '',
      footballTeam: 'Magyarok',
    ),
    'IE': EuropeClueData(
      nickname: 'The Emerald Isle',
      famousLandmark: 'Cliffs of Moher',
      famousPeople: ['Oscar Wilde', 'Conor McGregor', 'Bono'],
      flag: 'Three vertical stripes: green, white, orange',
      motto: '',
      footballTeam: 'Boys in Green',
    ),
    'IS': EuropeClueData(
      nickname: 'The Land of Fire and Ice',
      famousLandmark: 'Hallgrimskirkja',
      famousPeople: ['Bjork', 'Hafthor Bjornsson'],
      flag: 'Blue field with red Scandinavian cross outlined in white',
      motto: '',
      footballTeam: 'Strakarnir okkar',
    ),
    'IT': EuropeClueData(
      nickname: 'The Boot',
      famousLandmark: 'Colosseum',
      famousPeople: [
        'Leonardo da Vinci',
        'Michelangelo',
        'Marco Polo',
        'Andrea Bocelli',
      ],
      flag: 'Three vertical stripes: green, white, red',
      motto: '',
      footballTeam: 'Gli Azzurri',
    ),
    'LI': EuropeClueData(
      nickname: 'The Doubly Landlocked Principality',
      famousLandmark: 'Vaduz Castle',
      famousPeople: ['Hans-Adam II'],
      flag:
          'Two horizontal stripes: blue and red with gold crown on blue stripe',
      motto: 'Fur Gott, Furst und Vaterland (For God, Prince, and Fatherland)',
      footballTeam: 'FC Vaduz',
    ),
    'LT': EuropeClueData(
      nickname: 'The Land of Amber',
      famousLandmark: 'Gediminas Tower',
      famousPeople: ['Violeta Urmana', 'Arvydas Sabonis'],
      flag: 'Three horizontal stripes: yellow, green, red',
      motto:
          'Tautos jega, vienybe teze (The strength of the nation lies in unity)',
      footballTeam: 'FK Zalgiris Vilnius',
    ),
    'LU': EuropeClueData(
      nickname: 'The Grand Duchy',
      famousLandmark: 'Casemates du Bock',
      famousPeople: ['Robert Schuman'],
      flag: 'Three horizontal stripes: red, white, light blue',
      motto: 'Mir welle bleiwe wat mir sinn (We want to remain what we are)',
      footballTeam: 'F91 Dudelange',
    ),
    'LV': EuropeClueData(
      nickname: 'The Land of Blue Lakes',
      famousLandmark: 'Riga Old Town',
      famousPeople: ['Mikhail Eisenstein', 'Kristaps Porzingis'],
      flag: 'Dark red field with narrow white horizontal stripe through centre',
      motto: 'Tiesu tiesai (For justice)',
      footballTeam: 'FK RFS',
    ),
    'MC': EuropeClueData(
      nickname: 'The Rock',
      famousLandmark: 'Monte Carlo Casino',
      famousPeople: ['Grace Kelly', 'Prince Albert II'],
      flag: 'Two horizontal stripes: red over white',
      motto: 'Deo Juvante (With God\'s Help)',
      footballTeam: 'AS Monaco',
    ),
    'MD': EuropeClueData(
      nickname: 'The Land Between Rivers',
      famousLandmark: 'Orheiul Vechi',
      famousPeople: ['Eugen Doga'],
      flag:
          'Three vertical stripes: blue, yellow, red with coat of arms on yellow',
      motto: '',
      footballTeam: 'Sheriff Tiraspol',
    ),
    'ME': EuropeClueData(
      nickname: 'The Pearl of the Mediterranean',
      famousLandmark: 'Bay of Kotor',
      famousPeople: ['Petar II Petrovic-Njegos'],
      flag:
          'Red field with gold border and gold double-headed eagle coat of arms',
      motto: '',
      footballTeam: 'Hrabri Sokoli',
    ),
    'MK': EuropeClueData(
      nickname: 'The Land of the Sun',
      famousLandmark: 'Lake Ohrid',
      famousPeople: ['Mother Teresa', 'Alexander the Great'],
      flag:
          'Red field with yellow sun and eight broadening rays extending to edges',
      motto: '',
      footballTeam: 'FK Vardar',
    ),
    'MT': EuropeClueData(
      nickname: 'The George Cross Island',
      famousLandmark: 'Megalithic Temples of Malta',
      famousPeople: ['Dom Mintoff'],
      flag: 'Two vertical halves: white and red with George Cross on white',
      motto: '',
      footballTeam: 'Valletta FC',
    ),
    'NL': EuropeClueData(
      nickname: 'The Low Countries',
      famousLandmark: 'Anne Frank House',
      famousPeople: ['Vincent van Gogh', 'Rembrandt', 'Max Verstappen'],
      flag: 'Three horizontal stripes: red, white, blue',
      motto: 'Je maintiendrai (I will maintain)',
      footballTeam: 'Oranje',
    ),
    'NO': EuropeClueData(
      nickname: 'The Land of the Midnight Sun',
      famousLandmark: 'Geirangerfjord',
      famousPeople: ['Edvard Munch', 'Erling Haaland', 'Roald Amundsen'],
      flag: 'Red field with blue Scandinavian cross outlined in white',
      motto: 'Alt for Norge (Everything for Norway)',
      footballTeam: 'Landslaget',
    ),
    'PL': EuropeClueData(
      nickname: 'The Land of the White Eagle',
      famousLandmark: 'Wawel Castle',
      famousPeople: ['Marie Curie', 'Frederic Chopin', 'Robert Lewandowski'],
      flag: 'Two horizontal stripes: white over red',
      motto: '',
      footballTeam: 'Bialo-Czerwoni',
    ),
    'PT': EuropeClueData(
      nickname: 'The Land of Explorers',
      famousLandmark: 'Tower of Belem',
      famousPeople: ['Cristiano Ronaldo', 'Vasco da Gama', 'Fernando Pessoa'],
      flag:
          'Two vertical sections green and red with coat of arms on dividing line',
      motto: '',
      footballTeam: 'Selecao das Quinas',
    ),
    'RO': EuropeClueData(
      nickname: 'The Land of Dracula',
      famousLandmark: 'Bran Castle',
      famousPeople: ['Nadia Comaneci', 'Gheorghe Hagi'],
      flag: 'Three vertical stripes: blue, yellow, red',
      motto: '',
      footballTeam: 'Tricolorii',
    ),
    'RS': EuropeClueData(
      nickname: 'The Land of Raspberries',
      famousLandmark: 'Belgrade Fortress',
      famousPeople: ['Nikola Tesla', 'Novak Djokovic'],
      flag:
          'Three horizontal stripes: red, blue, white with coat of arms on hoist side',
      motto: '',
      footballTeam: 'Orlovi',
    ),
    'RU': EuropeClueData(
      nickname: 'The Motherland',
      famousLandmark: 'Saint Basil\'s Cathedral',
      famousPeople: ['Leo Tolstoy', 'Fyodor Dostoevsky', 'Yuri Gagarin'],
      flag: 'Three horizontal stripes: white, blue, red',
      motto: '',
      footballTeam: 'Sbornaya',
    ),
    'SE': EuropeClueData(
      nickname: 'The Land of the Vikings',
      famousLandmark: 'Vasa Museum',
      famousPeople: ['Alfred Nobel', 'Zlatan Ibrahimovic', 'ABBA'],
      flag: 'Blue field with yellow Scandinavian cross',
      motto: 'For Sverige i tiden (For Sweden, with the times)',
      footballTeam: 'Blagult',
    ),
    'SI': EuropeClueData(
      nickname: 'The Sunny Side of the Alps',
      famousLandmark: 'Lake Bled',
      famousPeople: ['Slavoj Zizek', 'Luka Doncic'],
      flag:
          'Three horizontal stripes: white, blue, red with coat of arms on upper hoist',
      motto: '',
      footballTeam: 'Zmajceki',
    ),
    'SK': EuropeClueData(
      nickname: 'The Tatra Tiger',
      famousLandmark: 'Spis Castle',
      famousPeople: ['Andy Warhol', 'Peter Sagan'],
      flag:
          'Three horizontal stripes: white, blue, red with coat of arms on hoist side',
      motto: '',
      footballTeam: 'Repre',
    ),
    'SM': EuropeClueData(
      nickname: 'The Most Serene Republic',
      famousLandmark: 'Guaita Tower',
      famousPeople: ['Saint Marinus'],
      flag:
          'Two horizontal stripes: white over light blue with coat of arms in centre',
      motto: 'Libertas (Liberty)',
      footballTeam: 'San Marino Calcio',
    ),
    'TR': EuropeClueData(
      nickname: 'The Bridge Between East and West',
      famousLandmark: 'Hagia Sophia',
      famousPeople: ['Mustafa Kemal Ataturk'],
      flag: 'Red field with white crescent moon and star',
      motto: 'Yurtta sulh, cihanda sulh (Peace at home, peace in the world)',
      footballTeam: 'Ay-Yildizlilar',
    ),
    'UA': EuropeClueData(
      nickname: 'The Breadbasket of Europe',
      famousLandmark: 'Saint Sophia\'s Cathedral, Kyiv',
      famousPeople: ['Taras Shevchenko', 'Andriy Shevchenko', 'Mila Kunis'],
      flag: 'Two horizontal stripes: blue over yellow',
      motto: '',
      footballTeam: 'Zbirna',
    ),
    'VA': EuropeClueData(
      nickname: 'The Holy See',
      famousLandmark: 'St. Peter\'s Basilica',
      famousPeople: ['Pope Francis', 'Pope John Paul II'],
      flag:
          'Two vertical halves: yellow and white with papal tiara and keys on white',
      motto: '',
      footballTeam: '',
    ),
    'XK': EuropeClueData(
      nickname: 'The Young European Nation',
      famousLandmark: 'Gjakova Bazaar',
      famousPeople: ['Ibrahim Rugova', 'Dua Lipa'],
      flag: 'Blue field with gold map of Kosovo and six white stars above',
      motto: '',
      footballTeam: 'Dardanet',
    ),
  };
}
