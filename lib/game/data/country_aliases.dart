/// Common alternative names, abbreviations, and frequent misspellings
/// for countries, states, and territories.
///
/// Keys are normalized (lowercase, no diacritics, no punctuation).
/// Values are lists of alternative spellings that should match.
///
/// Only include the canonical country name as the key — the FuzzyMatcher
/// handles reverse lookups automatically. Do NOT add reverse entries
/// (e.g. 'uae' → 'united arab emirates') as these create orphaned entries
/// in the admin panel.
library;

const Map<String, List<String>> countryAliases = {
  // ════════════════════════════════════════════════════════════════
  // AFRICA
  // ════════════════════════════════════════════════════════════════

  'cote divoire': [
    'ivory coast',
    'cote d ivoire',
    'la cote divoire',
    'ivorycoast',
    'cote d',
  ],

  'congo dr': [
    'drc',
    'dr congo',
    'democratic republic of the congo',
    'democratic republic of congo',
    'congo kinshasa',
    'zaire',
    'congo democratic republic',
  ],

  'congo republic': [
    'republic of the congo',
    'republic of congo',
    'congo brazzaville',
    'roc',
    'congo rep',
  ],

  'eswatini': ['swaziland', 'kingdom of eswatini'],

  'cabo verde': ['cape verde', 'cape verde islands', 'capeverde'],

  'central african republic': ['car', 'central africa', 'centrafrique'],

  'south sudan': ['s sudan', 'ss', 'republic of south sudan'],

  'burkina faso': ['upper volta', 'burkinafaso', 'burkina'],

  'tanzania': [
    'united republic of tanzania',
    'tanganyika',
    'tanzaniia',
    'tanazania',
  ],

  'guinea bissau': ['guinea-bissau', 'guinee bissau', 'guine bissau'],

  'sao tome and principe': [
    'sao tome',
    'stp',
    'sao tome principe',
    'sao tome n principe',
    'saint thomas and prince',
  ],

  'equatorial guinea': [
    'eq guinea',
    'eq. guinea',
    'equatorial guinea republic',
    'guinea ecuatorial',
  ],

  'western sahara': [
    'w sahara',
    'ws',
    'sahrawi republic',
    'western sahara territory',
  ],

  'djibouti': ['djibuti', 'djibouti republic', 'jibouti'],

  'eritrea': [
    'erithrea',
    'eritraea',
    'erithreea',
    'eretria',
    'state of eritrea',
  ],

  'ethiopia': [
    'etiopia',
    'ethiopa',
    'ethopia',
    'ethioppia',
    'abyssinia',
    'federal democratic republic of ethiopia',
  ],

  'kenya': ['republic of kenya', 'kenia'],

  'ghana': ['gold coast', 'republic of ghana'],

  'nigeria': ['nigiria', 'nigeia', 'federal republic of nigeria'],

  'senegal': ['senagal', 'republic of senegal', 'senagel'],

  'mali': ['republic of mali'],

  'niger': ['republic of niger'],

  'chad': ['republic of chad', 'tchad'],

  'cameroon': ['cameroun', 'republic of cameroon'],

  'gabon': ['gabonese republic'],

  'angola': ['republic of angola'],

  'zambia': ['zamiba', 'republic of zambia'],

  'zimbabwe': ['zimbabwae', 'zimbawbe', 'republic of zimbabwe'],

  'mozambique': [
    'mozambik',
    'mocambique',
    'republic of mozambique',
    'mozanbique',
  ],

  'madagascar': ['madagasgar', 'madagaskar', 'republic of madagascar'],

  'malawi': ['malwi', 'nyasaland', 'republic of malawi'],

  'rwanda': ['republic of rwanda'],

  'burundi': ['republic of burundi'],

  'uganda': ['republic of uganda'],

  'somalia': ['republic of somalia', 'somali republic'],

  'liberia': ['republic of liberia'],

  'sierra leone': [
    'siera leone',
    'sierre leone',
    'sierra leon',
    'seirra leone',
  ],

  'guinea': ['guinee', 'republic of guinea', 'guinee republique'],

  'togo': ['togolese republic'],

  'benin': ['republic of benin', 'dahomey'],

  'mauritania': ['mauritana', 'mouritania', 'islamic republic of mauritania'],

  'gambia': ['the gambia', 'republic of the gambia'],

  'comoros': ['comoro islands', 'union of the comoros', 'comoro'],

  'seychelles': ['republic of seychelles', 'seychells'],

  'mauritius': ['republic of mauritius'],

  'libya': ['libia', 'libiya', 'state of libya'],

  'algeria': ['algerie', 'peoples democratic republic of algeria'],

  'tunisia': ['tunesia', 'tunisian republic'],

  'morocco': ['morroco', 'morrocco', 'kingdom of morocco'],

  'egypt': ['arab republic of egypt', 'egipt'],

  'sudan': ['republic of the sudan', 'republic of sudan'],

  'lesotho': ['leshoto', 'kingdom of lesotho'],

  'botswana': ['botsuana', 'republic of botswana'],

  'namibia': ['namibea', 'republic of namibia'],

  'south africa': ['s africa', 'rsa', 'republic of south africa'],

  // ════════════════════════════════════════════════════════════════
  // ASIA
  // ════════════════════════════════════════════════════════════════

  'myanmar': ['burma', 'myanmmar', 'republic of the union of myanmar'],

  'timor leste': [
    'east timor',
    'timorleste',
    'e timor',
    'timor',
    'democratic republic of timor leste',
  ],

  'brunei': ['brunei darussalam', 'negara brunei darussalam'],

  'laos': [
    'lao',
    'lao pdr',
    'lao peoples democratic republic',
    'lao pdr',
    'laos pdr',
  ],

  'south korea': [
    'korea',
    'republic of korea',
    'rok',
    's korea',
    'korea south',
  ],

  'north korea': [
    'dprk',
    'democratic peoples republic of korea',
    'n korea',
    'korea north',
  ],

  'united arab emirates': ['uae', 'emirates'],

  'saudi arabia': [
    'ksa',
    'kingdom of saudi arabia',
    'saudi',
    'saudia arabia',
    'saudia',
  ],

  'kyrgyzstan': [
    'kirghizia',
    'kyrgyz republic',
    'kyrgyztan',
    'kirgizstan',
    'kirgistan',
    'kyrgystan',
    'kyrgzstan',
    'kyrgistan',
    'kirgiziya',
    'kirgizia',
    'kirgisia',
    'kyrgizstan',
    'kyrgztan',
    'kyrgstan',
    'kirghizstan',
    'kirghistan',
    'kyrgysstan',
    'kyrgyzsatan',
    'kyrgyzstaan',
    'kyrgyzstatn',
    'kyrgyztsan',
    'kyrgyzstna',
    'krgyzstan',
    'kyrgzistan',
    'kyrgyziston',
    'kyrgyzstain',
    'kyrgyzten',
    'kyrgiztan',
    'kirgyzstan',
    'kyrgystaan',
    'kyrgstan',
  ],

  'tajikistan': [
    'tadzhikistan',
    'tadjikistan',
    'tajikstan',
    'tajikstan',
    'taijikistan',
    'tajkistan',
  ],

  'kazakhstan': [
    'kazakstan',
    'kazahstan',
    'khazakstan',
    'kazahkstan',
    'kazakhkstan',
    'republic of kazakhstan',
  ],

  'uzbekistan': [
    'uzbekstan',
    'uzbek republic',
    'uzebekistan',
    'uzbekistaan',
  ],

  'turkmenistan': ['turkmenstan', 'turkmenia'],

  'azerbaijan': [
    'azerbajan',
    'azerbiajan',
    'azerbijan',
    'azerbaijaan',
    'azerbajian',
  ],

  'armenia': ['hayastan', 'republic of armenia'],

  'georgia': ['sakartvelo', 'republic of georgia'],

  'iran': ['persia', 'islamic republic of iran'],

  'iraq': ['republic of iraq'],

  'jordan': ['hashemite kingdom of jordan'],

  'syria': ['syrian arab republic'],

  'lebanon': ['lebannon', 'lebonon', 'republic of lebanon'],

  'israel': ['state of israel'],

  'palestine': [
    'state of palestine',
    'west bank and gaza',
    'palestinian territories'
  ],

  'oman': ['sultanate of oman'],

  'bahrain': ['kingdom of bahrain'],

  'qatar': ['state of qatar'],

  'kuwait': ['state of kuwait'],

  'yemen': ['republic of yemen'],

  'afghanistan': [
    'afganistan',
    'afgahnistan',
    'afhanistan',
    'afghansitan',
    'afghnaistan',
  ],

  'pakistan': ['pakstan', 'pak', 'islamic republic of pakistan'],

  'india': ['republic of india', 'bharat'],

  'bangladesh': [
    'bangledesh',
    'bangladash',
    'bangladehs',
    'bengladesh',
    'peoples republic of bangladesh',
  ],

  'sri lanka': [
    'srilanka',
    'ceylon',
    'democratic socialist republic of sri lanka'
  ],

  'nepal': ['federal democratic republic of nepal'],

  'bhutan': ['kingdom of bhutan'],

  'maldives': ['republic of maldives', 'maldive islands'],

  'cambodia': ['kampuchea', 'khmer republic', 'kingdom of cambodia'],

  'vietnam': ['viet nam', 'socialist republic of vietnam'],

  'thailand': ['tailand', 'kingdom of thailand', 'siam'],

  'malaysia': [
    'malasia',
    'malayasia',
    'federation of malaysia',
    'malasyia',
  ],

  'singapore': ['singapur', 'singapor', 'republic of singapore'],

  'indonesia': ['indoneisa', 'republic of indonesia', 'indonessia'],

  'philippines': [
    'phillipines',
    'phillippines',
    'philipines',
    'philippenes',
    'philipines',
    'republic of the philippines',
  ],

  'china': [
    'peoples republic of china',
    'prc',
    'zhongguo',
    'mainland china',
  ],

  'taiwan': [
    'republic of china',
    'roc',
    'chinese taipei',
    'formosa',
    'taipei',
  ],

  'japan': ['nippon', 'nihon'],

  'mongolia': ['mongolian people republic'],

  'hong kong': ['hk', 'hong kong sar'],

  'macao': ['macau', 'macao sar'],

  'north macedonia': [
    'macedonia',
    'fyrom',
    'n macedonia',
    'republic of north macedonia'
  ],

  // ════════════════════════════════════════════════════════════════
  // EUROPE
  // ════════════════════════════════════════════════════════════════

  'united kingdom': [
    'uk',
    'britain',
    'great britain',
    'gb',
    'england',
    'uk of great britain',
  ],

  'czech republic': [
    'czechia',
    'czech rep',
    'cz',
    'czechoslovakia',
    'bohemia',
  ],

  'bosnia and herzegovina': [
    'bosnia',
    'bih',
    'bosnia herzegovina',
    'bosnia n herzegovina',
    'bih',
    'herzegowina',
  ],

  'netherlands': ['holland', 'the netherlands', 'nederland'],

  'vatican': ['vatican city', 'holy see', 'holy see vatican city'],

  'russia': ['russian federation', 'rossiya'],

  'moldova': ['republic of moldova', 'moldavia'],

  'belarus': ['byelorussia', 'republic of belarus', 'byelorus'],

  'switzerland': ['swiss', 'swiss confederation', 'helvetia'],

  'germany': ['deutschland', 'federal republic of germany', 'germay'],

  'france': ['french republic', 'la france'],

  'spain': ['espana', 'kingdom of spain'],

  'portugal': ['republic of portugal', 'portugual'],

  'italy': ['italian republic', 'italia'],

  'greece': ['hellenic republic', 'hellas'],

  'austria': ['republic of austria', 'osterreich'],

  'belgium': ['kingdom of belgium', 'belgique'],

  'luxembourg': ['luxemburg', 'luxemborg', 'grand duchy of luxembourg'],

  'liechtenstein': [
    'lichtenstein',
    'liechenstein',
    'principality of liechtenstein',
  ],

  'norway': ['kingdom of norway', 'norge'],

  'sweden': ['kingdom of sweden', 'sverige'],

  'finland': ['republic of finland', 'suomi'],

  'denmark': ['kingdom of denmark', 'danmark'],

  'iceland': ['republic of iceland'],

  'ireland': ['republic of ireland', 'eire', 'ire'],

  'albania': ['republic of albania', 'shqiperia'],

  'andorra': ['principality of andorra'],

  'bulgaria': ['republic of bulgaria'],

  'croatia': ['republic of croatia', 'hrvatska'],

  'cyprus': ['republic of cyprus'],

  'estonia': ['republic of estonia', 'eesti'],

  'hungary': ['hungray', 'magyarorszag'],

  'latvia': ['republic of latvia', 'latvija'],

  'lithuania': ['republic of lithuania', 'lietuva'],

  'malta': ['republic of malta'],

  'monaco': ['principality of monaco'],

  'montenegro': ['crna gora', 'republic of montenegro'],

  'romania': ['roumania', 'rumania', 'romanea'],

  'san marino': ['republic of san marino'],

  'serbia': ['republic of serbia'],

  'slovakia': ['slovak republic', 'slovakya'],

  'slovenia': ['republic of slovenia'],

  'ukraine': ['ukrain', 'the ukraine'],

  'kosovo': ['republic of kosovo', 'kosova'],

  // ════════════════════════════════════════════════════════════════
  // AMERICAS
  // ════════════════════════════════════════════════════════════════

  'united states': [
    'usa',
    'us',
    'america',
    'united states of america',
    'us of america',
    'the us',
    'the usa',
  ],

  'antigua and barb': [
    'antigua',
    'antigua and barbuda',
    'antigua barbuda',
    'antigua n barbuda',
    'wadadli',
  ],

  'saint kitts and nevis': [
    'st kitts',
    'st kitts and nevis',
    'saint kitts',
    'st kitts nevis',
    'saint kitts nevis',
    'st kitts n nevis',
    'saint kitts n nevis',
    'skn',
  ],

  'saint lucia': ['st lucia', 'st. lucia', 'saint lucia island'],

  'saint vincent and the grenadines': [
    'st vincent',
    'saint vincent',
    'svg',
    'st vincent grenadines',
    'saint vincent grenadines',
    'st vincent n the grenadines',
    'saint vincent n the grenadines',
    'stvincent',
  ],

  'trinidad and tobago': [
    'trinidad',
    'tt',
    'trinidad tobago',
    'trinidad n tobago',
    'tobago',
  ],

  'dominican rep': [
    'dominican republic',
    'dominicana',
    'dominicna republic',
  ],

  'el salvador': ['salvador'],

  'costa rica': ['costarica'],

  'bolivia': ['plurinational state of bolivia', 'boliva'],

  'venezuela': ['bolivarian republic of venezuela'],

  'colombia': ['columbia', 'republic of colombia'],

  'brazil': ['brasil', 'federative republic of brazil'],

  'argentina': ['argentinia', 'republic of argentina', 'argentna'],

  'chile': ['chili', 'republic of chile'],

  'peru': ['republic of peru'],

  'ecuador': ['republic of ecuador'],

  'paraguay': ['paraguy', 'paraguai', 'republic of paraguay'],

  'uruguay': ['uruguai', 'oriental republic of uruguay'],

  'guyana': ['republic of guyana', 'cooperative republic of guyana'],

  'suriname': ['surinam', 'republic of suriname'],

  'belize': ['british honduras'],

  'guatemala': ['republic of guatemala'],

  'honduras': ['republic of honduras'],

  'nicaragua': ['nicaraugua', 'republic of nicaragua'],

  'panama': ['republic of panama'],

  'mexico': ['united mexican states', 'mejico'],

  'cuba': ['republic of cuba'],

  'haiti': ['republic of haiti', 'ayiti'],

  'jamaica': ['ja'],

  'bahamas': ['the bahamas', 'commonwealth of the bahamas'],

  'barbados': ['bados'],

  'grenada': ['island of grenada'],

  'dominica': ['commonwealth of dominica'],

  'canada': ['dominion of canada'],

  // ════════════════════════════════════════════════════════════════
  // OCEANIA
  // ════════════════════════════════════════════════════════════════

  'papua new guinea': ['png', 'pnginea', 'new guinea'],

  'new zealand': ['nz', 'aotearoa', 'new zeland'],

  'micronesia': [
    'federated states of micronesia',
    'fsm',
    'micronesia fsm',
  ],

  'marshall islands': [
    'rmi',
    'marshall is',
    'republic of the marshall islands',
  ],

  'solomon islands': [
    'solomon is',
    'solomons',
    'solomon island',
  ],

  'cook is': ['cook islands', 'cooks'],

  'faroe islands': [
    'faroe is',
    'faroes',
    'faeroe islands',
    'faeroe is',
    'faeroes',
  ],

  'falkland islands': [
    'falkland is',
    'falklands',
    'malvinas',
    'islas malvinas',
  ],

  'vanuatu': ['republic of vanuatu', 'new hebrides'],

  'samoa': ['independent state of samoa', 'western samoa'],

  'tonga': ['kingdom of tonga'],

  'tuvalu': ['ellice islands'],

  'nauru': ['republic of nauru'],

  'kiribati': ['republic of kiribati', 'gilbert islands'],

  'palau': ['republic of palau', 'belau'],

  'niue': ['republic of niue'],

  'fiji': ['republic of fiji', 'viti'],

  'australia': ['austrailia', 'australa', 'commonwealth of australia'],

  // ════════════════════════════════════════════════════════════════
  // TERRITORIES / SPECIAL
  // ════════════════════════════════════════════════════════════════

  'guam': ['territory of guam'],

  'puerto rico': ['pr', 'commonwealth of puerto rico'],

  'bermuda': ['bermudas'],

  'aruba': ['island of aruba'],

  'curacao': ['curacao island', 'willemstad'],

  'greenland': ['kalaallit nunaat'],

  'new caledonia': ['nouvelle caledonie', 'new cal'],

  'isle of man': ['iom', 'man'],

  'jersey': ['bailiwick of jersey'],

  'guernsey': ['bailiwick of guernsey'],

  'gibraltar': ['rock of gibraltar', 'the rock'],

  // ════════════════════════════════════════════════════════════════
  // COMMON GLOBAL TYPOS (additional, beyond above)
  // ════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════
  // US STATES
  // ════════════════════════════════════════════════════════════════

  'connecticut': ['conneticut', 'connnecticut'],
  'massachusetts': ['massachussets', 'massachussetts', 'masachusetts'],
  'mississippi': ['missisippi', 'mississipi'],
  'tennessee': ['tennesee', 'tennesse'],
  'pennsylvania': ['pensilvania', 'pensylvania'],
  'louisiana': ['louisianna'],
  'minnesota': ['minnisota', 'minnesotta'],
  'wisconsin': ['wisconson', 'wiscosin'],
  'michigan': ['michagan', 'michigen'],
  'illinois': ['ilinois', 'illinios'],
  'arkansas': ['arkansaw'],
  'california': ['californa'],
  'new hampshire': ['newhampshire'],
  'new jersey': ['newjersey'],
  'new mexico': ['newmexico'],
  'new york': ['newyork'],
  'north carolina': ['n carolina', 'northcarolina'],
  'south carolina': ['s carolina', 'southcarolina'],
  'north dakota': ['n dakota', 'northdakota'],
  'south dakota': ['s dakota', 'southdakota'],
  'west virginia': ['westvirginia', 'w virginia'],
  'rhode island': ['rhodeisland'],
  'district of columbia': ['dc', 'washington dc'],

  // ════════════════════════════════════════════════════════════════
  // UK COUNTIES — TRADITIONAL SHIRES
  // ════════════════════════════════════════════════════════════════

  'buckinghamshire': ['bucks'],
  'cambridgeshire': ['cambs'],
  'gloucestershire': ['glos', 'glostershire'],
  'hampshire': ['hants'],
  'hertfordshire': ['herts'],
  'lancashire': ['lancs'],
  'leicestershire': ['leics'],
  'northamptonshire': ['northants'],
  'nottinghamshire': ['notts'],
  'oxfordshire': ['oxon'],
  'staffordshire': ['staffs'],
  'warwickshire': ['warks'],
  'worcestershire': ['worcs'],
  'yorkshire': ['yorks'],

  // ════════════════════════════════════════════════════════════════
  // UK COUNTIES — SPECIFIC GAME ENTRIES
  // ════════════════════════════════════════════════════════════════

  'isle of anglesey': [
    'anglesey',
    'anglsey',
    'anglsea',
    'anglesea',
    'anglesy',
    'ynys mon',
  ],

  'county antrim': ['antrim', 'co antrim'],
  'county armagh': ['armagh', 'co armagh'],
  'county down': ['down', 'co down'],
  'county durham': ['durham', 'co durham'],
  'county fermanagh': ['fermanagh', 'co fermanagh'],
  'county londonderry': [
    'londonderry',
    'derry',
    'co londonderry',
    'co derry',
  ],
  'county tyrone': ['tyrone', 'co tyrone'],

  'east ayrshire': ['e ayrshire', 'ayrshire'],
  'north ayrshire': ['n ayrshire'],
  'south ayrshire': ['s ayrshire'],

  'east dunbartonshire': ['e dunbartonshire', 'dunbartonshire'],
  'west dunbartonshire': ['w dunbartonshire'],

  'east lothian': ['e lothian', 'lothian'],
  'west lothian': ['w lothian'],

  'east renfrewshire': ['e renfrewshire', 'renfrewshire'],

  'east riding of yorkshire': [
    'east riding',
    'e riding',
    'e riding of yorkshire'
  ],

  'north yorkshire': ['n yorkshire'],
  'south yorkshire': ['s yorkshire'],
  'west yorkshire': ['w yorkshire'],

  'north lanarkshire': ['n lanarkshire', 'lanarkshire'],
  'south lanarkshire': ['s lanarkshire'],

  'greater london': ['london', 'greater london authority'],
  'greater manchester': ['manchester'],

  'dumfries and galloway': [
    'dumfries',
    'galloway',
    'dumfries n galloway',
    'dumfries galloway',
  ],

  'perth and kinross': ['perth', 'kinross', 'perth n kinross', 'perth kinross'],

  'vale of glamorgan': ['glamorgan', 'y fro'],

  'neath port talbot': ['neath', 'port talbot'],

  'rhondda cynon taf': ['rhondda', 'rct', 'rhondda cynon taff'],

  'merthyr tydfil': ['merthyr'],

  'blaenau gwent': ['blaenau'],

  'argyll and bute': ['argyll', 'bute', 'argyll n bute', 'argyll bute'],

  'tyne and wear': ['tyne', 'tyneside', 'tyne n wear', 'tyne wear'],

  'eilean siar': ['western isles', 'outer hebrides', 'na h eileanan an iar'],

  'orkney islands': ['orkney', 'orkney is'],
  'shetland islands': ['shetland', 'shetland is', 'zetland'],
  'scottish borders': ['borders', 'the borders'],

  'city of edinburgh': ['edinburgh'],
  'aberdeen city': ['aberdeen'],
  'dundee city': ['dundee'],
  'glasgow city': ['glasgow'],

  // ════════════════════════════════════════════════════════════════
  // CANADIAN PROVINCES
  // ════════════════════════════════════════════════════════════════

  'newfoundland and labrador': [
    'newfoundland',
    'labrador',
    'nfld',
    'nl',
    'newfoundland n labrador',
    'newfoundland labrador',
  ],

  'prince edward island': [
    'pei',
    'prince edward is',
    'pei island',
    'the island',
  ],

  'northwest territories': ['nwt', 'northwest territory'],

  'british columbia': ['bc', 'b.c.'],

  'new brunswick': ['nb'],

  'nova scotia': ['ns'],
};
