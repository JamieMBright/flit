/// Regional clue data for major counties and regions of the United Kingdom
library;

class UkCountyClueData {
  const UkCountyClueData({
    required this.country,
    required this.famousPerson,
    required this.famousLandmark,
    required this.footballTeam,
    required this.nickname,
  });

  final String country;
  final String famousPerson;
  final String famousLandmark;
  final String footballTeam;
  final String nickname;
}

abstract class UkClues {
  static const Map<String, UkCountyClueData> data = {
    // ENGLAND - Metropolitan & Major Counties
    'GLA': UkCountyClueData(
      country: 'England',
      famousPerson: 'Charles Dickens',
      famousLandmark: 'Tower Bridge',
      footballTeam: 'Arsenal, Chelsea, Tottenham',
      nickname: 'The Big Smoke',
    ),
    'WMD': UkCountyClueData(
      country: 'England',
      famousPerson: 'Ozzy Osbourne',
      famousLandmark: 'Birmingham Cathedral',
      footballTeam: 'Aston Villa, Birmingham City',
      nickname: 'The Black Country',
    ),
    'GTM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Noel Gallagher',
      famousLandmark: 'Old Trafford Stadium',
      footballTeam: 'Manchester United, Manchester City',
      nickname: 'Cottonopolis',
    ),
    'WYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Patrick Stewart',
      famousLandmark: 'Leeds Town Hall',
      footballTeam: 'Leeds United',
      nickname: 'God\'s Own County',
    ),
    'MER': UkCountyClueData(
      country: 'England',
      famousPerson: 'The Beatles',
      famousLandmark: 'Royal Liver Building',
      footballTeam: 'Liverpool FC, Everton',
      nickname: 'The Pool of Life',
    ),
    'SYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sean Bean',
      famousLandmark: 'Sheffield Cathedral',
      footballTeam: 'Sheffield United, Sheffield Wednesday',
      nickname: 'Steel City',
    ),
    'TWR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sting',
      famousLandmark: 'Angel of the North',
      footballTeam: 'Newcastle United, Sunderland AFC',
      nickname: 'The Geordies',
    ),

    // ENGLAND - Southern Counties
    'KEN': UkCountyClueData(
      country: 'England',
      famousPerson: 'Charles Darwin',
      famousLandmark: 'Canterbury Cathedral',
      footballTeam: 'Gillingham FC',
      nickname: 'The Garden of England',
    ),
    'ESS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jamie Oliver',
      famousLandmark: 'Colchester Castle',
      footballTeam: 'Colchester United',
      nickname: 'The Saxon Shore',
    ),
    'HAM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jane Austen',
      famousLandmark: 'Winchester Cathedral',
      footballTeam: 'Southampton FC, Portsmouth FC',
      nickname: 'Hants',
    ),
    'SRY': UkCountyClueData(
      country: 'England',
      famousPerson: 'Eric Clapton',
      famousLandmark: 'Hampton Court Palace',
      footballTeam: 'Crystal Palace',
      nickname: 'The Home Counties',
    ),
    'HRT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Hawking',
      famousLandmark: 'St Albans Cathedral',
      footballTeam: 'Watford FC',
      nickname: 'Herts',
    ),
    'SUS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Virginia Woolf',
      famousLandmark: 'Brighton Pier',
      footballTeam: 'Brighton & Hove Albion',
      nickname: 'The Downs',
    ),
    'BRK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Kate Middleton',
      famousLandmark: 'Windsor Castle',
      footballTeam: 'Reading FC',
      nickname: 'Royal County',
    ),

    // ENGLAND - Eastern Counties
    'NFO': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Fry',
      famousLandmark: 'Norwich Cathedral',
      footballTeam: 'Norwich City',
      nickname: 'The Broads',
    ),
    'SUF': UkCountyClueData(
      country: 'England',
      famousPerson: 'Ed Sheeran',
      famousLandmark: 'Framlingham Castle',
      footballTeam: 'Ipswich Town',
      nickname: 'Silly Suffolk',
    ),
    'CAM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Hawking',
      famousLandmark: 'King\'s College Chapel',
      footballTeam: 'Cambridge United',
      nickname: 'The Fens',
    ),
    'LIN': UkCountyClueData(
      country: 'England',
      famousPerson: 'Margaret Thatcher',
      famousLandmark: 'Lincoln Cathedral',
      footballTeam: 'Lincoln City',
      nickname: 'The Yellow Bellies',
    ),

    // ENGLAND - South West
    'DEV': UkCountyClueData(
      country: 'England',
      famousPerson: 'Agatha Christie',
      famousLandmark: 'Exeter Cathedral',
      footballTeam: 'Plymouth Argyle, Exeter City',
      nickname: 'Glorious Devon',
    ),
    'COR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Rosamunde Pilcher',
      famousLandmark: 'St Michael\'s Mount',
      footballTeam: 'Truro City',
      nickname: 'The Duchy',
    ),
    'SOM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Arthur C. Clarke',
      famousLandmark: 'Glastonbury Tor',
      footballTeam: 'Bristol City',
      nickname: 'The Cider County',
    ),
    'DOR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Thomas Hardy',
      famousLandmark: 'Durdle Door',
      footballTeam: 'Bournemouth AFC',
      nickname: 'Hardy Country',
    ),

    // ENGLAND - Midlands
    'OXF': UkCountyClueData(
      country: 'England',
      famousPerson: 'J.R.R. Tolkien',
      famousLandmark: 'Radcliffe Camera',
      footballTeam: 'Oxford United',
      nickname: 'The City of Dreaming Spires',
    ),
    'WAR': UkCountyClueData(
      country: 'England',
      famousPerson: 'William Shakespeare',
      famousLandmark: 'Warwick Castle',
      footballTeam: 'Coventry City',
      nickname: 'The Heart of England',
    ),
    'NTH': UkCountyClueData(
      country: 'England',
      famousPerson: 'Alan Moore',
      famousLandmark: 'Silverstone Circuit',
      footballTeam: 'Northampton Town',
      nickname: 'The Rose of the Shires',
    ),
    'LEI': UkCountyClueData(
      country: 'England',
      famousPerson: 'Gary Lineker',
      famousLandmark: 'Leicester Cathedral',
      footballTeam: 'Leicester City',
      nickname: 'The Foxes',
    ),
    'NOT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Lord Byron',
      famousLandmark: 'Sherwood Forest',
      footballTeam: 'Nottingham Forest, Notts County',
      nickname: 'Robin Hood Country',
    ),
    'DER': UkCountyClueData(
      country: 'England',
      famousPerson: 'Florence Nightingale',
      famousLandmark: 'Chatsworth House',
      footballTeam: 'Derby County',
      nickname: 'The Peak',
    ),
    'STS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Robbie Williams',
      famousLandmark: 'Alton Towers',
      footballTeam: 'Stoke City',
      nickname: 'The Potteries',
    ),

    // ENGLAND - Northern Counties
    'LAN': UkCountyClueData(
      country: 'England',
      famousPerson: 'Andrew Flintoff',
      famousLandmark: 'Blackpool Tower',
      footballTeam: 'Blackburn Rovers, Preston North End',
      nickname: 'The Red Rose County',
    ),
    'CHS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Lewis Carroll',
      famousLandmark: 'Chester Cathedral',
      footballTeam: 'Chester FC',
      nickname: 'The County Palatine',
    ),
    'DUR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Rowan Atkinson',
      famousLandmark: 'Durham Cathedral',
      footballTeam: 'Darlington FC',
      nickname: 'Land of the Prince Bishops',
    ),
    'CUM': UkCountyClueData(
      country: 'England',
      famousPerson: 'William Wordsworth',
      famousLandmark: 'Hadrian\'s Wall',
      footballTeam: 'Carlisle United',
      nickname: 'The Lake District',
    ),
    'NBL': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jackie Charlton',
      famousLandmark: 'Lindisfarne Castle',
      footballTeam: 'Newcastle United',
      nickname: 'The Far North',
    ),

    // SCOTLAND
    'GLG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Billy Connolly',
      famousLandmark: 'Kelvingrove Art Gallery',
      footballTeam: 'Celtic, Rangers',
      nickname: 'The Dear Green Place',
    ),
    'EDH': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Graham Bell',
      famousLandmark: 'Edinburgh Castle',
      footballTeam: 'Hibernian, Hearts',
      nickname: 'Auld Reekie',
    ),
    'FIF': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Adam Smith',
      famousLandmark: 'St Andrews Links',
      footballTeam: 'Dunfermline Athletic',
      nickname: 'The Kingdom of Fife',
    ),
    'HLD': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Flora MacDonald',
      famousLandmark: 'Loch Ness',
      footballTeam: 'Inverness Caledonian Thistle',
      nickname: 'The Highlands',
    ),
    'ABD': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Annie Lennox',
      famousLandmark: 'Balmoral Castle',
      footballTeam: 'Aberdeen FC',
      nickname: 'The Granite City',
    ),
    'AYR': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Burns',
      famousLandmark: 'Burns Cottage',
      footballTeam: 'Ayr United, Kilmarnock',
      nickname: 'Burns Country',
    ),
    'DGY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert the Bruce',
      famousLandmark: 'Sweetheart Abbey',
      footballTeam: 'Queen of the South',
      nickname: 'The Galloway Hills',
    ),
    'STI': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Wallace',
      famousLandmark: 'Stirling Castle',
      footballTeam: 'Stirling Albion',
      nickname: 'The Gateway to the Highlands',
    ),

    // WALES
    'CRF': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Shirley Bassey',
      famousLandmark: 'Cardiff Castle',
      footballTeam: 'Cardiff City',
      nickname: 'The Capital',
    ),
    'SWA': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Catherine Zeta-Jones',
      famousLandmark: 'Swansea Bay',
      footballTeam: 'Swansea City',
      nickname: 'The Copperopolis',
    ),
    'GWN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Lloyd George',
      famousLandmark: 'Snowdon (Yr Wyddfa)',
      footballTeam: 'Bangor City',
      nickname: 'Land of Castles',
    ),
    'PEM': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Griff Rhys Jones',
      famousLandmark: 'Pembroke Castle',
      footballTeam: 'Haverfordwest County',
      nickname: 'Little England Beyond Wales',
    ),
    'PWS': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Laura Ashley',
      famousLandmark: 'Powis Castle',
      footballTeam: 'Newtown AFC',
      nickname: 'The Green Desert of Wales',
    ),
    'CGN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Richard Burton',
      famousLandmark: 'Conwy Castle',
      footballTeam: 'Conwy Borough',
      nickname: 'The Castle County',
    ),
    'CRD': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Caerphilly Castle',
      footballTeam: 'Cardiff Metropolitan',
      nickname: 'The Valleys',
    ),
    'DEN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Timothy Dalton',
      famousLandmark: 'Denbigh Castle',
      footballTeam: 'Rhyl FC',
      nickname: 'The Vale of Clwyd',
    ),
  };
}
