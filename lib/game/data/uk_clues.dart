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
          'The flag of the City of London bears the cross of St George, patron saint of England, with the sword of St Paul in the upper hoist — a tribute to the city\'s patron saint and the apostle martyred by beheading, whose symbol has appeared on London\'s arms since the medieval period.',
    ),
    'WMD': UkCountyClueData(
      country: 'England',
      famousPerson: 'Ozzy Osbourne',
      famousLandmark: 'Birmingham Cathedral',
      footballTeam: 'Aston Villa, Birmingham City',
      nickname: 'The Black Country',
      flag:
          'The black and gold colours of the West Midlands flag reflect the identity of the Black Country — a region named for its coal-black skies during the Industrial Revolution. The diagonal cross echoes the heraldic traditions of the Mercian kingdom that once ruled this heartland of England.',
    ),
    'GTM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Noel Gallagher',
      famousLandmark: 'Old Trafford Stadium',
      footballTeam: 'Manchester United, Manchester City',
      nickname: 'Cottonopolis',
      flag:
          'Greater Manchester\'s flag draws on the arms of Manchester city, where the gold ship symbolises the Manchester Ship Canal — once the lifeline of the cotton trade that made the city the world\'s first industrial metropolis. The three gold stripes represent the rivers Irwell, Medlock and Irk that shaped the city\'s growth.',
    ),
    'WYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Patrick Stewart',
      famousLandmark: 'Leeds Town Hall',
      footballTeam: 'Leeds United',
      nickname: 'God\'s Own County',
      flag:
          'The white rose on blue is the emblem of the House of York, one of the two rival dynasties of the Wars of the Roses. The white rose has symbolised Yorkshire since at least the 15th century and represents the county\'s fierce pride in its identity — the most populous county in England.',
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
          'South Yorkshire\'s flag combines the white rose of the House of York with the green of the county\'s rural landscape — acknowledging that even this industrial heartland, home to the steel and cutlery trades, is rooted in the broader Yorkshire identity forged over centuries of shared history.',
    ),
    'TWR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sting',
      famousLandmark: 'Angel of the North',
      footballTeam: 'Newcastle United, Sunderland AFC',
      nickname: 'The Geordies',
      flag:
          'Tyne and Wear\'s arms draw on the heraldry of Newcastle and Sunderland. The castle references Newcastle\'s Norman fortification — the "new castle" built by Robert Curthose, son of William the Conqueror, in 1080. The lion echoes the arms of the powerful Percy family, Earls of Northumberland, who dominated the region for centuries.',
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
          'The white horse of Kent (the Invicta horse) is one of England\'s oldest county symbols, appearing in arms since at least the 14th century. It likely derives from the Saxon kingdom of Kent, whose legendary founders Hengist and Horsa bore horse names, and whose battle standard was said to carry this symbol when they first conquered the land.',
    ),
    'ESS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jamie Oliver',
      famousLandmark: 'Colchester Castle',
      footballTeam: 'Colchester United',
      nickname: 'The Saxon Shore',
      flag:
          'Essex takes its name from the East Saxons, and its three seaxes (curved Saxon swords) are among the oldest heraldic emblems in England. The seax was the signature weapon of the Saxon people; these blades represent the three divisions of the ancient kingdom of Essex — a symbol carried since the medieval roll of arms.',
    ),
    'HAM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jane Austen',
      famousLandmark: 'Winchester Cathedral',
      footballTeam: 'Southampton FC, Portsmouth FC',
      nickname: 'Hants',
      flag:
          'Hampshire\'s flag features the Tudor rose, the dynastic emblem created by Henry VII to unite the white rose of York and red rose of Lancaster after the Wars of the Roses. Winchester, Hampshire\'s county town, was the ancient capital of England and seat of the Anglo-Saxon kings — hence the regal crown acknowledging its historic primacy.',
    ),
    'SRY': UkCountyClueData(
      country: 'England',
      famousPerson: 'Eric Clapton',
      famousLandmark: 'Hampton Court Palace',
      footballTeam: 'Crystal Palace',
      nickname: 'The Home Counties',
      flag:
          'Surrey\'s gold and red chequered arms derive directly from the heraldry of the de Warenne family, Earls of Surrey — powerful Norman lords who held the county from the Conquest. The chequy pattern was their dynastic emblem, and by inheritance it became the county\'s enduring symbol after the earldom passed to the Crown.',
    ),
    'HRT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Hawking',
      famousLandmark: 'St Albans Cathedral',
      footballTeam: 'Watford FC',
      nickname: 'Herts',
      flag:
          'Hertfordshire\'s symbol is the hart (a male deer), a visual pun on the county\'s name — a form of canting heraldry, where the charge sounds like the name it represents. The county was named for Hertford ("hart ford"), the river crossing used by deer. The stag has appeared in the county arms since at least the 16th century.',
    ),
    // SUS renamed to SSX (East Sussex)
    'SSX': UkCountyClueData(
      country: 'England',
      famousPerson: 'Virginia Woolf',
      famousLandmark: 'Brighton Pier',
      footballTeam: 'Brighton & Hove Albion',
      nickname: 'The Downs',
      flag:
          'The six golden martlets (a legless heraldic bird derived from the swift) on blue are the ancient arms of the Kingdom of Sussex, one of the original Anglo-Saxon heptarchy kingdoms. The martlet appears on the coats of arms of many Sussex families and towns, symbolising the county\'s Saxon heritage and its identity as a distinct historic nation.',
    ),
    'BRK': UkCountyClueData(
      country: 'England',
      famousPerson: 'Kate Middleton',
      famousLandmark: 'Windsor Castle',
      footballTeam: 'Reading FC',
      nickname: 'Royal County',
      flag:
          'Berkshire\'s flag features the white stag, a symbol associated with the royal forests of the county and Windsor Great Park, where kings hunted for centuries. The oak alludes to these ancient royal hunting grounds. Windsor Castle, the oldest occupied castle in the world, has stood here since William the Conqueror and given the county its "Royal" designation.',
    ),
    'WSX': UkCountyClueData(
      country: 'England',
      famousPerson: 'Percy Bysshe Shelley',
      famousLandmark: 'Arundel Castle',
      footballTeam: 'Crawley Town',
      nickname: 'The South Downs',
      flag:
          'West Sussex shares the six golden martlets of the ancient Kingdom of Sussex with its eastern neighbour, a common Saxon heritage predating the modern administrative split. The crown distinguishes West Sussex and honours Arundel Castle, ancestral seat of the Dukes of Norfolk — the highest-ranking dukedom in England and the foremost Catholic noble family.',
    ),
    'IOW': UkCountyClueData(
      country: 'England',
      famousPerson: 'Queen Victoria',
      famousLandmark: 'Osborne House',
      footballTeam: 'Newport IOW FC',
      nickname: 'The Island',
      flag:
          'The Isle of Wight\'s flag reflects its ancient status as a semi-independent entity. The island was for centuries the seat of the Lords of the Isle — a title held by Norman lords and later English nobility — giving it a distinct identity apart from the mainland. The gold outline of the island itself is a rare heraldic device emphasising its island nature.',
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
          'Norfolk\'s black and white bicolour derives from the arms of the de Ufford family and later the Mowbray Dukes of Norfolk, whose heraldic colours of sable (black) and argent (white/silver) became associated with the county. These colours also echo the distinctive black-and-white flint-knapped buildings that characterise Norfolk\'s vernacular architecture.',
    ),
    'SUF': UkCountyClueData(
      country: 'England',
      famousPerson: 'Ed Sheeran',
      famousLandmark: 'Framlingham Castle',
      footballTeam: 'Ipswich Town',
      nickname: 'Silly Suffolk',
      flag:
          'Suffolk\'s flag draws on the arms of the ancient Anglo-Saxon Kingdom of the East Angles, of which Suffolk was the southern half (South Folk). The crown references the saintly East Anglian king Edmund the Martyr, killed by Vikings in 869 and venerated as a king-saint, whose royal emblem long represented the region.',
    ),
    'CAM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Stephen Hawking',
      famousLandmark: 'King\'s College Chapel',
      footballTeam: 'Cambridge United',
      nickname: 'The Fens',
      flag:
          'The three golden crowns on blue are the arms of the East Anglian kingdom, representing the three legendary kings who once ruled the region. They are also associated with the Three Kings of Cologne, whose relics were venerated at Ely Cathedral — a centre of medieval pilgrimage in the Fens at the heart of Cambridgeshire.',
    ),
    'LIN': UkCountyClueData(
      country: 'England',
      famousPerson: 'Margaret Thatcher',
      famousLandmark: 'Lincoln Cathedral',
      footballTeam: 'Lincoln City',
      nickname: 'The Yellow Bellies',
      flag:
          'Lincolnshire\'s flag combines the green of its famous limestone wolds and rich agricultural fenland with the fleur-de-lis taken from the arms of the City of Lincoln — a symbol linked to the French connection of the Norman cathedral builders. Lincoln was one of the largest cities in medieval England, and its arms reflect centuries of trade with France.',
    ),
    'BED': UkCountyClueData(
      country: 'England',
      famousPerson: 'John Bunyan',
      famousLandmark: 'Woburn Abbey',
      footballTeam: 'Luton Town',
      nickname: 'The Bedfordshire Clanger County',
      flag:
          'Bedfordshire\'s flag bears the arms of the Beauchamp family — Earls of Bedford — who held the county in the medieval period. The three silver escallop shells on a red bend (diagonal stripe) are classic Beauchamp heraldry; the scallop shell in medieval heraldry signified a pilgrim or crusader, reflecting the family\'s religious and martial prestige.',
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
          'Bristol\'s ship-and-castle arms originate in the city\'s medieval status as England\'s second-greatest port. The castle represents the Norman Clifton fortress built to control the Avon Gorge, while the ship embodies the Atlantic trade that made Bristol wealthy — including, controversially, its role as a central hub of the transatlantic slave trade.',
    ),
    'DEV': UkCountyClueData(
      country: 'England',
      famousPerson: 'Agatha Christie',
      famousLandmark: 'Exeter Cathedral',
      footballTeam: 'Plymouth Argyle, Exeter City',
      nickname: 'Glorious Devon',
      flag:
          'Devon\'s green and black bicolour references the county\'s landscape contrasts: the lush green of its rolling farmland and the dark moorland of Dartmoor and Exmoor. The colours also appear in the arms of many Devon gentry families. Devon was the county of Sir Francis Drake and Sir Walter Raleigh — Elizabethan sea-dogs who shaped England\'s maritime empire.',
    ),
    'COR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Rosamunde Pilcher',
      famousLandmark: 'St Michael\'s Mount',
      footballTeam: 'Truro City',
      nickname: 'The Duchy',
      flag:
          'St Piran\'s Cross — white on black — is the flag of Cornwall and its patron saint, a 5th-century Irish monk who reputedly discovered tin smelting when his black hearthstone glowed white-hot. The colours represent tin (white/silver) emerging from the black ore, celebrating the industry that defined Cornwall\'s Celtic identity for two millennia.',
    ),
    'SOM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Arthur C. Clarke',
      famousLandmark: 'Glastonbury Tor',
      footballTeam: 'Bristol City',
      nickname: 'The Cider County',
      flag:
          'Somerset\'s red dragon on gold derives from the arms of the ancient Kingdom of Wessex and its association with Arthurian legend — Glastonbury is traditionally identified as Avalon, the resting place of King Arthur. The dragon was the battle standard of Uther Pendragon and the Celtic warlords who resisted Saxon invasion from this heartland.',
    ),
    'DOR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Thomas Hardy',
      famousLandmark: 'Durdle Door',
      footballTeam: 'Bournemouth AFC',
      nickname: 'Hardy Country',
      flag:
          'Dorset\'s quartered red and gold field echoes the arms of the Bishops of Salisbury, who had jurisdiction over much of the county in the medieval period. The cross connects to the ecclesiastical history of the region, while the colours reflect the county\'s ancient manorial heritage. Dorset was home to many powerful Norman families after 1066.',
    ),
    'GLO': UkCountyClueData(
      country: 'England',
      famousPerson: 'J.K. Rowling',
      famousLandmark: 'Gloucester Cathedral',
      footballTeam: 'Cheltenham Town, Forest Green Rovers',
      nickname: 'The Cotswolds County',
      flag:
          'Gloucestershire\'s green and gold reflect the fertile Severn Vale and the wealth of the medieval wool trade that built the county\'s magnificent churches and manor houses. The chevron pattern is drawn from the arms of Clare, Earls of Gloucester — one of the most powerful Anglo-Norman dynasties, whose red chevrons on gold became inseparable from the county\'s identity.',
    ),
    'WIL': UkCountyClueData(
      country: 'England',
      famousPerson: 'Sir Christopher Wren',
      famousLandmark: 'Stonehenge',
      footballTeam: 'Swindon Town',
      nickname: 'The Moonraker County',
      flag:
          'The Great Bustard on Wiltshire\'s flag celebrates the bird that once roamed Salisbury Plain in great numbers before being hunted to extinction in Britain by the 1840s. The bustard has been the county\'s symbol since at least the 18th century, appearing in Wiltshire regimental badges and arms — a reminder of the ancient chalk downland that defines the county.',
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
          'Oxford\'s arms feature a classic example of canting heraldry: a gold ford (river crossing) with an ox, literally spelling out "Ox-ford." This punning tradition in heraldry dates to the Norman period. The city\'s university — founded in the 12th century and among the oldest in the English-speaking world — made the ox-ford crossing one of the most intellectually significant in history.',
    ),
    'WAR': UkCountyClueData(
      country: 'England',
      famousPerson: 'William Shakespeare',
      famousLandmark: 'Warwick Castle',
      footballTeam: 'Coventry City',
      nickname: 'The Heart of England',
      flag:
          'Warwickshire\'s bear and ragged staff is one of England\'s most celebrated heraldic badges, belonging to the Earls of Warwick — among the most powerful magnates in medieval England. The chequered fess (horizontal band) derives from the arms of the de Newburgh Earls of Warwick. The badge became so famous it entered common parlance as a synonym for the county itself.',
    ),
    'NTH': UkCountyClueData(
      country: 'England',
      famousPerson: 'Alan Moore',
      famousLandmark: 'Silverstone Circuit',
      footballTeam: 'Northampton Town',
      nickname: 'The Rose of the Shires',
      flag:
          'The red rose of Northamptonshire is distinct from the red rose of Lancaster — it is an older heraldic charge associated with the county\'s Norman lords. Northamptonshire sits at the geographic heart of England and was a royal county, with numerous hunting lodges and manor houses; the rose reflects its long association with courtly culture and nobility.',
    ),
    'LEI': UkCountyClueData(
      country: 'England',
      famousPerson: 'Gary Lineker',
      famousLandmark: 'Leicester Cathedral',
      footballTeam: 'Leicester City',
      nickname: 'The Foxes',
      flag:
          'Leicestershire\'s fox has been the county\'s symbol since at least the 19th century, celebrating its world-famous foxhunting tradition — the Quorn, Belvoir and Pytchley hunts made the Leicestershire countryside the spiritual home of the sport. The cinquefoil (five-petalled flower) comes from the arms of the de Quincy Earls of Winchester, who held great Leicestershire estates.',
    ),
    'NOT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Lord Byron',
      famousLandmark: 'Sherwood Forest',
      footballTeam: 'Nottingham Forest, Notts County',
      nickname: 'Robin Hood Country',
      flag:
          'Nottinghamshire\'s green reflects the ancient forest of Sherwood, the royal hunting forest that covered a third of the county in the medieval period and gave rise to the legend of Robin Hood. The outlaw\'s silhouette on the flag is a modern addition that celebrates the county\'s most famous mythological figure, whose story of fighting Norman oppression resonates across centuries.',
    ),
    'DER': UkCountyClueData(
      country: 'England',
      famousPerson: 'Florence Nightingale',
      famousLandmark: 'Chatsworth House',
      footballTeam: 'Derby County',
      nickname: 'The Peak',
      flag:
          'Derbyshire\'s flag combines the Tudor rose — recalling the county\'s prominence during the Tudor era, when the Derbyshire lead mines enriched the Crown — with the blue cross derived from the arms of Robert de Ferrers, the powerful Norman Earl of Derby. The green represents the Peak District moorland, England\'s first national park.',
    ),
    'STS': UkCountyClueData(
      country: 'England',
      famousPerson: 'Robbie Williams',
      famousLandmark: 'Alton Towers',
      footballTeam: 'Stoke City',
      nickname: 'The Potteries',
      flag:
          'The Staffordshire Knot is one of England\'s most distinctive heraldic badges, a three-looped knot of uncertain but ancient origin. It is first recorded in the 14th century and was used by the Stafford Dukes of Buckingham, who took their title and arms from the county. The knot became so embedded in county identity that it appears on civic heraldry, regimental badges and pub signs across Staffordshire.',
    ),
    'BKM': UkCountyClueData(
      country: 'England',
      famousPerson: 'Roald Dahl',
      famousLandmark: 'Bletchley Park',
      footballTeam: 'Wycombe Wanderers',
      nickname: 'The Home of the Chilterns',
      flag:
          'The chained swan is the badge of the Bohun family, Earls of Hereford and Essex, who held great estates across Buckinghamshire. Through inheritance it passed to Henry IV and became a royal badge of the House of Lancaster. The swan — noble, white and restrained — perfectly captured the medieval ideal of controlled power; it became inseparable from Buckinghamshire\'s identity.',
    ),
    'HEF': UkCountyClueData(
      country: 'England',
      famousPerson: 'David Garrick',
      famousLandmark: 'Hereford Cathedral',
      footballTeam: 'Hereford FC',
      nickname: 'The Marches',
      flag:
          'Herefordshire\'s flag celebrates the famous Hereford breed of cattle, whose red-and-white colouring has been selectively developed in the county since the 18th century and exported worldwide. The three gold lions derive from the arms of the de Lacy lords of Hereford — Norman barons who built Hereford Castle and controlled the Welsh Marches for the Crown.',
    ),
    'WOR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Edward Elgar',
      famousLandmark: 'Worcester Cathedral',
      footballTeam: 'Worcester City',
      nickname: 'The Faithful City County',
      flag:
          'The pear tree on Worcestershire\'s flag is a reference to the famous Worcestershire pear — the county has been renowned for its perry (pear cider) and dessert pears since at least the 17th century. The wavy lines represent the River Severn, which bisects the county. The combination reflects a uniquely agrarian identity, rich orchards and the gentle landscape celebrated by Edward Elgar in his music.',
    ),
    'RUT': UkCountyClueData(
      country: 'England',
      famousPerson: 'Titus Oates',
      famousLandmark: 'Rutland Water',
      footballTeam: 'Oakham United',
      nickname: 'England\'s Smallest County',
      flag:
          'The horseshoe is the ancient symbol of Rutland, England\'s smallest historic county. Local tradition holds it represents the county\'s importance as a centre of horse-breeding and royal hunting; it appears in civic arms for centuries. Rutland famously resisted abolition in the 1974 local government reorganisation and was restored as an independent county in 1997 — the horseshoe a fitting symbol of stubborn good fortune.',
    ),
    'SHR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Charles Darwin',
      famousLandmark: 'Ironbridge Gorge',
      footballTeam: 'Shrewsbury Town',
      nickname: 'Salop',
      flag:
          'Shropshire\'s three white leopard faces (or lion faces passant) on blue and gold derive from the arms of the de Belmeis and later Fitz Alan lords who held the county. The Fitz Alans, Earls of Arundel, were among the most powerful Marcher lords guarding the Welsh border; their heraldry merged with local tradition to produce Shropshire\'s distinctive blue-and-gold identity.',
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
          'The red rose of Lancashire is the emblem of the House of Lancaster, the royal dynasty that produced Henry IV, V and VI. After the Wars of the Roses, the red rose became firmly associated with Lancashire\'s fierce county pride. The gold field derives from the arms of the Duchy of Lancaster, which remains a personal possession of the Crown to this day.',
    ),
    // CHS renamed to CHE (Cheshire)
    'CHE': UkCountyClueData(
      country: 'England',
      famousPerson: 'Lewis Carroll',
      famousLandmark: 'Chester Cathedral',
      footballTeam: 'Chester FC',
      nickname: 'The County Palatine',
      flag:
          'The three golden wheatsheaves of Cheshire derive from the arms of the ancient Earldom of Chester, one of England\'s most powerful palatine earldoms. The sword represents the county\'s status as a County Palatine — a jurisdiction where the Earl exercised powers equivalent to the King, including his own courts, mint and army. The earldom was merged with the Crown in 1254.',
    ),
    'DUR': UkCountyClueData(
      country: 'England',
      famousPerson: 'Rowan Atkinson',
      famousLandmark: 'Durham Cathedral',
      footballTeam: 'Darlington FC',
      nickname: 'Land of the Prince Bishops',
      flag:
          'Durham\'s flag honours the Prince Bishops of Durham, who wielded royal power within the county palatine from the Norman Conquest until 1836. The gold cross on blue derives from the arms of the Bishopric — the lions represent the power vested in the bishops by the Crown to defend the northern frontier against Scottish invasion. Durham Cathedral, built to house St Cuthbert\'s relics, was the seat of this unique ecclesiastical state.',
    ),
    // CUM renamed to CMA (Cumbria)
    'CMA': UkCountyClueData(
      country: 'England',
      famousPerson: 'William Wordsworth',
      famousLandmark: 'Hadrian\'s Wall',
      footballTeam: 'Carlisle United',
      nickname: 'The Lake District',
      flag:
          'Cumbria\'s flag combines elements from its constituent historic counties — Cumberland and Westmorland — which merged in 1974. The gold fleece reflects the county\'s ancient wool trade from Herdwick sheep, bred on the fells since Viking settlement. The colours of green, blue and gold represent the lake, fell and pastoral landscape that Wordsworth immortalised as the English sublime.',
    ),
    'NBL': UkCountyClueData(
      country: 'England',
      famousPerson: 'Jackie Charlton',
      famousLandmark: 'Lindisfarne Castle',
      footballTeam: 'Newcastle United',
      nickname: 'The Far North',
      flag:
          'Northumberland\'s arms draw on the ancient heraldry of the Earldom of Northumberland, one of the most turbulent titles in English history. The red and gold quartering echoes the Percy family arms — Earls of Northumberland since the 14th century — whose power rivalled the Crown and whose rebellion against Henry IV inspired Shakespeare\'s Henry IV plays. The blue and white chequered canton derives from the ancient Kingdom of Northumbria.',
    ),
    'NYK': UkCountyClueData(
      country: 'England',
      famousPerson: 'James Herriot',
      famousLandmark: 'Whitby Abbey',
      footballTeam: 'Harrogate Town, York City',
      nickname: 'God\'s Own County',
      flag:
          'North Yorkshire carries the white rose of the House of York on blue — the same emblem shared across all Yorkshire ridings. As England\'s largest county, North Yorkshire encompasses the great medieval landscapes of the Yorkshire Dales and North York Moors, and the historic city of York itself, the former Roman capital of Britannia and seat of the Archbishop whose power historically rivalled Canterbury.',
    ),
    'ERY': UkCountyClueData(
      country: 'England',
      famousPerson: 'Amy Johnson',
      famousLandmark: 'The Humber Bridge',
      footballTeam: 'Hull City',
      nickname: 'The Wolds',
      flag:
          'The East Riding of Yorkshire carries the white rose of York, shared across all three Yorkshire ridings as a mark of common identity. The wavy band represents the Humber estuary — one of Britain\'s great river mouths — which made Kingston upon Hull a prosperous medieval port and the gateway through which Scandinavian culture and trade flowed into England.',
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
          'Glasgow\'s arms feature four symbols from the legend of St Mungo, the city\'s 6th-century patron saint: the tree he lit by breathing on a branch, the bird (robin) he restored to life, the bell he brought from Rome, and the fish with a ring in its mouth — recalling a queen\'s lost ring found inside a salmon. The rhyme "Here is the bird that never flew…" encodes all four symbols in Glasgow\'s civic identity.',
    ),
    'EDH': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Graham Bell',
      famousLandmark: 'Edinburgh Castle',
      footballTeam: 'Hibernian, Hearts',
      nickname: 'Auld Reekie',
      flag:
          'Edinburgh\'s arms feature the castle, representing the volcanic crag fortress that has been occupied for over 3,000 years. The castle has been the seat of Scottish kings, a state prison and treasury housing the Honours of Scotland — the oldest crown jewels in the British Isles. Edinburgh became the capital of Scotland in the 15th century, cementing its identity as a seat of law, Church and government.',
    ),
    'FIF': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Adam Smith',
      famousLandmark: 'St Andrews Links',
      footballTeam: 'Dunfermline Athletic',
      nickname: 'The Kingdom of Fife',
      flag:
          'The Kingdom of Fife — as it has been known since at least the 12th century — carries the red lion rampant on gold, derived from the arms of the ancient MacDuff Earls of Fife. The MacDuffs held one of the seven earldoms of Scotland and had the sacred privilege of crowning the Scottish King at Scone. The chequered border echoes the tressure found on the Royal Standard of Scotland.',
    ),
    'HLD': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Flora MacDonald',
      famousLandmark: 'Loch Ness',
      footballTeam: 'Inverness Caledonian Thistle',
      nickname: 'The Highlands',
      flag:
          'The Highlands uses the Saltire — the national flag of Scotland — the white diagonal cross on blue that represents St Andrew, Scotland\'s patron saint, who was martyred on a diagonal (X-shaped) cross at Patras in Greece. Legend holds that St Andrew\'s relics were brought to Scotland in the 4th century by a monk called Rule, and the sight of a white cross against a blue sky before battle confirmed the symbol as Scotland\'s own.',
    ),
    'ABD': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Annie Lennox',
      famousLandmark: 'Balmoral Castle',
      footballTeam: 'Aberdeen FC',
      nickname: 'The Granite City',
      flag:
          'Aberdeenshire\'s three silver towers on blue derive from the ancient arms of the region, representing the great castles that once controlled the Grampian routes. The county was home to more castles per square mile than almost anywhere in Europe, reflecting its importance as a buffer zone between the Lowland kingdoms and the Highland clans. Balmoral, the royal residence chosen by Queen Victoria, lies here.',
    ),
    'ABE': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Denis Law',
      famousLandmark: 'Marischal College',
      footballTeam: 'Aberdeen FC',
      nickname: 'The Silver City',
      flag:
          'Aberdeen city\'s arms reflect its medieval importance as a royal burgh and trading hub. The three silver towers represent the city\'s fortifications and its status as a place of strength at the mouth of the River Dee. The leopards (derived from Scottish royal heraldry) acknowledge Aberdeen\'s close ties to the Scottish Crown, which granted the city its first royal charter.',
    ),
    'AYR': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Burns',
      famousLandmark: 'Burns Cottage',
      footballTeam: 'Ayr United, Kilmarnock',
      nickname: 'Burns Country',
      flag:
          'The heart on Ayrshire\'s flag is the Bleeding Heart of Douglas — emblem of the powerful Black Douglas family, who were the dominant lords of this region in the 14th and 15th centuries. The Good Sir James Douglas carried the embalmed heart of Robert the Bruce on crusade in 1330, and the heart symbol has defined Douglas heraldry ever since, passing into the wider identity of Ayrshire.',
    ),
    'DGY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert the Bruce',
      famousLandmark: 'Sweetheart Abbey',
      footballTeam: 'Queen of the South',
      nickname: 'The Galloway Hills',
      flag: 'Blue field with white lion rampant from Galloway arms',
    ),
    // STI renamed to STG (Stirling)
    'STG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Wallace',
      famousLandmark: 'Stirling Castle',
      footballTeam: 'Stirling Albion',
      nickname: 'The Gateway to the Highlands',
      flag: 'Gold field with red wolf from burgh arms',
    ),
    'ANS': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Don Coutts',
      famousLandmark: 'Glamis Castle',
      footballTeam: 'Arbroath FC, Forfar Athletic',
      nickname: 'The Land o\' the Angus Glens',
      flag: 'Red field with white lion passant from Angus arms',
    ),
    'ARG': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Neil Munro',
      famousLandmark: 'Inveraray Castle',
      footballTeam: 'Oban Saints',
      nickname: 'The Gateway to the Isles',
      flag: 'Blue and green field with lymphad ship from Campbell arms',
    ),
    'CLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Bruce',
      famousLandmark: 'Alloa Tower',
      footballTeam: 'Alloa Athletic',
      nickname: 'The Wee County',
      flag: 'Gold field with black saltire and oak tree from county arms',
    ),
    'DND': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Mary Shelley (lived here)',
      famousLandmark: 'RRS Discovery',
      footballTeam: 'Dundee FC, Dundee United',
      nickname: 'The City of Discovery',
      flag: 'Blue field with white pot of lilies from city arms',
    ),
    'EDU': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Tom Conti',
      famousLandmark: 'Mugdock Castle',
      footballTeam: 'Kirkintilloch Rob Roy',
      nickname: 'The Bears Den',
      flag:
          'Green field with white and blue wavy band and bear from council arms',
    ),
    'EIL': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Angus MacPhee',
      famousLandmark: 'Callanish Standing Stones',
      footballTeam: 'Stornoway United',
      nickname: 'The Western Isles',
      flag: 'Blue field with Norse longship and herring from island arms',
    ),
    'ELN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'John Muir',
      famousLandmark: 'Tantallon Castle',
      footballTeam: 'Dunbar United',
      nickname: 'Scotland\'s Golf Coast',
      flag: 'Red field with white goat from county arms',
    ),
    'ERW': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'David Dale',
      famousLandmark: 'Rouken Glen Park',
      footballTeam: 'Arthurlie FC',
      nickname: 'The Ren',
      flag: 'Green field with white chevron and thistle from council arms',
    ),
    'FAL': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'William Rankine',
      famousLandmark: 'The Kelpies',
      footballTeam: 'Falkirk FC',
      nickname: 'The Bairns\' Town',
      flag: 'Blue field with silver stag and Forth bridge from council arms',
    ),
    'INV': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Mary Barbour',
      famousLandmark: 'Newark Castle',
      footballTeam: 'Greenock Morton',
      nickname: 'The Tail of the Bank',
      flag:
          'Blue field with silver herring and sailing ship from Inverclyde arms',
    ),
    'MLN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Dolly the Sheep (Roslin Institute)',
      famousLandmark: 'Rosslyn Chapel',
      footballTeam: 'Bonnyrigg Rose Athletic',
      nickname: 'The Heart of Midlothian',
      flag: 'Blue field with white castle and gold stars from Midlothian arms',
    ),
    'MRY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Ramsay MacDonald',
      famousLandmark: 'Elgin Cathedral',
      footballTeam: 'Elgin City',
      nickname: 'The Malt Whisky Country',
      flag: 'Blue field with gold stars and silver castle from Moray arms',
    ),
    'NAY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Fleming',
      famousLandmark: 'Brodick Castle',
      footballTeam: 'Kilwinning Rangers',
      nickname: 'The Ayrshire Coast',
      flag: 'Blue field with silver saltire and red heart',
    ),
    'NLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Alexander Baird',
      famousLandmark: 'Summerlee Museum of Scottish Industrial Life',
      footballTeam: 'Motherwell FC, Airdrieonians',
      nickname: 'The Lanarkshire Heartland',
      flag: 'Red field with double-headed eagle from Hamilton arms',
    ),
    'ORK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'George Mackay Brown',
      famousLandmark: 'Skara Brae',
      footballTeam: 'Orkney FC',
      nickname: 'The Northern Isles',
      flag: 'Red and yellow Nordic cross on blue field',
    ),
    'PKN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'John Buchan',
      famousLandmark: 'Scone Palace',
      footballTeam: 'St Johnstone',
      nickname: 'The Big County',
      flag: 'Gold field with red eagle from Perth arms',
    ),
    'RFW': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Gerry Rafferty',
      famousLandmark: 'Paisley Abbey',
      footballTeam: 'St Mirren',
      nickname: 'The Buddies\' Land',
      flag: 'Blue field with chequered silver band and mitre from Paisley arms',
    ),
    'SAY': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Robert Burns (Alloway)',
      famousLandmark: 'Culzean Castle',
      footballTeam: 'Ayr United',
      nickname: 'The Burns Coast',
      flag: 'Blue field with silver saltire and castle from Ayr arms',
    ),
    'SCB': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Walter Scott',
      famousLandmark: 'Abbotsford House',
      footballTeam: 'Gala Fairydean Rovers',
      nickname: 'Scott\'s Country',
      flag: 'Green field with gold saltire and silver tower from Borders arms',
    ),
    'SLK': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Sir Harry Lauder',
      famousLandmark: 'New Lanark',
      footballTeam: 'Hamilton Academical',
      nickname: 'The Clyde Valley',
      flag: 'Red field with double-headed eagle and Hamilton cinquefoils',
    ),
    'WDU': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Tobias Smollett',
      famousLandmark: 'Dumbarton Castle',
      footballTeam: 'Dumbarton FC',
      nickname: 'The Rock',
      flag: 'Blue field with white elephant and castle from Dumbarton arms',
    ),
    'WLN': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Dougray Scott',
      famousLandmark: 'Linlithgow Palace',
      footballTeam: 'Livingston FC',
      nickname: 'The Shale Oil County',
      flag: 'Blue field with black dog on gold ground from Linlithgow arms',
    ),
    'ZET': UkCountyClueData(
      country: 'Scotland',
      famousPerson: 'Arthur Anderson',
      famousLandmark: 'Jarlshof',
      footballTeam: 'Shetland FC',
      nickname: 'The Old Rock',
      flag: 'White Nordic cross on blue field',
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
      flag: 'Red dragon on white and green field (Y Ddraig Goch)',
    ),
    'SWA': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Catherine Zeta-Jones',
      famousLandmark: 'Swansea Bay',
      footballTeam: 'Swansea City',
      nickname: 'The Copperopolis',
      flag: 'White castle with black swan on red and gold field',
    ),
    'GWN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Lloyd George',
      famousLandmark: 'Snowdon (Yr Wyddfa)',
      footballTeam: 'Bangor City',
      nickname: 'Land of Castles',
      flag: 'Green field with gold eagles and lions from Gwynedd arms',
    ),
    'PEM': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Griff Rhys Jones',
      famousLandmark: 'Pembroke Castle',
      footballTeam: 'Haverfordwest County',
      nickname: 'Little England Beyond Wales',
      flag: 'Blue field with gold lions from Deheubarth arms',
    ),
    // PWS renamed to POW (Powys)
    'POW': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Laura Ashley',
      famousLandmark: 'Powis Castle',
      footballTeam: 'Newtown AFC',
      nickname: 'The Green Desert of Wales',
      flag: 'Red field with gold lion rampant from Powys Fadog arms',
    ),
    // CRD renamed to CAY (Caerphilly)
    'CAY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Caerphilly Castle',
      footballTeam: 'Cardiff Metropolitan',
      nickname: 'The Valleys',
      flag: 'Green field with red dragon and red chevron',
    ),
    'NWP': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Mark Williams',
      famousLandmark: 'Newport Transporter Bridge',
      footballTeam: 'Newport County',
      nickname: 'The Gateway to Wales',
      flag: 'Gold field with red chevron and three silver towers',
    ),
    'RCT': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Tom Jones',
      famousLandmark: 'Rhondda Heritage Park',
      footballTeam: 'Pontypridd Town',
      nickname: 'The Rhondda Valleys',
      flag: 'Black and gold field with red dragon and mining symbols',
    ),
    'FLN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Jonathan Davies',
      famousLandmark: 'Flint Castle',
      footballTeam: 'Connah\'s Quay Nomads',
      nickname: 'The Borderlands',
      flag: 'Gold field with red lion rampant and silver castle',
    ),
    'WRX': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Elihu Yale',
      famousLandmark: 'Wrexham Parish Church',
      footballTeam: 'Wrexham AFC',
      nickname: 'The Gateway to Wales',
      flag: 'Green field with gold cross and red Powys lion',
    ),
    'CMN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Hedd Wyn',
      famousLandmark: 'National Botanic Garden of Wales',
      footballTeam: 'Carmarthen Town',
      nickname: 'The Garden of Wales',
      flag: 'Blue and gold quartered field with gold lions and towers',
    ),
    'CRG': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Augustus John',
      famousLandmark: 'Devil\'s Bridge',
      footballTeam: 'Aberystwyth Town',
      nickname: 'The Celtic Heartland',
      flag: 'Gold field with blue dolphins and red lion from Ceredigion arms',
    ),
    'AGY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Anglesey Druid heritage',
      famousLandmark: 'Beaumaris Castle',
      footballTeam: 'Holyhead Hotspur',
      nickname: 'Mother of Wales',
      flag: 'Green and white field with gold coronet and red lions',
    ),
    'BGE': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Gareth Thomas',
      famousLandmark: 'Porthcawl Lighthouse',
      footballTeam: 'Bridgend Town',
      nickname: 'Gateway to the Valleys',
      flag: 'Blue field with a gold castle and bridge',
    ),
    'BGW': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Aneurin Bevan',
      famousLandmark: 'Big Pit National Coal Museum',
      footballTeam: 'Ebbw Vale',
      nickname: 'Valleys Gateway',
      flag: 'Green and white with a mining symbol',
    ),
    'CWY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Bryn Terfel',
      famousLandmark: 'Conwy Castle',
      footballTeam: 'Conwy Borough',
      nickname: 'Land of Castles',
      flag: 'Gold field with a red eagle',
    ),
    'DEN': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Beatrix Potter (holidayed)',
      famousLandmark: 'Denbigh Castle',
      footballTeam: 'Rhyl',
      nickname: 'Heart of the Vale',
      flag: 'Red and gold stripes with a black lion',
    ),
    'MON': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Henry V',
      famousLandmark: 'Tintern Abbey',
      footballTeam: 'Monmouth Town',
      nickname: 'Gateway to Wales',
      flag: 'Gold field with three chevrons',
    ),
    'MTY': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Laura Ashley',
      famousLandmark: 'Cyfarthfa Castle',
      footballTeam: 'Merthyr Town',
      nickname: 'Iron Capital of the World',
      flag: 'Red field with a gold crown',
    ),
    'NPT': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Richard Burton',
      famousLandmark: 'Gnoll Estate Country Park',
      footballTeam: 'Port Talbot Town',
      nickname: 'Steel Town',
      flag: 'Blue and gold with industrial symbols',
    ),
    'TOF': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Terry Matthews',
      famousLandmark: 'Blaenavon Ironworks',
      footballTeam: 'Cwmbran Celtic',
      nickname: 'Land of the Torrent',
      flag: 'Green with a gold torch',
    ),
    'VGL': UkCountyClueData(
      country: 'Wales',
      famousPerson: 'Roald Dahl (raised in Penarth)',
      famousLandmark: 'Dunraven Bay',
      footballTeam: 'Barry Town United',
      nickname: 'Garden of Wales',
      flag: 'Green and gold with a rose',
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
          'Red field with white castle and gold chief with red hand of Ulster',
    ),
    'ARM': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'George Best',
      famousLandmark: 'Armagh Cathedral',
      footballTeam: 'Armagh City FC',
      nickname: 'The Orchard County',
      flag: 'Blue field with red hand of Ulster on gold shield',
    ),
    'DOW': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Patrick Bronte',
      famousLandmark: 'Mourne Mountains',
      footballTeam: 'Glenavon FC',
      nickname: 'The Mournes',
      flag: 'Green field with silver ship and gold fish from county arms',
    ),
    'FER': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Samuel Beckett',
      famousLandmark: 'Enniskillen Castle',
      footballTeam: 'Enniskillen Town',
      nickname: 'The Lakeland County',
      flag:
          'Blue field with red hand of Ulster and silver cross from county arms',
    ),
    'LDY': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Seamus Heaney',
      famousLandmark: 'Derry City Walls',
      footballTeam: 'Derry City FC',
      nickname: 'The Maiden City',
      flag: 'White field with red cross and gold castle with skeleton in tower',
    ),
    'TYR': UkCountyClueData(
      country: 'Northern Ireland',
      famousPerson: 'Brian Friel',
      famousLandmark: 'Sperrin Mountains',
      footballTeam: 'Dungannon Swifts',
      nickname: 'O\'Neill Country',
      flag:
          'Gold field with red hand of Ulster and red cross from O\'Neill arms',
    ),
  };
}
