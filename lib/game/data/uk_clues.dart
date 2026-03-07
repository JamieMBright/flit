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
    // =========================================================================
    // ENGLAND - Metropolitan & Major Counties
    // =========================================================================
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

    // =========================================================================
    // ENGLAND - Southern Counties
    // =========================================================================
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
    // SUS renamed to SSX (East Sussex)
    'SSX': UkCountyClueData(
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
    'WSX': UkCountyClueData(
      country: 'England',
      famousPerson: 'Percy Bysshe Shelley',
      famousLandmark: 'Arundel Castle',
      footballTeam: 'Crawley Town',
      nickname: 'The South Downs',
    ),
    'IOW': UkCountyClueData(
      country: 'England',
      famousPerson: 'Queen Victoria',
      famousLandmark: 'Osborne House',
      footballTeam: 'Newport IOW FC',
      nickname: 'The Island',
    ),

    // =========================================================================
    // ENGLAND - Eastern Counties
    // =========================================================================
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
    'BED': UkCountyClueData(
      country: 'England',
      famousPerson: 'John Bunyan',
      famousLandmark: 'Woburn Abbey',
      footballTeam: 'Luton Town',
      nickname: 'The Bedfordshire Clanger County',
    ),

    // =========================================================================
    // ENGLAND - South West
    // =========================================================================
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
    'GLO': UkCountyClueData(
      country: 'England',
      famousPerson: 'J.K. Rowling',
      famousLandmark: 'Gloucester Cathedral',
      footballTeam: 'Cheltenham Town, Forest Green Rovers',
      nickname: 'The Cotswolds County',
    ),
    'WIL': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sir Christopher Wren',
      famousLandmark: 'Stonehenge',
      footballTeam: 'Swindon Town',
      nickname: 'The Moonraker County',
    ),

    // =========================================================================
    // ENGLAND - Midlands
    // =========================================================================
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
    'BKM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Roald Dahl',
      famousLandmark: 'Bletchley Park',
      footballTeam: 'Wycombe Wanderers',
      nickname: 'The Home of the Chilterns',
    ),
    'HEF': UkCountyClueData(
      country: 'England',
      famousPerson: 'David Garrick',
      famousLandmark: 'Hereford Cathedral',
      footballTeam: 'Hereford FC',
      nickname: 'The Marches',
    ),
    'WOR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Edward Elgar',
      famousLandmark: 'Worcester Cathedral',
      footballTeam: 'Worcester City',
      nickname: 'The Faithful City County',
    ),
    'RUT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Titus Oates',
      famousLandmark: 'Rutland Water',
      footballTeam: 'Oakham United',
      nickname: 'England\'s Smallest County',
    ),
    'SHR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Charles Darwin',
      famousLandmark: 'Ironbridge Gorge',
      footballTeam: 'Shrewsbury Town',
      nickname: 'Salop',
    ),

    // =========================================================================
    // ENGLAND - Northern Counties
    // =========================================================================
    'LAN': UkCountyClueData(
      country: 'England',
      famousPerson: 'Andrew Flintoff',
      famousLandmark: 'Blackpool Tower',
      footballTeam: 'Blackburn Rovers, Preston North End',
      nickname: 'The Red Rose County',
    ),
    // CHS renamed to CHE (Cheshire)
    'CHE': UkCountyClueData(
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
    // CUM renamed to CMA (Cumbria)
    'CMA': UkCountyClueData(
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
    'NYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'James Herriot',
      famousLandmark: 'Whitby Abbey',
      footballTeam: 'Harrogate Town, York City',
      nickname: 'God\'s Own County',
    ),
    'ERY': UkCountyClueData(
      country: 'England',
      famousPerson: 'Amy Johnson',
      famousLandmark: 'The Humber Bridge',
      footballTeam: 'Hull City',
      nickname: 'The Wolds',
    ),

    // =========================================================================
    // SCOTLAND
    // =========================================================================
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
    'ABE': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Denis Law',
      famousLandmark: 'Marischal College',
      footballTeam: 'Aberdeen FC',
      nickname: 'The Silver City',
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
    // STI renamed to STG (Stirling)
    'STG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Wallace',
      famousLandmark: 'Stirling Castle',
      footballTeam: 'Stirling Albion',
      nickname: 'The Gateway to the Highlands',
    ),
    'ANS': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Don Coutts',
      famousLandmark: 'Glamis Castle',
      footballTeam: 'Arbroath FC, Forfar Athletic',
      nickname: 'The Land o\' the Angus Glens',
    ),
    'ARG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Neil Munro',
      famousLandmark: 'Inveraray Castle',
      footballTeam: 'Oban Saints',
      nickname: 'The Gateway to the Isles',
    ),
    'CLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Bruce',
      famousLandmark: 'Alloa Tower',
      footballTeam: 'Alloa Athletic',
      nickname: 'The Wee County',
    ),
    'DND': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Mary Shelley (lived here)',
      famousLandmark: 'RRS Discovery',
      footballTeam: 'Dundee FC, Dundee United',
      nickname: 'The City of Discovery',
    ),
    'EDU': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Tom Conti',
      famousLandmark: 'Mugdock Castle',
      footballTeam: 'Kirkintilloch Rob Roy',
      nickname: 'The Bears Den',
    ),
    'EIL': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Angus MacPhee',
      famousLandmark: 'Callanish Standing Stones',
      footballTeam: 'Stornoway United',
      nickname: 'The Western Isles',
    ),
    'ELN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'John Muir',
      famousLandmark: 'Tantallon Castle',
      footballTeam: 'Dunbar United',
      nickname: 'Scotland\'s Golf Coast',
    ),
    'ERW': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'David Dale',
      famousLandmark: 'Rouken Glen Park',
      footballTeam: 'Arthurlie FC',
      nickname: 'The Ren',
    ),
    'FAL': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Rankine',
      famousLandmark: 'The Kelpies',
      footballTeam: 'Falkirk FC',
      nickname: 'The Bairns\' Town',
    ),
    'INV': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Mary Barbour',
      famousLandmark: 'Newark Castle',
      footballTeam: 'Greenock Morton',
      nickname: 'The Tail of the Bank',
    ),
    'MLN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Dolly the Sheep (Roslin Institute)',
      famousLandmark: 'Rosslyn Chapel',
      footballTeam: 'Bonnyrigg Rose Athletic',
      nickname: 'The Heart of Midlothian',
    ),
    'MRY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Ramsay MacDonald',
      famousLandmark: 'Elgin Cathedral',
      footballTeam: 'Elgin City',
      nickname: 'The Malt Whisky Country',
    ),
    'NAY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Fleming',
      famousLandmark: 'Brodick Castle',
      footballTeam: 'Kilwinning Rangers',
      nickname: 'The Ayrshire Coast',
    ),
    'NLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Baird',
      famousLandmark: 'Summerlee Museum of Scottish Industrial Life',
      footballTeam: 'Motherwell FC, Airdrieonians',
      nickname: 'The Lanarkshire Heartland',
    ),
    'ORK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'George Mackay Brown',
      famousLandmark: 'Skara Brae',
      footballTeam: 'Orkney FC',
      nickname: 'The Northern Isles',
    ),
    'PKN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'John Buchan',
      famousLandmark: 'Scone Palace',
      footballTeam: 'St Johnstone',
      nickname: 'The Big County',
    ),
    'RFW': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Gerry Rafferty',
      famousLandmark: 'Paisley Abbey',
      footballTeam: 'St Mirren',
      nickname: 'The Buddies\' Land',
    ),
    'SAY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Burns (Alloway)',
      famousLandmark: 'Culzean Castle',
      footballTeam: 'Ayr United',
      nickname: 'The Burns Coast',
    ),
    'SCB': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Walter Scott',
      famousLandmark: 'Abbotsford House',
      footballTeam: 'Gala Fairydean Rovers',
      nickname: 'Scott\'s Country',
    ),
    'SLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Sir Harry Lauder',
      famousLandmark: 'New Lanark',
      footballTeam: 'Hamilton Academical',
      nickname: 'The Clyde Valley',
    ),
    'WDU': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Tobias Smollett',
      famousLandmark: 'Dumbarton Castle',
      footballTeam: 'Dumbarton FC',
      nickname: 'The Rock',
    ),
    'WLN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Dougray Scott',
      famousLandmark: 'Linlithgow Palace',
      footballTeam: 'Livingston FC',
      nickname: 'The Shale Oil County',
    ),
    'ZET': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Arthur Anderson',
      famousLandmark: 'Jarlshof',
      footballTeam: 'Shetland FC',
      nickname: 'The Old Rock',
    ),

    // =========================================================================
    // WALES
    // =========================================================================
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
    // PWS renamed to POW (Powys)
    'POW': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Laura Ashley',
      famousLandmark: 'Powis Castle',
      footballTeam: 'Newtown AFC',
      nickname: 'The Green Desert of Wales',
    ),
    // CRD renamed to CAY (Caerphilly)
    'CAY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Caerphilly Castle',
      footballTeam: 'Cardiff Metropolitan',
      nickname: 'The Valleys',
    ),
    'NWP': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Mark Williams',
      famousLandmark: 'Newport Transporter Bridge',
      footballTeam: 'Newport County',
      nickname: 'The Gateway to Wales',
    ),
    'RCT': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Rhondda Heritage Park',
      footballTeam: 'Pontypridd Town',
      nickname: 'The Rhondda Valleys',
    ),
    'FLN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Jonathan Davies',
      famousLandmark: 'Flint Castle',
      footballTeam: 'Connah\'s Quay Nomads',
      nickname: 'The Borderlands',
    ),
    'WRX': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Elihu Yale',
      famousLandmark: 'Wrexham Parish Church',
      footballTeam: 'Wrexham AFC',
      nickname: 'The Gateway to Wales',
    ),
    'CMN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Hedd Wyn',
      famousLandmark: 'National Botanic Garden of Wales',
      footballTeam: 'Carmarthen Town',
      nickname: 'The Garden of Wales',
    ),
    'CRG': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Augustus John',
      famousLandmark: 'Devil\'s Bridge',
      footballTeam: 'Aberystwyth Town',
      nickname: 'The Celtic Heartland',
    ),
    'AGY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Anglesey Druid heritage',
      famousLandmark: 'Beaumaris Castle',
      footballTeam: 'Holyhead Hotspur',
      nickname: 'Mother of Wales',
    ),

    // =========================================================================
    // NORTHERN IRELAND
    // =========================================================================
    'ANT': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Liam Neeson',
      famousLandmark: 'Giant\'s Causeway',
      footballTeam: 'Glentoran, Cliftonville, Linfield',
      nickname: 'The Glens',
    ),
    'ARM': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'George Best',
      famousLandmark: 'Armagh Cathedral',
      footballTeam: 'Armagh City FC',
      nickname: 'The Orchard County',
    ),
    'DOW': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Patrick Bronte',
      famousLandmark: 'Mourne Mountains',
      footballTeam: 'Glenavon FC',
      nickname: 'The Mournes',
    ),
    'FER': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Samuel Beckett',
      famousLandmark: 'Enniskillen Castle',
      footballTeam: 'Enniskillen Town',
      nickname: 'The Lakeland County',
    ),
    'LDY': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Seamus Heaney',
      famousLandmark: 'Derry City Walls',
      footballTeam: 'Derry City FC',
      nickname: 'The Maiden City',
    ),
    'TYR': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Brian Friel',
      famousLandmark: 'Sperrin Mountains',
      footballTeam: 'Dungannon Swifts',
      nickname: 'O\'Neill Country',
    ),
  };
}
