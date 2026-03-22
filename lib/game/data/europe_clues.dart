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
          'The blue, yellow, and red vertical stripes blend the colours of France and Spain — this nation\'s two co-sovereign neighbours — while the central coat of arms unites symbols of both protecting powers',
      motto: 'Virtus Unita Fortior',
      footballTeam: 'FC Andorra',
    ),
    'AL': EuropeClueData(
      nickname: 'The Land of the Eagles',
      famousLandmark: 'Butrint',
      famousPeople: ['Mother Teresa', 'Dua Lipa', 'Rita Ora'],
      flag:
          'The double-headed eagle is the seal of the national hero Gjergj Kastrioti Skanderbeg, who resisted Ottoman conquest in the 15th century; the red field represents bravery and the blood shed for independence',
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
      flag:
          'Legend traces the red-white-red to Duke Leopold V\'s blood-soaked surcoat at the Siege of Acre in 1191, where only the cloth under his belt remained white — one of the oldest flag designs still in use',
      motto: '',
      footballTeam: 'Das Team',
    ),
    'BA': EuropeClueData(
      nickname: 'The Heart-Shaped Land',
      famousLandmark: 'Stari Most (Old Bridge of Mostar)',
      famousPeople: ['Ivo Andric', 'Edin Dzeko'],
      flag:
          'Adopted after the Dayton Agreement, the blue field and white stars evoke Europe, the yellow triangle represents the three constituent peoples of this nation and roughly mirrors the shape of this nation on the map',
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
      flag:
          'The black, yellow, and red vertical tricolour was inspired by the French Tricolore during the 1830 revolution against Dutch rule; the colours derive from the Duchy of Brabant\'s coat of arms — a gold lion with red claws on a black shield',
      motto: 'Eendracht maakt macht / L\'union fait la force',
      footballTeam: 'De Rode Duivels',
    ),
    'BG': EuropeClueData(
      nickname: 'The Land of Roses',
      famousLandmark: 'Alexander Nevsky Cathedral',
      famousPeople: ['Hristo Stoichkov', 'Grigor Dimitrov'],
      flag:
          'The white represents peace and Slavic heritage, the green symbolises agricultural fertility, and the red stands for the courage and blood of those who fought for independence from Ottoman rule',
      motto: 'Saединението прави силата (Unity makes strength)',
      footballTeam: 'The Lions',
    ),
    'BY': EuropeClueData(
      nickname: 'White Rus',
      famousLandmark: 'Mir Castle',
      famousPeople: ['Marc Chagall', 'Victoria Azarenka'],
      flag:
          'The red and green recall Soviet-era national colours; the red symbolises the blood shed in defence of the nation, the green represents forests and spring, and the ornamental side panel reproduces a traditional rushnyk woven textile pattern',
      motto: '',
      footballTeam: 'FC BATE Borisov',
    ),
    'CH': EuropeClueData(
      nickname: 'The Playground of Europe',
      famousLandmark: 'Matterhorn',
      famousPeople: ['Albert Einstein', 'Roger Federer', 'William Tell'],
      flag:
          'The white cross on red dates to the Battle of Laupen in 1339 and derives from the Holy Roman Empire\'s war banner; this nation is one of only two sovereign states with a square flag, reflecting the federal coat of arms',
      motto: 'Unus pro omnibus, omnes pro uno (One for all, all for one)',
      footballTeam: 'Nati',
    ),
    'CY': EuropeClueData(
      nickname: 'The Island of Aphrodite',
      famousLandmark: 'Tombs of the Kings',
      famousPeople: ['Zeno of Citium'],
      flag:
          'The white field represents peace between the island\'s Greek and Turkish communities, the copper-orange silhouette honours the island\'s name (from the Greek "kypros" meaning copper), and the olive branches below reinforce the hope for peace',
      motto: '',
      footballTeam: 'APOEL FC',
    ),
    'CZ': EuropeClueData(
      nickname: 'The Heart of Europe',
      famousLandmark: 'Prague Castle',
      famousPeople: ['Franz Kafka', 'Jaromir Jagr', 'Antonin Dvorak'],
      flag:
          'The white and red horizontal bands come from the ancient Bohemian coat of arms (a white lion on red), and the blue triangle was added in 1920 to distinguish the former federation from Poland\'s similar white-and-red flag',
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
      flag:
          'The black, red, and gold trace back to the uniforms of the Lützow Free Corps who fought Napoleon — the black cloth, red facings, and gold buttons became symbols of national unity and the democratic movement of 1848',
      motto: 'Einigkeit und Recht und Freiheit (Unity and Justice and Freedom)',
      footballTeam: 'Die Mannschaft',
    ),
    'DK': EuropeClueData(
      nickname: 'The Land of the Danes',
      famousLandmark: 'The Little Mermaid',
      famousPeople: ['Hans Christian Andersen', 'Mads Mikkelsen', 'Niels Bohr'],
      flag:
          'The Dannebrog is the oldest continuously used national flag in the world; legend holds it fell from the sky during the Battle of Lyndanisse in 1219, and the white Scandinavian cross on red has been this nation\'s symbol ever since',
      motto: '',
      footballTeam: 'Danish Dynamite',
    ),
    'EE': EuropeClueData(
      nickname: 'The Digital Nation',
      famousLandmark: 'Tallinn Old Town',
      famousPeople: ['Arvo Part', 'Ott Tanak'],
      flag:
          'The blue represents the sky, sea, and national loyalty; the black symbolises the dark past of oppression and the fertile soil; the white stands for snow, purity, and the aspiration for freedom — together they paint the national landscape',
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
          'The red and yellow (gualda) stripes trace to the medieval Crown of Aragon; legend says King Charles III chose the design in 1785 because it was visible at sea — the coat of arms combines the symbols of the historical kingdoms of Castile, León, Aragon, and Navarre',
      motto: 'Plus Ultra (Further Beyond)',
      footballTeam: 'La Roja',
    ),
    'FI': EuropeClueData(
      nickname: 'The Land of a Thousand Lakes',
      famousLandmark: 'Suomenlinna Fortress',
      famousPeople: ['Jean Sibelius', 'Kimi Raikkonen', 'Linus Torvalds'],
      flag:
          'The blue Nordic cross represents the thousands of lakes and the sky, set on a white field symbolising the winter snow — a design adopted at independence in 1917 to express this nation\'s identity within the Scandinavian cross tradition',
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
      flag:
          'The tricolore combines the red and blue of Paris (colours of the city\'s coat of arms) with the white of the Bourbon monarchy, symbolising the unity of the king and the people during the 1789 Revolution',
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
          'The Union Jack layers the crosses of England\'s St George (red on white), Scotland\'s St Andrew (white saltire on blue), and Ireland\'s St Patrick (red saltire on white), representing the political union of the three kingdoms',
      motto: 'Dieu et mon droit (God and my right)',
      footballTeam: 'The Three Lions',
    ),
    'GR': EuropeClueData(
      nickname: 'The Cradle of Western Civilisation',
      famousLandmark: 'Parthenon',
      famousPeople: ['Aristotle', 'Socrates', 'Alexander the Great'],
      flag:
          'The nine blue and white stripes may represent the nine syllables of "Eleftheria i Thanatos" (Freedom or Death), the motto of the War of Independence; the white cross in the canton symbolises Orthodox Christianity',
      motto: 'Eleftheria i Thanatos (Freedom or Death)',
      footballTeam: 'Ethniki',
    ),
    'HR': EuropeClueData(
      nickname: 'The Land of a Thousand Islands',
      famousLandmark: 'Dubrovnik Old Town',
      famousPeople: ['Nikola Tesla', 'Luka Modric'],
      flag:
          'The red-white-blue Pan-Slavic tricolour links this nation to its Slavic roots, while the chequerboard shield (šahovnica) has been a national symbol since the medieval kingdom, first documented in the 15th century',
      motto: '',
      footballTeam: 'Vatreni',
    ),
    'HU': EuropeClueData(
      nickname: 'The Land of Thermal Waters',
      famousLandmark: 'Hungarian Parliament Building',
      famousPeople: ['Franz Liszt', 'Rubik Erno (inventor of Rubik\'s Cube)'],
      flag:
          'The red, white, and green horizontal tricolour draws from the national coat of arms — red for strength, white for faithfulness, and green for hope — popularised during the 1848 revolution against Habsburg rule',
      motto: '',
      footballTeam: 'Magyarok',
    ),
    'IE': EuropeClueData(
      nickname: 'The Emerald Isle',
      famousLandmark: 'Cliffs of Moher',
      famousPeople: ['Oscar Wilde', 'Conor McGregor', 'Bono'],
      flag:
          'The green represents the Gaelic and Catholic tradition, the orange honours the Protestant (William of Orange) tradition, and the white between them symbolises the aspiration for peace and unity between the two communities',
      motto: '',
      footballTeam: 'Boys in Green',
    ),
    'IS': EuropeClueData(
      nickname: 'The Land of Fire and Ice',
      famousLandmark: 'Hallgrimskirkja',
      famousPeople: ['Bjork', 'Hafthor Bjornsson'],
      flag:
          'The blue field represents the Atlantic Ocean and mountains, the white recalls snow and ice, and the red Nordic cross symbolises volcanic fire — together depicting this nation\'s landscape of fire and ice',
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
      flag:
          'Inspired by the French Tricolore, the green-white-red tricolour was first used by the Cisalpine Republic in 1797; green is said to represent the national landscape, white the snowy Alps, and red the blood shed for independence',
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
      flag:
          'The yellow symbolises the golden wheat fields and sunshine, the green represents the forests and countryside, and the red honours the blood shed for this nation\'s sovereignty — colours used since the early 20th century independence movement',
      motto:
          'Tautos jega, vienybe teze (The strength of the nation lies in unity)',
      footballTeam: 'FK Zalgiris Vilnius',
    ),
    'LU': EuropeClueData(
      nickname: 'The Grand Duchy',
      famousLandmark: 'Casemates du Bock',
      famousPeople: ['Robert Schuman'],
      flag:
          'The red, white, and blue horizontal tricolour derives from the 13th-century coat of arms of the local ruling Counts (a red lion on blue-and-white stripes), though it resembles the Dutch flag — the blue is intentionally a lighter shade to distinguish it',
      motto: 'Mir welle bleiwe wat mir sinn (We want to remain what we are)',
      footballTeam: 'F91 Dudelange',
    ),
    'LV': EuropeClueData(
      nickname: 'The Land of Blue Lakes',
      famousLandmark: 'Riga Old Town',
      famousPeople: ['Mikhail Eisenstein', 'Kristaps Porzingis'],
      flag:
          'The dark carmine-white-carmine design is one of the oldest in Europe, reportedly dating to a 13th-century chronicle where a tribal leader was carried wounded on a white sheet stained with blood on both edges',
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
          'The blue-yellow-red vertical tricolour reflects this nation\'s Romanian heritage (similar to Romania\'s flag), and the central coat of arms features an eagle holding a cross, sceptre, and olive branch over the traditional aurochs head',
      motto: '',
      footballTeam: 'Sheriff Tiraspol',
    ),
    'ME': EuropeClueData(
      nickname: 'The Pearl of the Mediterranean',
      famousLandmark: 'Bay of Kotor',
      famousPeople: ['Petar II Petrovic-Njegos'],
      flag:
          'The red field with gold border echoes the historical flag of the ruling dynasty of Petrović-Njegoš; the double-headed eagle and lion on the central coat of arms symbolise the unity of church and state',
      motto: '',
      footballTeam: 'Hrabri Sokoli',
    ),
    'MK': EuropeClueData(
      nickname: 'The Land of the Sun',
      famousLandmark: 'Lake Ohrid',
      famousPeople: ['Mother Teresa', 'Alexander the Great'],
      flag:
          'The golden sun with eight broadening rays on red represents the "new sun of liberty" referenced in the national anthem; the design was adopted in 1995 after the original Vergina Sun was disputed by Greece',
      motto: '',
      footballTeam: 'FK Vardar',
    ),
    'MT': EuropeClueData(
      nickname: 'The George Cross Island',
      famousLandmark: 'Megalithic Temples of Malta',
      famousPeople: ['Dom Mintoff'],
      flag:
          'The white and red halves derive from the colours of Count Roger I of Sicily, who aided the island in 1091; the George Cross in the canton was awarded by King George VI in 1942 for the island\'s heroic resistance during World War II',
      motto: '',
      footballTeam: 'Valletta FC',
    ),
    'NL': EuropeClueData(
      nickname: 'The Low Countries',
      famousLandmark: 'Anne Frank House',
      famousPeople: ['Vincent van Gogh', 'Rembrandt', 'Max Verstappen'],
      flag:
          'The red-white-blue horizontal tricolour was originally orange-white-blue (the "Prinsenvlag" of William of Orange); the orange faded to red over time in dye, and the red version became official — it influenced many later tricolour flags worldwide',
      motto: 'Je maintiendrai (I will maintain)',
      footballTeam: 'Oranje',
    ),
    'NO': EuropeClueData(
      nickname: 'The Land of the Midnight Sun',
      famousLandmark: 'Geirangerfjord',
      famousPeople: ['Edvard Munch', 'Erling Haaland', 'Roald Amundsen'],
      flag:
          'The red field with a blue Scandinavian cross outlined in white combines Denmark\'s red-and-white (recalling this nation\'s union with Denmark) and the blue of Sweden and France as a symbol of liberty — created in 1821 during the push for full independence',
      motto: 'Alt for Norge (Everything for Norway)',
      footballTeam: 'Landslaget',
    ),
    'PL': EuropeClueData(
      nickname: 'The Land of the White Eagle',
      famousLandmark: 'Wawel Castle',
      famousPeople: ['Marie Curie', 'Frederic Chopin', 'Robert Lewandowski'],
      flag:
          'The white and red derive from the national coat of arms — a white eagle on a red shield — dating back to the 13th-century Piast dynasty; the simple bicolour was adopted during the struggle for independence in 1831',
      motto: '',
      footballTeam: 'Bialo-Czerwoni',
    ),
    'PT': EuropeClueData(
      nickname: 'The Land of Explorers',
      famousLandmark: 'Tower of Belem',
      famousPeople: ['Cristiano Ronaldo', 'Vasco da Gama', 'Fernando Pessoa'],
      flag:
          'The green and red were revolutionary colours adopted after the 1910 overthrow of the monarchy; the armillary sphere represents this nation\'s Age of Exploration, and the shield bears five smaller shields recalling the victory at the Battle of Ourique in 1139',
      motto: '',
      footballTeam: 'Selecao das Quinas',
    ),
    'RO': EuropeClueData(
      nickname: 'The Land of Dracula',
      famousLandmark: 'Bran Castle',
      famousPeople: ['Nadia Comaneci', 'Gheorghe Hagi'],
      flag:
          'The blue-yellow-red vertical tricolour represents Transylvania (blue), Wallachia (yellow), and Moldavia (red) — the three historic principalities united as this nation; the colours were used in the 1848 Wallachian revolution',
      motto: '',
      footballTeam: 'Tricolorii',
    ),
    'RS': EuropeClueData(
      nickname: 'The Land of Raspberries',
      famousLandmark: 'Belgrade Fortress',
      famousPeople: ['Nikola Tesla', 'Novak Djokovic'],
      flag:
          'The red-blue-white horizontal tricolour uses Pan-Slavic colours in a distinct order; the coat of arms features the double-headed white eagle of the Nemanjić dynasty and a crown recalling the medieval empire',
      motto: '',
      footballTeam: 'Orlovi',
    ),
    'RU': EuropeClueData(
      nickname: 'The Motherland',
      famousLandmark: 'Saint Basil\'s Cathedral',
      famousPeople: ['Leo Tolstoy', 'Fyodor Dostoevsky', 'Yuri Gagarin'],
      flag:
          'The white-blue-red horizontal tricolour was introduced by Peter the Great, inspired by the Dutch flag; white represents nobility and frankness, blue faithfulness and honesty, and red courage and love — it was restored after the fall of the Soviet Union in 1991',
      motto: '',
      footballTeam: 'Sbornaya',
    ),
    'SE': EuropeClueData(
      nickname: 'The Land of the Vikings',
      famousLandmark: 'Vasa Museum',
      famousPeople: ['Alfred Nobel', 'Zlatan Ibrahimovic', 'ABBA'],
      flag:
          'The blue and gold Nordic cross derives from the national coat of arms (three gold crowns on blue); the Scandinavian cross design was influenced by Denmark\'s Dannebrog, and the colours have symbolised this nation since at least the 16th century',
      motto: 'For Sverige i tiden (For Sweden, with the times)',
      footballTeam: 'Blagult',
    ),
    'SI': EuropeClueData(
      nickname: 'The Sunny Side of the Alps',
      famousLandmark: 'Lake Bled',
      famousPeople: ['Slavoj Zizek', 'Luka Doncic'],
      flag:
          'The white-blue-red Pan-Slavic tricolour bears a coat of arms depicting Mount Triglav (the nation\'s highest peak), two wavy blue lines representing rivers and the Adriatic Sea, and three gold stars from the Counts of Celje',
      motto: '',
      footballTeam: 'Zmajceki',
    ),
    'SK': EuropeClueData(
      nickname: 'The Tatra Tiger',
      famousLandmark: 'Spis Castle',
      famousPeople: ['Andy Warhol', 'Peter Sagan'],
      flag:
          'The white-blue-red horizontal tricolour uses Pan-Slavic colours, and the coat of arms depicts a double cross on three hills (Tatra, Fatra, and Mátra mountains), symbolising this nation\'s Christian heritage and geographic landscape',
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
      flag:
          'The blue represents the sky above and the yellow the wheat fields below — a simple depiction of the national landscape; the colours were first used by the People\'s Republic in 1918 and restored at independence in 1992',
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
      flag:
          'Adopted at independence in 2008, the blue field represents aspirations for European integration, the gold map silhouette shows the national territory, and the six white stars above symbolise the six major ethnic groups — Albanian, Serbian, Turkish, Gorani, Romani, and Bosniak',
      motto: '',
      footballTeam: 'Dardanet',
    ),
  };
}
