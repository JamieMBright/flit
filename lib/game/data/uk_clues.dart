/// Regional clue data for major counties and regions of the United Kingdom
library;

class UkCountyClueData {
  const UkCountyClueData({
    required this.country,
    required this.famousPerson,
    required this.famousLandmark,
    required this.footballTeam,
    required this.nickname,
    required this.flag,
  });

  final String country;
  final String famousPerson;
  final String famousLandmark;
  final String footballTeam;
  final String nickname;
  final String flag;
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
      flag:
          'The flag of this city bears the cross of St George, patron saint of England, with the sword of St Paul in the upper hoist — a tribute to the city\'s patron saint and the apostle martyred by beheading, whose symbol has appeared on the city\'s arms since the medieval period.',
    ),
    'WMD': UkCountyClueData(
      country: 'England',
      famousPerson: 'Ozzy Osbourne',
      famousLandmark: 'Birmingham Cathedral',
      footballTeam: 'Aston Villa, Birmingham City',
      nickname: 'The Black Country',
      flag:
          'The black and gold colours of this county\'s flag reflect the identity of the Black Country — a region named for its coal-black skies during the Industrial Revolution. The diagonal cross echoes the heraldic traditions of the Mercian kingdom that once ruled this heartland of England.',
    ),
    'GTM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Noel Gallagher',
      famousLandmark: 'Old Trafford Stadium',
      footballTeam: 'Manchester United, Manchester City',
      nickname: 'Cottonopolis',
      flag:
          'This county\'s flag draws on the arms of its principal city, where the gold ship symbolises the great Ship Canal — once the lifeline of the cotton trade that made the city the world\'s first industrial metropolis. The three gold stripes represent the rivers Irwell, Medlock and Irk that shaped the city\'s growth.',
    ),
    'WYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Patrick Stewart',
      famousLandmark: 'Leeds Town Hall',
      footballTeam: 'Leeds United',
      nickname: 'God\'s Own County',
      flag:
          'The white rose on blue is the emblem of the House of York, one of the two rival dynasties of the Wars of the Roses. The white rose has symbolised this county since at least the 15th century and represents its fierce pride in its identity — the most populous county in England.',
    ),
    'MER': UkCountyClueData(
      country: 'England',
      famousPerson: 'The Beatles',
      famousLandmark: 'Royal Liver Building',
      footballTeam: 'Liverpool FC, Everton',
      nickname: 'The Pool of Life',
      flag:
          'The Liver Bird — a mythical cormorant-like creature — has been the symbol of Liverpool since the city\'s first seal in the 13th century. Legend holds the birds guard the city; if they fly away, the city will cease to exist. The wavy band represents the River Mersey, the tidal highway that made Liverpool a great trading port.',
    ),
    'SYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sean Bean',
      famousLandmark: 'Sheffield Cathedral',
      footballTeam: 'Sheffield United, Sheffield Wednesday',
      nickname: 'Steel City',
      flag:
          'This county\'s flag combines the white rose of the House of York with the green of the county\'s rural landscape — acknowledging that even this industrial heartland, home to the steel and cutlery trades, is rooted in the broader Yorkshire identity forged over centuries of shared history.',
    ),
    'TWR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sting',
      famousLandmark: 'Angel of the North',
      footballTeam: 'Newcastle United, Sunderland AFC',
      nickname: 'The Geordies',
      flag:
          'This county\'s arms draw on the heraldry of Newcastle and Sunderland. The castle references Newcastle\'s Norman fortification — the "new castle" built by Robert Curthose, son of William the Conqueror, in 1080. The lion echoes the arms of the powerful Percy family, Earls of Northumberland, who dominated the region for centuries.',
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
      flag:
          'The white horse (the Invicta horse) is one of England\'s oldest county symbols, appearing in arms since at least the 14th century. It likely derives from the Saxon kingdom that once occupied this land, whose legendary founders Hengist and Horsa bore horse names, and whose battle standard was said to carry this symbol when they first conquered the land.',
    ),
    'ESS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jamie Oliver',
      famousLandmark: 'Colchester Castle',
      footballTeam: 'Colchester United',
      nickname: 'The Saxon Shore',
      flag:
          'This county takes its name from the East Saxons, and its three seaxes (curved Saxon swords) are among the oldest heraldic emblems in England. The seax was the signature weapon of the Saxon people; these blades represent the three divisions of the ancient kingdom here — a symbol carried since the medieval roll of arms.',
    ),
    'HAM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jane Austen',
      famousLandmark: 'Winchester Cathedral',
      footballTeam: 'Southampton FC, Portsmouth FC',
      nickname: 'Hants',
      flag:
          'This county\'s flag features the Tudor rose, the dynastic emblem created by Henry VII to unite the white rose of York and red rose of Lancaster after the Wars of the Roses. Winchester, the county town, was the ancient capital of England and seat of the Anglo-Saxon kings — hence the regal crown acknowledging its historic primacy.',
    ),
    'SRY': UkCountyClueData(
      country: 'England',
      famousPerson: 'Eric Clapton',
      famousLandmark: 'Hampton Court Palace',
      footballTeam: 'Crystal Palace',
      nickname: 'The Home Counties',
      flag:
          'This county\'s gold and red chequered arms derive directly from the heraldry of the de Warenne family, who were the Earls here — powerful Norman lords who held the county from the Conquest. The chequy pattern was their dynastic emblem, and by inheritance it became the county\'s enduring symbol after the earldom passed to the Crown.',
    ),
    'HRT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Hawking',
      famousLandmark: 'St Albans Cathedral',
      footballTeam: 'Watford FC',
      nickname: 'Herts',
      flag:
          'This county\'s symbol is the hart (a male deer), a visual pun on the county\'s name — a form of canting heraldry, where the charge sounds like the name it represents. The county was named for Hertford ("hart ford"), the river crossing used by deer. The stag has appeared in the county arms since at least the 16th century.',
    ),
    // SUS renamed to SSX (East Sussex)
    'SSX': UkCountyClueData(
      country: 'England',
      famousPerson: 'Virginia Woolf',
      famousLandmark: 'Brighton Pier',
      footballTeam: 'Brighton & Hove Albion',
      nickname: 'The Downs',
      flag:
          'The six golden martlets (a legless heraldic bird derived from the swift) on blue are the ancient arms of the Anglo-Saxon kingdom that once occupied this region, one of the original heptarchy kingdoms. The martlet appears on the coats of arms of many local families and towns, symbolising the county\'s Saxon heritage and its identity as a distinct historic nation.',
    ),
    'BRK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Kate Middleton',
      famousLandmark: 'Windsor Castle',
      footballTeam: 'Reading FC',
      nickname: 'Royal County',
      flag:
          'This county\'s flag features the white stag, a symbol associated with the royal forests of the county and Windsor Great Park, where kings hunted for centuries. The oak alludes to these ancient royal hunting grounds. Windsor Castle, the oldest occupied castle in the world, has stood here since William the Conqueror and given the county its "Royal" designation.',
    ),
    'WSX': UkCountyClueData(
      country: 'England',
      famousPerson: 'Percy Bysshe Shelley',
      famousLandmark: 'Arundel Castle',
      footballTeam: 'Crawley Town',
      nickname: 'The South Downs',
      flag:
          'This county shares the six golden martlets of the ancient Anglo-Saxon kingdom with its eastern neighbour, a common Saxon heritage predating the modern administrative split. The crown distinguishes this county and honours Arundel Castle, ancestral seat of the Dukes of Norfolk — the highest-ranking dukedom in England and the foremost Catholic noble family.',
    ),
    'IOW': UkCountyClueData(
      country: 'England',
      famousPerson: 'Queen Victoria',
      famousLandmark: 'Osborne House',
      footballTeam: 'Newport IOW FC',
      nickname: 'The Island',
      flag:
          'This island county\'s flag reflects its ancient status as a semi-independent entity. The island was for centuries the seat of the Lords of the Isle — a title held by Norman lords and later English nobility — giving it a distinct identity apart from the mainland. The gold outline of the island itself is a rare heraldic device emphasising its island nature.',
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
      flag:
          'This county\'s black and white bicolour derives from the arms of the de Ufford family and later the Mowbray dukes who held this earldom, whose heraldic colours of sable (black) and argent (white/silver) became associated with the county. These colours also echo the distinctive black-and-white flint-knapped buildings that characterise this county\'s vernacular architecture.',
    ),
    'SUF': UkCountyClueData(
      country: 'England',
      famousPerson: 'Ed Sheeran',
      famousLandmark: 'Framlingham Castle',
      footballTeam: 'Ipswich Town',
      nickname: 'Silly Suffolk',
      flag:
          'This county\'s flag draws on the arms of the ancient Anglo-Saxon Kingdom of the East Angles, of which this county was the southern half (South Folk). The crown references the saintly East Anglian king Edmund the Martyr, killed by Vikings in 869 and venerated as a king-saint, whose royal emblem long represented the region.',
    ),
    'CAM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Hawking',
      famousLandmark: 'King\'s College Chapel',
      footballTeam: 'Cambridge United',
      nickname: 'The Fens',
      flag:
          'The three golden crowns on blue are the arms of the East Anglian kingdom, representing the three legendary kings who once ruled the region. They are also associated with the Three Kings of Cologne, whose relics were venerated at Ely Cathedral — a centre of medieval pilgrimage in the Fens at the heart of this county.',
    ),
    'LIN': UkCountyClueData(
      country: 'England',
      famousPerson: 'Margaret Thatcher',
      famousLandmark: 'Lincoln Cathedral',
      footballTeam: 'Lincoln City',
      nickname: 'The Yellow Bellies',
      flag:
          'This county\'s flag combines the green of its famous limestone wolds and rich agricultural fenland with the fleur-de-lis taken from the arms of the City of Lincoln — a symbol linked to the French connection of the Norman cathedral builders. Lincoln was one of the largest cities in medieval England, and its arms reflect centuries of trade with France.',
    ),
    'BED': UkCountyClueData(
      country: 'England',
      famousPerson: 'John Bunyan',
      famousLandmark: 'Woburn Abbey',
      footballTeam: 'Luton Town',
      nickname: 'The Bedfordshire Clanger County',
      flag:
          'This county\'s flag bears the arms of the Beauchamp family — Earls of Bedford — who held the county in the medieval period. The three silver escallop shells on a red bend (diagonal stripe) are classic Beauchamp heraldry; the scallop shell in medieval heraldry signified a pilgrim or crusader, reflecting the family\'s religious and martial prestige.',
    ),

    // =========================================================================
    // ENGLAND - South West
    // =========================================================================
    'BST': UkCountyClueData(
      country: 'England',
      famousPerson: 'Banksy',
      famousLandmark: 'Clifton Suspension Bridge',
      footballTeam: 'Bristol City / Bristol Rovers',
      nickname: 'City of Bridges',
      flag:
          'This city\'s ship-and-castle arms originate in its medieval status as England\'s second-greatest port. The castle represents the Norman Clifton fortress built to control the Avon Gorge, while the ship embodies the Atlantic trade that made this city wealthy — including, controversially, its role as a central hub of the transatlantic slave trade.',
    ),
    'DEV': UkCountyClueData(
      country: 'England',
      famousPerson: 'Agatha Christie',
      famousLandmark: 'Exeter Cathedral',
      footballTeam: 'Plymouth Argyle, Exeter City',
      nickname: 'Glorious Devon',
      flag:
          'This county\'s green and black bicolour references the landscape contrasts: the lush green of its rolling farmland and the dark moorland of Dartmoor and Exmoor. The colours also appear in the arms of many of this county\'s gentry families. This was the county of Sir Francis Drake and Sir Walter Raleigh — Elizabethan sea-dogs who shaped England\'s maritime empire.',
    ),
    'COR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Rosamunde Pilcher',
      famousLandmark: 'St Michael\'s Mount',
      footballTeam: 'Truro City',
      nickname: 'The Duchy',
      flag:
          'St Piran\'s Cross — white on black — is the flag of this county and its patron saint, a 5th-century Irish monk who reputedly discovered tin smelting when his black hearthstone glowed white-hot. The colours represent tin (white/silver) emerging from the black ore, celebrating the industry that defined this county\'s Celtic identity for two millennia.',
    ),
    'SOM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Arthur C. Clarke',
      famousLandmark: 'Glastonbury Tor',
      footballTeam: 'Bristol City',
      nickname: 'The Cider County',
      flag:
          'This county\'s red dragon on gold derives from the arms of the ancient Kingdom of Wessex and its association with Arthurian legend — Glastonbury is traditionally identified as Avalon, the resting place of King Arthur. The dragon was the battle standard of Uther Pendragon and the Celtic warlords who resisted Saxon invasion from this heartland.',
    ),
    'DOR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Thomas Hardy',
      famousLandmark: 'Durdle Door',
      footballTeam: 'Bournemouth AFC',
      nickname: 'Hardy Country',
      flag:
          'This county\'s quartered red and gold field echoes the arms of the Bishops of Salisbury, who had jurisdiction over much of the county in the medieval period. The cross connects to the ecclesiastical history of the region, while the colours reflect the county\'s ancient manorial heritage. The county was home to many powerful Norman families after 1066.',
    ),
    'GLO': UkCountyClueData(
      country: 'England',
      famousPerson: 'J.K. Rowling',
      famousLandmark: 'Gloucester Cathedral',
      footballTeam: 'Cheltenham Town, Forest Green Rovers',
      nickname: 'The Cotswolds County',
      flag:
          'This county\'s green and gold reflect the fertile Severn Vale and the wealth of the medieval wool trade that built the county\'s magnificent churches and manor houses. The chevron pattern is drawn from the arms of the Clare family, among the most powerful Anglo-Norman dynasties, whose red chevrons on gold became inseparable from the county\'s identity.',
    ),
    'WIL': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sir Christopher Wren',
      famousLandmark: 'Stonehenge',
      footballTeam: 'Swindon Town',
      nickname: 'The Moonraker County',
      flag:
          'The Great Bustard on this county\'s flag celebrates the bird that once roamed Salisbury Plain in great numbers before being hunted to extinction in Britain by the 1840s. The bustard has been the county\'s symbol since at least the 18th century, appearing in this county\'s regimental badges and arms — a reminder of the ancient chalk downland that defines the region.',
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
      flag:
          'This county\'s arms feature a classic example of canting heraldry: a gold ford (river crossing) with an ox, literally spelling out the county\'s name as a visual pun. This punning tradition in heraldry dates to the Norman period. The city\'s university — founded in the 12th century and among the oldest in the English-speaking world — made this particular river crossing one of the most intellectually significant in history.',
    ),
    'WAR': UkCountyClueData(
      country: 'England',
      famousPerson: 'William Shakespeare',
      famousLandmark: 'Warwick Castle',
      footballTeam: 'Coventry City',
      nickname: 'The Heart of England',
      flag:
          'This county\'s bear and ragged staff is one of England\'s most celebrated heraldic badges, belonging to the Earls of this county — among the most powerful magnates in medieval England. The chequered fess (horizontal band) derives from the arms of the de Newburgh family who held the earldom. The badge became so famous it entered common parlance as a synonym for the county itself.',
    ),
    'NTH': UkCountyClueData(
      country: 'England',
      famousPerson: 'Alan Moore',
      famousLandmark: 'Silverstone Circuit',
      footballTeam: 'Northampton Town',
      nickname: 'The Rose of the Shires',
      flag:
          'The red rose of this county is distinct from the red rose of Lancaster — it is an older heraldic charge associated with the county\'s Norman lords. This county sits at the geographic heart of England and was a royal county, with numerous hunting lodges and manor houses; the rose reflects its long association with courtly culture and nobility.',
    ),
    'LEI': UkCountyClueData(
      country: 'England',
      famousPerson: 'Gary Lineker',
      famousLandmark: 'Leicester Cathedral',
      footballTeam: 'Leicester City',
      nickname: 'The Foxes',
      flag:
          'This county\'s fox has been the county\'s symbol since at least the 19th century, celebrating its world-famous foxhunting tradition — the Quorn, Belvoir and Pytchley hunts made this county\'s countryside the spiritual home of the sport. The cinquefoil (five-petalled flower) comes from the arms of the de Quincy Earls of Winchester, who held great estates here.',
    ),
    'NOT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Lord Byron',
      famousLandmark: 'Sherwood Forest',
      footballTeam: 'Nottingham Forest, Notts County',
      nickname: 'Robin Hood Country',
      flag:
          'This county\'s green reflects the ancient forest of Sherwood, the royal hunting forest that covered a third of the county in the medieval period and gave rise to the legend of Robin Hood. The outlaw\'s silhouette on the flag is a modern addition that celebrates the county\'s most famous mythological figure, whose story of fighting Norman oppression resonates across centuries.',
    ),
    'DER': UkCountyClueData(
      country: 'England',
      famousPerson: 'Florence Nightingale',
      famousLandmark: 'Chatsworth House',
      footballTeam: 'Derby County',
      nickname: 'The Peak',
      flag:
          'This county\'s flag combines the Tudor rose — recalling the county\'s prominence during the Tudor era, when its lead mines enriched the Crown — with the blue cross derived from the arms of Robert de Ferrers, the powerful Norman earl who once ruled this region. The green represents the Peak District moorland, England\'s first national park.',
    ),
    'STS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Robbie Williams',
      famousLandmark: 'Alton Towers',
      footballTeam: 'Stoke City',
      nickname: 'The Potteries',
      flag:
          'The county knot is one of England\'s most distinctive heraldic badges, a three-looped knot of uncertain but ancient origin. It is first recorded in the 14th century and was used by the Stafford Dukes of Buckingham, who took their title and arms from the county. The knot became so embedded in county identity that it appears on civic heraldry, regimental badges and pub signs across the region.',
    ),
    'BKM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Roald Dahl',
      famousLandmark: 'Bletchley Park',
      footballTeam: 'Wycombe Wanderers',
      nickname: 'The Home of the Chilterns',
      flag:
          'The chained swan is the badge of the Bohun family, Earls of Hereford and Essex, who held great estates across this county. Through inheritance it passed to Henry IV and became a royal badge of the House of Lancaster. The swan — noble, white and restrained — perfectly captured the medieval ideal of controlled power; it became inseparable from this county\'s identity.',
    ),
    'HEF': UkCountyClueData(
      country: 'England',
      famousPerson: 'David Garrick',
      famousLandmark: 'Hereford Cathedral',
      footballTeam: 'Hereford FC',
      nickname: 'The Marches',
      flag:
          'This county\'s flag celebrates the famous local breed of cattle, whose red-and-white colouring has been selectively developed here since the 18th century and exported worldwide. The three gold lions derive from the arms of the de Lacy lords — Norman barons who built the castle here and controlled the Welsh Marches for the Crown.',
    ),
    'WOR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Edward Elgar',
      famousLandmark: 'Worcester Cathedral',
      footballTeam: 'Worcester City',
      nickname: 'The Faithful City County',
      flag:
          'The pear tree on this county\'s flag is a reference to the famous local pear — the county has been renowned for its perry (pear cider) and dessert pears since at least the 17th century. The wavy lines represent the River Severn, which bisects the county. The combination reflects a uniquely agrarian identity, rich orchards and the gentle landscape celebrated by Edward Elgar in his music.',
    ),
    'RUT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Titus Oates',
      famousLandmark: 'Rutland Water',
      footballTeam: 'Oakham United',
      nickname: 'England\'s Smallest County',
      flag:
          'The horseshoe is the ancient symbol of this county, England\'s smallest historic county. Local tradition holds it represents the county\'s importance as a centre of horse-breeding and royal hunting; it appears in civic arms for centuries. This county famously resisted abolition in the 1974 local government reorganisation and was restored as an independent county in 1997 — the horseshoe a fitting symbol of stubborn good fortune.',
    ),
    'SHR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Charles Darwin',
      famousLandmark: 'Ironbridge Gorge',
      footballTeam: 'Shrewsbury Town',
      nickname: 'Salop',
      flag:
          'This county\'s three white leopard faces (or lion faces passant) on blue and gold derive from the arms of the de Belmeis and later Fitz Alan lords who held the county. The Fitz Alans, Earls of Arundel, were among the most powerful Marcher lords guarding the Welsh border; their heraldry merged with local tradition to produce the distinctive blue-and-gold identity of this county.',
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
      flag:
          'The red rose of this county is the emblem of the House of Lancaster, the royal dynasty that produced Henry IV, V and VI. After the Wars of the Roses, the red rose became firmly associated with this county\'s fierce county pride. The gold field derives from the arms of the Duchy of Lancaster, which remains a personal possession of the Crown to this day.',
    ),
    // CHS renamed to CHE (Cheshire)
    'CHE': UkCountyClueData(
      country: 'England',
      famousPerson: 'Lewis Carroll',
      famousLandmark: 'Chester Cathedral',
      footballTeam: 'Chester FC',
      nickname: 'The County Palatine',
      flag:
          'The three golden wheatsheaves of this county derive from the arms of the ancient earldom here, one of England\'s most powerful palatine earldoms. The sword represents the county\'s status as a County Palatine — a jurisdiction where the Earl exercised powers equivalent to the King, including his own courts, mint and army. The earldom was merged with the Crown in 1254.',
    ),
    'DUR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Rowan Atkinson',
      famousLandmark: 'Durham Cathedral',
      footballTeam: 'Darlington FC',
      nickname: 'Land of the Prince Bishops',
      flag:
          'This county\'s flag honours the Prince Bishops who wielded royal power within the county palatine from the Norman Conquest until 1836. The gold cross on blue derives from the arms of the Bishopric — the lions represent the power vested in the bishops by the Crown to defend the northern frontier against Scottish invasion. The cathedral here, built to house St Cuthbert\'s relics, was the seat of this unique ecclesiastical state.',
    ),
    // CUM renamed to CMA (Cumbria)
    'CMA': UkCountyClueData(
      country: 'England',
      famousPerson: 'William Wordsworth',
      famousLandmark: 'Hadrian\'s Wall',
      footballTeam: 'Carlisle United',
      nickname: 'The Lake District',
      flag:
          'This county\'s flag combines elements from its constituent historic counties — Cumberland and Westmorland — which merged in 1974. The gold fleece reflects the county\'s ancient wool trade from Herdwick sheep, bred on the fells since Viking settlement. The colours of green, blue and gold represent the lake, fell and pastoral landscape that Wordsworth immortalised as the English sublime.',
    ),
    'NBL': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jackie Charlton',
      famousLandmark: 'Lindisfarne Castle',
      footballTeam: 'Newcastle United',
      nickname: 'The Far North',
      flag:
          'This county\'s arms draw on the ancient heraldry of the local earldom, one of the most turbulent titles in English history. The red and gold quartering echoes the Percy family arms — Earls of this county since the 14th century — whose power rivalled the Crown and whose rebellion against Henry IV inspired Shakespeare\'s Henry IV plays. The blue and white chequered canton derives from the ancient Kingdom of Northumbria.',
    ),
    'NYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'James Herriot',
      famousLandmark: 'Whitby Abbey',
      footballTeam: 'Harrogate Town, York City',
      nickname: 'God\'s Own County',
      flag:
          'This county carries the white rose of the House of York on blue — the same emblem shared across all Yorkshire ridings. As England\'s largest county, it encompasses the great medieval landscapes of the Yorkshire Dales and North York Moors, and the historic city of York itself, the former Roman capital of Britannia and seat of the Archbishop whose power historically rivalled Canterbury.',
    ),
    'ERY': UkCountyClueData(
      country: 'England',
      famousPerson: 'Amy Johnson',
      famousLandmark: 'The Humber Bridge',
      footballTeam: 'Hull City',
      nickname: 'The Wolds',
      flag:
          'This county carries the white rose of York, shared across all three Yorkshire ridings as a mark of common identity. The wavy band represents the Humber estuary — one of Britain\'s great river mouths — which made Kingston upon Hull a prosperous medieval port and the gateway through which Scandinavian culture and trade flowed into England.',
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
      flag:
          'This city\'s arms feature four symbols from the legend of St Mungo, the city\'s 6th-century patron saint: the tree he lit by breathing on a branch, the bird (robin) he restored to life, the bell he brought from Rome, and the fish with a ring in its mouth — recalling a queen\'s lost ring found inside a salmon. The rhyme "Here is the bird that never flew…" encodes all four symbols in the city\'s civic identity.',
    ),
    'EDH': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Graham Bell',
      famousLandmark: 'Edinburgh Castle',
      footballTeam: 'Hibernian, Hearts',
      nickname: 'Auld Reekie',
      flag:
          'This city\'s arms feature the castle, representing the volcanic crag fortress that has been occupied for over 3,000 years. The castle has been the seat of Scottish kings, a state prison and treasury housing the Honours of Scotland — the oldest crown jewels in the British Isles. The city became the capital of Scotland in the 15th century, cementing its identity as a seat of law, Church and government.',
    ),
    'FIF': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Adam Smith',
      famousLandmark: 'St Andrews Links',
      footballTeam: 'Dunfermline Athletic',
      nickname: 'The Kingdom of Fife',
      flag:
          'Known as a kingdom since at least the 12th century, this region carries the red lion rampant on gold, derived from the arms of the ancient MacDuff earldom. The MacDuffs held one of the seven earldoms of Scotland and had the sacred privilege of crowning the Scottish King at Scone. The chequered border echoes the tressure found on the Royal Standard of Scotland.',
    ),
    'HLD': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Flora MacDonald',
      famousLandmark: 'Loch Ness',
      footballTeam: 'Inverness Caledonian Thistle',
      nickname: 'The Highlands',
      flag:
          'This region uses the Saltire — the national flag of Scotland — the white diagonal cross on blue that represents St Andrew, Scotland\'s patron saint, who was martyred on a diagonal (X-shaped) cross at Patras in Greece. Legend holds that St Andrew\'s relics were brought to Scotland in the 4th century by a monk called Rule, and the sight of a white cross against a blue sky before battle confirmed the symbol as Scotland\'s own.',
    ),
    'ABD': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Annie Lennox',
      famousLandmark: 'Balmoral Castle',
      footballTeam: 'Aberdeen FC',
      nickname: 'The Granite City',
      flag:
          'This county\'s three silver towers on blue derive from the ancient arms of the region, representing the great castles that once controlled the Grampian routes. The county was home to more castles per square mile than almost anywhere in Europe, reflecting its importance as a buffer zone between the Lowland kingdoms and the Highland clans. Balmoral, the royal residence chosen by Queen Victoria, lies here.',
    ),
    'ABE': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Denis Law',
      famousLandmark: 'Marischal College',
      footballTeam: 'Aberdeen FC',
      nickname: 'The Silver City',
      flag:
          'This city\'s arms reflect its medieval importance as a royal burgh and trading hub. The three silver towers represent the city\'s fortifications and its status as a place of strength at the mouth of the River Dee. The leopards (derived from Scottish royal heraldry) acknowledge this city\'s close ties to the Scottish Crown, which granted the city its first royal charter.',
    ),
    'AYR': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Burns',
      famousLandmark: 'Burns Cottage',
      footballTeam: 'Ayr United, Kilmarnock',
      nickname: 'Burns Country',
      flag:
          'The heart on this county\'s flag is the Bleeding Heart of Douglas — emblem of the powerful Black Douglas family, who were the dominant lords of this region in the 14th and 15th centuries. The Good Sir James Douglas carried the embalmed heart of Robert the Bruce on crusade in 1330, and the heart symbol has defined Douglas heraldry ever since, passing into the wider identity of this county.',
    ),
    'DGY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert the Bruce',
      famousLandmark: 'Sweetheart Abbey',
      footballTeam: 'Queen of the South',
      nickname: 'The Galloway Hills',
      flag:
          'The white lion rampant of this region represents the ancient local lords, a semi-independent Celtic lordship that resisted both Scottish and English overlordship for centuries. The white lion on blue is one of the most ancient heraldic symbols in Scotland, pre-dating many royal arms and embodying the region\'s fiercely independent Celtic and Gaelic heritage.',
    ),
    // STI renamed to STG (Stirling)
    'STG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Wallace',
      famousLandmark: 'Stirling Castle',
      footballTeam: 'Stirling Albion',
      nickname: 'The Gateway to the Highlands',
      flag:
          'This county\'s wolf on gold derives from the burgh\'s ancient arms, symbolising the ferocity needed to hold this strategic fortress — "the key to Scotland." Whoever held this town controlled movement between the Highlands and Lowlands. The castle here was the birthplace of James II and Mary Queen of Scots, and the town witnessed two of Scotland\'s most decisive battles: the Bridge (1297) and Bannockburn (1314).',
    ),
    'ANS': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Don Coutts',
      famousLandmark: 'Glamis Castle',
      footballTeam: 'Arbroath FC, Forfar Athletic',
      nickname: 'The Land o\' the Angus Glens',
      flag:
          'The white lion passant (walking) of this county derives from the arms of the ancient earldom, one of the seven great earldoms of Scotland. Glamis Castle, within this county, was the childhood home of Queen Elizabeth The Queen Mother and the legendary setting of Macbeth. The lion passant distinguishes this county\'s arms from the rampant lion of Scotland, reflecting the earldom\'s subordinate but prestigious status.',
    ),
    'ARG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Neil Munro',
      famousLandmark: 'Inveraray Castle',
      footballTeam: 'Oban Saints',
      nickname: 'The Gateway to the Isles',
      flag:
          'The lymphad (a single-masted Highland galley) is the heraldic emblem of Clan Campbell, one of the most powerful families in Scottish history, who were Dukes of this region. Their control of this county\'s sea-lanes and island chains gave them dominance over western Scotland for centuries. The galley itself symbolises the Gaelic-Norse seafaring culture that shaped the Hebridean and west coast identity for a thousand years.',
    ),
    'CLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Bruce',
      famousLandmark: 'Alloa Tower',
      footballTeam: 'Alloa Athletic',
      nickname: 'The Wee County',
      flag:
          'This county\'s oak tree on gold derives from an ancient legend: the stone and mannan (a Pictish word possibly meaning "rock" or relating to a local deity) gave the county its name, and the oak has been its symbol since heraldic records begin. The black saltire reflects the county\'s identity within the Scottish kingdom. As Scotland\'s smallest county it punches above its weight in historical associations with the Wars of Independence.',
    ),
    'DND': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Mary Shelley (lived here)',
      famousLandmark: 'RRS Discovery',
      footballTeam: 'Dundee FC, Dundee United',
      nickname: 'The City of Discovery',
      flag:
          'This city\'s pot of lilies is a symbol of the Virgin Mary, reflecting the medieval city\'s dedication to Our Lady — the founding charter was associated with the Church. The city became famous for its three Js: jute, jam and journalism, making it a vital Victorian industrial port. The RRS Discovery, the ship that carried Scott to the Antarctic, was built and launched here.',
    ),
    'EDU': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Tom Conti',
      famousLandmark: 'Mugdock Castle',
      footballTeam: 'Kirkintilloch Rob Roy',
      nickname: 'The Bears Den',
      flag:
          'This county\'s bear derives from the heraldry of the ancient earldom of Lennox, whose lords held this territory for centuries before the Reformation. The bear was a symbol of strength and protection; the wavy band represents the River Kelvin flowing through the area. The Lennox earldom was one of Scotland\'s most prestigious titles, and its arms shaped the heraldry of communities throughout the Clyde valley.',
    ),
    'EIL': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Angus MacPhee',
      famousLandmark: 'Callanish Standing Stones',
      footballTeam: 'Stornoway United',
      nickname: 'The Western Isles',
      flag:
          'This region\'s flag combines the Norse longship — reflecting the Viking kingdom of the Isles (Suðreyjar) that controlled the Hebrides from the 9th to 13th centuries — with the herring, the silver harvest that sustained island communities for generations. These islands were finally ceded by Norway to Scotland only in 1266, and Norse language and place names still echo across the islands.',
    ),
    'ELN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'John Muir',
      famousLandmark: 'Tantallon Castle',
      footballTeam: 'Dunbar United',
      nickname: 'Scotland\'s Golf Coast',
      flag:
          'This county\'s white goat derives from the county\'s ancient arms, representing the hardy livestock that have grazed these fertile coastal farmlands since antiquity. The county was historically one of the most productive in Scotland — the breadbasket of Edinburgh. Haddington, the county town, was a royal burgh and birthplace of John Knox, founder of the Scottish Reformation.',
    ),
    'ERW': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'David Dale',
      famousLandmark: 'Rouken Glen Park',
      footballTeam: 'Arthurlie FC',
      nickname: 'The Ren',
      flag:
          'This county\'s thistle — the national emblem of Scotland — represents the county\'s Scottish identity, while the chevron derives from older local heraldry associated with the Stewart family. Walter FitzAlan, ancestor of the Royal House of Stewart, held estates here, making this ground the ancestral home of the dynasty that would rule Scotland for three centuries.',
    ),
    'FAL': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Rankine',
      famousLandmark: 'The Kelpies',
      footballTeam: 'Falkirk FC',
      nickname: 'The Bairns\' Town',
      flag:
          'This area\'s stag represents the ancient burgh\'s arms, symbolising the great Caledonian Forest and the hunting grounds of Scottish kings in this central belt region. The Forth bridge references the county\'s role as the crossing point between the Lowlands and the North. The main town was the site of two significant battles — in 1298 (Wallace\'s defeat by Edward I) and 1746 (the last Jacobite victory on Scottish soil).',
    ),
    'INV': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Mary Barbour',
      famousLandmark: 'Newark Castle',
      footballTeam: 'Greenock Morton',
      nickname: 'The Tail of the Bank',
      flag:
          'This county\'s herring and sailing ship reflect its principal town\'s history as one of Scotland\'s most important maritime ports. The silver herring represents the fishing trade that sustained the town before the industrial era, while the sailing ship recalls the sugar and rum trade with the Caribbean — and the town\'s role as a departure point for generations of Scottish emigrants seeking new lives abroad.',
    ),
    'MLN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Dolly the Sheep (Roslin Institute)',
      famousLandmark: 'Rosslyn Chapel',
      footballTeam: 'Bonnyrigg Rose Athletic',
      nickname: 'The Heart of Midlothian',
      flag:
          'This county\'s castle and stars derive from the arms associated with Edinburgh\'s hinterland — the county that surrounds the capital. The castle references Edinburgh Castle itself, which defined the region\'s destiny. The nickname "Heart of" this county — immortalised by Sir Walter Scott — refers to the old Edinburgh Tolbooth prison that once stood at the heart of the county\'s civic life.',
    ),
    'MRY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Ramsay MacDonald',
      famousLandmark: 'Elgin Cathedral',
      footballTeam: 'Elgin City',
      nickname: 'The Malt Whisky Country',
      flag:
          'This county\'s castle and stars reflect the ancient Celtic province here — one of the most powerful in early Scotland — whose lords periodically challenged the kings of Scots for supremacy. The star symbols echo the Pictish stone carvings found throughout the region. The area is now most famous as the whisky-producing heartland of Scotland, home to the greatest concentration of malt whisky distilleries in the world.',
    ),
    'NAY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Fleming',
      famousLandmark: 'Brodick Castle',
      footballTeam: 'Kilwinning Rangers',
      nickname: 'The Ayrshire Coast',
      flag:
          'This county\'s saltire and heart combine two heraldic traditions: the saltire from the arms of the old County of Ayr, connecting to St Andrew\'s cross, and the heart from the Douglas family, who dominated this coastline. The Isle of Arran, within the county, was a prehistoric and Viking stronghold, and Brodick Castle was long a seat of the Dukes of Hamilton — the premier Scottish peerage.',
    ),
    'NLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Baird',
      famousLandmark: 'Summerlee Museum of Scottish Industrial Life',
      footballTeam: 'Motherwell FC, Airdrieonians',
      nickname: 'The Lanarkshire Heartland',
      flag:
          'The double-headed eagle of this county derives from the arms of the Hamilton family, Dukes of Hamilton — the premier Scottish peerage and at one point possible heirs to the Scottish throne. The double-headed eagle was one of the most powerful symbols in European heraldry, borrowed from the Holy Roman Empire, and its use by the Hamiltons reflects their extraordinary status in Scottish society.',
    ),
    'ORK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'George Mackay Brown',
      famousLandmark: 'Skara Brae',
      footballTeam: 'Orkney FC',
      nickname: 'The Northern Isles',
      flag:
          'This county\'s Nordic cross in red and gold on blue directly references its Norse heritage — the islands were part of the Kingdom of Norway until pledged to Scotland in 1468 as dowry for Margaret of Denmark, and never redeemed. The Norn language, a Norse dialect, was spoken here until the 18th century. The cross design follows Scandinavian flag tradition, connecting this island group to its Norse identity more emphatically than any other Scottish council.',
    ),
    'PKN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'John Buchan',
      famousLandmark: 'Scone Palace',
      footballTeam: 'St Johnstone',
      nickname: 'The Big County',
      flag:
          'This county\'s red eagle on gold derives from the arms of the ancient earldom of Strathearn, whose lords were among the most powerful in medieval Scotland. Scone, just north of the county town, was the coronation site of Scottish kings for centuries — the Stone of Destiny was kept here until Edward I removed it to Westminster in 1296. The county town served as the effective capital of Scotland for much of the medieval period.',
    ),
    'RFW': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Gerry Rafferty',
      famousLandmark: 'Paisley Abbey',
      footballTeam: 'St Mirren',
      nickname: 'The Buddies\' Land',
      flag:
          'This county\'s flag features the mitre of Paisley Abbey — one of Scotland\'s most important medieval monasteries, founded in 1163 by Walter FitzAlan, ancestor of the Royal House of Stewart. The chequered band derives from the Stewart heraldry, acknowledging that this county was the ancestral cradle of the dynasty that went on to rule Scotland, and later through James VI, all of Britain.',
    ),
    'SAY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Burns (Alloway)',
      famousLandmark: 'Culzean Castle',
      footballTeam: 'Ayr United',
      nickname: 'The Burns Coast',
      flag:
          'This county\'s saltire and castle draw on the arms of the burgh of Ayr — one of Scotland\'s most important medieval trading ports, granted its royal charter in 1205. The saltire connects the county to the national symbol of St Andrew, while the castle represents Ayr\'s royal fortification. The county contains Culzean Castle, gifted to General Eisenhower by the Scottish people after World War II.',
    ),
    'SCB': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Walter Scott',
      famousLandmark: 'Abbotsford House',
      footballTeam: 'Gala Fairydean Rovers',
      nickname: 'Scott\'s Country',
      flag:
          'This region\'s flag reflects its contested history as a battleground between Scotland and England for centuries. The tower represents the characteristic peel towers built throughout the region as refuges against the raids of Border Reivers — the lawless clans who terrorised both sides of the frontier from the 13th to 17th centuries. The gold saltire acknowledges the region\'s Scottish identity.',
    ),
    'SLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Sir Harry Lauder',
      famousLandmark: 'New Lanark',
      footballTeam: 'Hamilton Academical',
      nickname: 'The Clyde Valley',
      flag:
          'This county\'s double-headed eagle and cinquefoils combine two great heraldic traditions of the region. The eagle comes from the arms of the Hamilton family — Dukes of Hamilton and once heirs presumptive to the Scottish throne — while the cinquefoils (five-petalled flowers) represent the Fraser family, another powerful local dynasty. New Lanark, within the county, was Robert Owen\'s pioneering model community and a founding site of the cooperative movement.',
    ),
    'WDU': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Tobias Smollett',
      famousLandmark: 'Dumbarton Castle',
      footballTeam: 'Dumbarton FC',
      nickname: 'The Rock',
      flag:
          'This county\'s elephant and castle is a surprising heraldic device for a Scottish county, but derives from the arms of the principal burgh here. The elephant represents exotic strength and rarity, a symbol often used in heraldry to indicate the exotic trade connections of a port town. The great rock — one of the oldest continuously occupied strongholds in Britain — was the capital of the ancient Kingdom of Strathclyde.',
    ),
    'WLN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Dougray Scott',
      famousLandmark: 'Linlithgow Palace',
      footballTeam: 'Livingston FC',
      nickname: 'The Shale Oil County',
      flag:
          'This county\'s black dog on gold derives from the arms of Linlithgow burgh, where the dog (a greyhound or similar) was associated with royal hunting and the adjacent royal palace. Linlithgow Palace was the birthplace of Mary Queen of Scots in 1542 and a favourite residence of the Scottish kings. The region was also the centre of Scotland\'s 19th-century shale oil industry, pioneered by James Young.',
    ),
    'ZET': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Arthur Anderson',
      famousLandmark: 'Jarlshof',
      footballTeam: 'Shetland FC',
      nickname: 'The Old Rock',
      flag:
          'This county\'s white Nordic cross on blue directly proclaims its Norse identity — the islands were part of the Kingdom of Norway until 1468, when they were pledged to Scotland as security for a dowry that was never paid. The Norn language survived here longer than anywhere else in Britain. More than any Scottish council area, this island group looks to Scandinavia rather than the Scottish mainland for its cultural identity.',
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
      flag:
          'This city\'s flag carries Y Ddraig Goch — the Red Dragon of Wales — one of the oldest national symbols in Europe. The red dragon appears in the Historia Brittonum (9th century) as the emblem of the Britons battling the white dragon of the Saxons. Henry VII, of Welsh Tudor descent, used the dragon at the Battle of Bosworth in 1485, cementing its status as the symbol of Wales and Welsh nationhood.',
    ),
    'SWA': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Catherine Zeta-Jones',
      famousLandmark: 'Swansea Bay',
      footballTeam: 'Swansea City',
      nickname: 'The Copperopolis',
      flag:
          'This city\'s flag combines the castle from its Norman fortification — one of the first Norman castles in Wales — with the black swan that gives the city its English name (derived from "Sweyn\'s ey," a Norse-origin name). The red and gold colours derive from the arms of the ancient Welsh kingdom of Deheubarth, whose princes ruled southwest Wales before the Norman conquest.',
    ),
    'GWN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Lloyd George',
      famousLandmark: 'Snowdon (Yr Wyddfa)',
      footballTeam: 'Bangor City',
      nickname: 'Land of Castles',
      flag:
          'This county\'s eagles derive from the arms of the Princes of this region — the most powerful Welsh dynasty, who resisted English domination longest. The eagle was associated with Llywelyn ap Gruffudd, "The Last Prince," who was killed in 1282, ending the independent Principality of Wales. The lions come from the arms of Owain, the 12th-century prince who united Wales.',
    ),
    'PEM': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Griff Rhys Jones',
      famousLandmark: 'Pembroke Castle',
      footballTeam: 'Haverfordwest County',
      nickname: 'Little England Beyond Wales',
      flag:
          'This county\'s gold lions on blue derive from the arms of the ancient Kingdom of Deheubarth, the most powerful Welsh kingdom of southwest Wales. The great castle here was the birthplace of Henry VII, founder of the Tudor dynasty. The county is nicknamed "Little England Beyond Wales" because Norman and Flemish settlers colonised it so thoroughly in the 12th century that its language and culture remained English long after the surrounding areas returned to Welsh.',
    ),
    // PWS renamed to POW (Powys)
    'POW': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Laura Ashley',
      famousLandmark: 'Powis Castle',
      footballTeam: 'Newtown AFC',
      nickname: 'The Green Desert of Wales',
      flag:
          'This county\'s gold lion rampant on red derives from the arms of the ancient kingdoms of central Wales, whose northern division gave rise to the modern county boundaries. The region traces its lineage to the sub-Roman princes who ruled central Wales after the Roman withdrawal. The county\'s remoteness and sparse population — the "Green Desert" — allowed its Celtic Welsh culture and language to survive intact.',
    ),
    // CRD renamed to CAY (Caerphilly)
    'CAY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Caerphilly Castle',
      footballTeam: 'Cardiff Metropolitan',
      nickname: 'The Valleys',
      flag:
          'This county\'s flag combines the Welsh red dragon — the ancient symbol of the Britons — with a red chevron referencing the great Norman castle here, one of the largest castles in Britain, built by Gilbert de Clare in 1268 specifically to contain the growing power of Llywelyn ap Gruffudd, the last native Prince of Wales. The tension between these symbols captures the contested Welsh-Norman history of the valleys.',
    ),
    'NWP': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Mark Williams',
      famousLandmark: 'Newport Transporter Bridge',
      footballTeam: 'Newport County',
      nickname: 'The Gateway to Wales',
      flag:
          'This city\'s chevron and three towers derive from the town\'s Norman castle and its role as a major crossing point of the River Usk. The chevron references the Clare family arms — Earls of Gloucester who controlled this strategic borderland after the Norman Conquest. The town became a major coal and iron export port in the 19th century, and was the scene of the Chartist Uprising of 1839 — the last armed rebellion on British soil.',
    ),
    'RCT': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Rhondda Heritage Park',
      footballTeam: 'Pontypridd Town',
      nickname: 'The Rhondda Valleys',
      flag:
          'This county\'s black and gold colours represent coal and gold — the valley\'s defining resources. Black reflects the coal seams that made this region one of the most productive coalfields in the world, while gold represents the wealth and aspiration of its communities. The Welsh dragon asserts the region\'s cultural identity, preserved through choirs, chapels and the Welsh language even as coal defined its economic destiny.',
    ),
    'FLN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Jonathan Davies',
      famousLandmark: 'Flint Castle',
      footballTeam: 'Connah\'s Quay Nomads',
      nickname: 'The Borderlands',
      flag:
          'This county\'s lion rampant and castle reflect its position as a March (border) county, fought over by Welsh princes and English kings for centuries. The local castle was the first of Edward I\'s iron ring of castles built to subjugate Wales, constructed in 1277. It was here, in 1399, that Richard II surrendered to Henry Bolingbroke — an event that changed the English succession and inspired Shakespeare.',
    ),
    'WRX': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Elihu Yale',
      famousLandmark: 'Wrexham Parish Church',
      footballTeam: 'Wrexham AFC',
      nickname: 'The Gateway to Wales',
      flag:
          'This county\'s cross and lion combine the traditions of the Welsh Marches with the heraldry of the ancient Kingdom of Powys. The town grew around its parish church — St Giles, one of the finest in Wales — and developed as a coal and steel centre. The lion echoes the Powys royal arms, asserting Welsh identity in a borderland that was historically more English in population and culture.',
    ),
    'CMN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Hedd Wyn',
      famousLandmark: 'National Botanic Garden of Wales',
      footballTeam: 'Carmarthen Town',
      nickname: 'The Garden of Wales',
      flag:
          'This county\'s quartered blue and gold field with lions and towers derives from the arms of the ancient Welsh kingdom of Deheubarth and the later Norman lords who controlled the county town. The county town itself claims to be the oldest town in Wales, with Roman origins, and is traditionally associated with the wizard Merlin — legend holds the town will flood when a certain oak tree falls.',
    ),
    'CRG': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Augustus John',
      famousLandmark: 'Devil\'s Bridge',
      footballTeam: 'Aberystwyth Town',
      nickname: 'The Celtic Heartland',
      flag:
          'This county\'s dolphins and lion are drawn from the county\'s arms reflecting its coastal identity on Cardigan Bay — home to one of the most important populations of bottlenose dolphins in Britain. The red lion derives from the arms of the Kingdom of Deheubarth, whose heartland was here. The county is considered one of the most Welsh of all Welsh counties in language and culture, with over half the population speaking Welsh.',
    ),
    'AGY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Anglesey Druid heritage',
      famousLandmark: 'Beaumaris Castle',
      footballTeam: 'Holyhead Hotspur',
      nickname: 'Mother of Wales',
      flag:
          'This island county\'s coronet and lions reflect its title as "Mam Cymru" — Mother of Wales — the fertile island that fed mainland Wales through centuries of conflict. The coronet acknowledges the island\'s royal connections as the final stronghold of the Princes of Gwynedd; the Romans called it Mona and targeted it to destroy the druidic religion that centred on its sacred groves, massacring the druids there in 60 AD.',
    ),
    'BGE': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Gareth Thomas',
      famousLandmark: 'Porthcawl Lighthouse',
      footballTeam: 'Bridgend Town',
      nickname: 'Gateway to the Valleys',
      flag:
          'This county\'s castle and bridge are literal representations of the town\'s name — Pen-y-bont ar Ogwr in Welsh, meaning "the head of the bridge on the Ogmore." The castle refers to Newcastle, the Norman fortification built to control the river crossing. The blue field derives from the heraldic tradition of the county borough, representing the rivers that flow through this industrial and agricultural borderland between the coalfield valleys and the Glamorgan coast.',
    ),
    'BGW': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Aneurin Bevan',
      famousLandmark: 'Big Pit National Coal Museum',
      footballTeam: 'Ebbw Vale',
      nickname: 'Valleys Gateway',
      flag:
          'This county\'s green and white colours represent the landscape of the South Wales valleys before and after industrialisation. The mining symbol honours the iron and coal industries that once defined this region — Ebbw Vale was home to one of the largest steelworks in Britain. The county is named after Aneurin Bevan\'s parliamentary constituency; Bevan, born in Tredegar nearby, created the NHS in 1948 — one of the most significant social achievements of the 20th century.',
    ),
    'CWY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Bryn Terfel',
      famousLandmark: 'Conwy Castle',
      footballTeam: 'Conwy Borough',
      nickname: 'Land of Castles',
      flag:
          'This county\'s red eagle on gold derives from the arms of the ancient Welsh princes and the powerful de Lacey family who held the region after the Norman conquest. The great castle here, built by Edward I between 1283 and 1289, is one of the finest examples of medieval military architecture in Europe. The county takes its name from the river that forms its boundary — the ancient dividing line between the kingdoms of Gwynedd and Gwynedd\'s eastern neighbours.',
    ),
    'DEN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Beatrix Potter (holidayed)',
      famousLandmark: 'Denbigh Castle',
      footballTeam: 'Rhyl',
      nickname: 'Heart of the Vale',
      flag:
          'This county\'s red and gold stripes with a black lion derive from the arms of the ancient local lordship, granted to Henry de Lacy, Earl of Lincoln, after Edward I\'s conquest of Wales in 1282. The black lion was a de Lacy heraldic charge. This borderland county was historically a contested zone between English lordships and the residual power of the Welsh gentry who clung to their language and traditions.',
    ),
    'MON': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Henry V',
      famousLandmark: 'Tintern Abbey',
      footballTeam: 'Monmouth Town',
      nickname: 'Gateway to Wales',
      flag:
          'This county\'s three chevrons on gold derive from the arms of the Clare family — Earls of Gloucester and Hertford — who controlled the county from their headquarters at Chepstow Castle after the Norman conquest. The chevron (roof-like shape) is one of the most ancient heraldic charges. This county\'s ambiguous status between England and Wales — it was legally treated as English from Henry VIII until 1974 — is embodied in its Norman-English heraldry sitting on the Welsh border.',
    ),
    'MTY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Laura Ashley',
      famousLandmark: 'Cyfarthfa Castle',
      footballTeam: 'Merthyr Town',
      nickname: 'Iron Capital of the World',
      flag:
          'This county\'s crown on red acknowledges the town\'s extraordinary industrial importance — the town was the largest iron-producing centre in the world in the early 19th century, making it briefly the most important industrial town on earth. The crown is a symbol of this civic pride and the Welsh royal heritage associated with the name Tydfil, a 5th-century Celtic saint who was martyred here and around whom the settlement grew.',
    ),
    'NPT': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Richard Burton',
      famousLandmark: 'Gnoll Estate Country Park',
      footballTeam: 'Port Talbot Town',
      nickname: 'Steel Town',
      flag:
          'This county\'s blue and gold colours derive from the heraldic traditions of the principal borough here (Castell-nedd) and reference the industrial heritage of the Swansea Bay hinterland. The area was the global centre of copper smelting in the 18th and 19th centuries, and later steel. The industrial symbols honour a community shaped by metal working from the Roman occupation — when the town had a Roman fort — to the age of heavy industry.',
    ),
    'TOF': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Terry Matthews',
      famousLandmark: 'Blaenavon Ironworks',
      footballTeam: 'Cwmbran Celtic',
      nickname: 'Land of the Torrent',
      flag:
          'This county\'s torch on green represents enlightenment and the industrial knowledge that transformed this valley — Blaenavon, within this county, was a UNESCO World Heritage Site for its remarkably preserved ironworks and mining landscape. The green reflects the natural environment of the Afon Lwyd valley reclaimed after the industrial era. The county name means "stone gap" in Welsh, referencing the dramatic valley geology.',
    ),
    'VGL': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Roald Dahl (raised in Penarth)',
      famousLandmark: 'Dunraven Bay',
      footballTeam: 'Barry Town United',
      nickname: 'Garden of Wales',
      flag:
          'Vale of Glamorgan\'s green and gold with a rose reflects the county\'s identity as the fertile "Garden of Glamorgan" — the most productive agricultural land in Wales, contrasting sharply with the coal valleys to its north. The rose is a symbol of the pastoral beauty and gentle landscape of the Vale, while the gold references the rich farmland that has been continuously cultivated since prehistoric times.',
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
      flag:
          'County Antrim\'s flag features the Red Hand of Ulster — one of Ireland\'s most ancient heraldic symbols, associated with the O\'Neill dynasty and the ancient kingdom of Ulster. Legend holds the hand was severed by a king who threw it ashore to win a boat race. The castle derives from the arms of the O\'Neill lords who controlled northeast Ireland, and references the fortifications built to defend this coastline against Viking and Scottish raids.',
    ),
    'ARM': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'George Best',
      famousLandmark: 'Armagh Cathedral',
      footballTeam: 'Armagh City FC',
      nickname: 'The Orchard County',
      flag:
          'Armagh\'s flag bears the Red Hand of Ulster on a gold shield — the emblem of the ancient Kingdom of Ulster and its ruling O\'Neill dynasty. Armagh is considered the ecclesiastical capital of Ireland: St Patrick founded his church here in 445 AD, and both the Roman Catholic and Church of Ireland primates have their cathedrals in this small city, making it Ireland\'s most sacred ground.',
    ),
    'DOW': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Patrick Bronte',
      famousLandmark: 'Mourne Mountains',
      footballTeam: 'Glenavon FC',
      nickname: 'The Mournes',
      flag:
          'County Down\'s ship and fish reflect its maritime identity along the Irish Sea coast and Strangford Lough. The ship references Down\'s importance as a landing point from Scotland and Britain, while the fish represent the rich waters of Strangford Lough — one of Ireland\'s most important marine habitats. St Patrick is traditionally held to have landed in County Down and to be buried at Downpatrick Cathedral.',
    ),
    'FER': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Samuel Beckett',
      famousLandmark: 'Enniskillen Castle',
      footballTeam: 'Enniskillen Town',
      nickname: 'The Lakeland County',
      flag:
          'This county\'s flag combines the Red Hand of Ulster — symbol of the ancient O\'Neill and Ulster kingdoms — with a silver cross acknowledging the county\'s deep Christian heritage. This county\'s lake-studded landscape (the "Lakeland County") was home to important early Christian monasteries, most notably on the island of Devenish in Lough Erne, where a perfectly preserved 12th-century round tower still stands.',
    ),
    'LDY': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Seamus Heaney',
      famousLandmark: 'Derry City Walls',
      footballTeam: 'Derry City FC',
      nickname: 'The Maiden City',
      flag:
          'Derry\'s flag features a castle with a skeleton in the tower — a uniquely macabre heraldic device based on the city\'s coat of arms. The skeleton represents a figure from the city\'s founding legend associated with the O\'Cahans, who possessed the land before the Plantation of Ulster. The red cross on white connects to the English St George\'s Cross, acknowledging the Plantation settlers who built the city\'s famous walls in 1613–1619.',
    ),
    'TYR': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Brian Friel',
      famousLandmark: 'Sperrin Mountains',
      footballTeam: 'Dungannon Swifts',
      nickname: 'O\'Neill Country',
      flag:
          'Tyrone — O\'Neill Country — carries the Red Hand of Ulster on gold, directly from the arms of the O\'Neill dynasty, the most powerful Gaelic Irish family in Ulster. The O\'Neills were High Kings of Ulster for centuries and the leading figures in the Nine Years\' War (1593–1603) — the last great Gaelic Irish resistance to English conquest. Hugh O\'Neill, the Great O\'Neill, almost drove the English from Ireland before his defeat at Kinsale in 1601.',
    ),
  };
}
