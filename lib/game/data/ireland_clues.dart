/// Regional clue data for all 32 counties of Ireland (Republic + Northern Ireland)
library;

class CountyClueData {
  const CountyClueData({
    required this.province,
    required this.gaelicName,
    required this.famousPerson,
    required this.famousLandmark,
    required this.gaaTeam,
    required this.nickname,
  });

  final String province;
  final String gaelicName;
  final String famousPerson;
  final String famousLandmark;
  final String gaaTeam;
  final String nickname;
}

abstract class IrelandClues {
  static const Map<String, CountyClueData> data = {
    // LEINSTER
    'D': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Baile Átha Cliath',
      famousPerson: 'James Joyce',
      famousLandmark: 'GPO on O\'Connell Street',
      gaaTeam: 'The Dubs (Sky Blue)',
      nickname: 'The Pale',
    ),
    'WW': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Mhantáin',
      famousPerson: 'Katie Taylor',
      famousLandmark: 'Glendalough Monastic Site',
      gaaTeam: 'The Garden County (Blue & Gold)',
      nickname: 'The Garden of Ireland',
    ),
    'WX': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Loch Garman',
      famousPerson: 'John Barry, father of US Navy',
      famousLandmark: 'Hook Lighthouse',
      gaaTeam: 'The Model County (Purple & Gold)',
      nickname: 'The Model County',
    ),
    'KK': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Chainnigh',
      famousPerson: 'Henry Shefflin',
      famousLandmark: 'Kilkenny Castle',
      gaaTeam: 'The Cats (Black & Amber)',
      nickname: 'The Marble City',
    ),
    'CW': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Ceatharlach',
      famousPerson: 'Pierce Brosnan',
      famousLandmark: 'Brownshill Dolmen',
      gaaTeam: 'The Scallion Eaters (Green, Red & Yellow)',
      nickname: 'The Dolmen County',
    ),
    'KE': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Dara',
      famousPerson: 'Christy Moore',
      famousLandmark: 'The Curragh Racecourse',
      gaaTeam: 'The Lilywhites (White)',
      nickname: 'The Thoroughbred County',
    ),
    'MH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Mhí',
      famousPerson: 'Pierce Brosnan',
      famousLandmark: 'Newgrange',
      gaaTeam: 'The Royals (Green & Gold)',
      nickname: 'The Royal County',
    ),
    'WH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Iarmhí',
      famousPerson: 'Niall Horan',
      famousLandmark: 'Athlone Castle',
      gaaTeam: 'The Lake County (Maroon & White)',
      nickname: 'The Lake County',
    ),
    'LS': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Laois',
      famousPerson: 'Jack Charlton (lived there)',
      famousLandmark: 'Rock of Dunamase',
      gaaTeam: 'The O\'Moore County (Blue & White)',
      nickname: 'The O\'Moore County',
    ),
    'OY': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Uíbh Fhailí',
      famousPerson: 'Shane Lowry',
      famousLandmark: 'Clonmacnoise',
      gaaTeam: 'The Faithful County (Green, White & Gold)',
      nickname: 'The Faithful County',
    ),
    'LD': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Longfort',
      famousPerson: 'Padraic Colum',
      famousLandmark: 'Corlea Trackway',
      gaaTeam: 'The Slashers (Blue & Gold)',
      nickname: 'The Midlands',
    ),
    'LH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Lú',
      famousPerson: 'Pierce Brosnan (born there)',
      famousLandmark: 'Proleek Dolmen',
      gaaTeam: 'The Wee County (Red)',
      nickname: 'The Wee County',
    ),

    // MUNSTER
    'C': CountyClueData(
      province: 'Munster',
      gaelicName: 'Corcaigh',
      famousPerson: 'Michael Collins',
      famousLandmark: 'Blarney Castle',
      gaaTeam: 'The Rebels (Red & White)',
      nickname: 'The Rebel County',
    ),
    'KY': CountyClueData(
      province: 'Munster',
      gaelicName: 'Ciarraí',
      famousPerson: 'Brendan Gleeson',
      famousLandmark: 'Gap of Dunloe',
      gaaTeam: 'The Kingdom (Green & Gold)',
      nickname: 'The Kingdom',
    ),
    'L': CountyClueData(
      province: 'Munster',
      gaelicName: 'Luimneach',
      famousPerson: 'Richard Harris',
      famousLandmark: 'King John\'s Castle',
      gaaTeam: 'The Treaty County (Green & White)',
      nickname: 'The Treaty City',
    ),
    'CE': CountyClueData(
      province: 'Munster',
      gaelicName: 'An Clár',
      famousPerson: 'Edna O\'Brien',
      famousLandmark: 'Cliffs of Moher',
      gaaTeam: 'The Banner County (Saffron & Blue)',
      nickname: 'The Banner County',
    ),
    'T': CountyClueData(
      province: 'Munster',
      gaelicName: 'Tiobraid Árann',
      famousPerson: 'Eamonn de Valera',
      famousLandmark: 'Rock of Cashel',
      gaaTeam: 'The Premier County (Blue & Gold)',
      nickname: 'The Premier County',
    ),
    'W': CountyClueData(
      province: 'Munster',
      gaelicName: 'Port Láirge',
      famousPerson: 'Val Doonican',
      famousLandmark: 'Waterford Crystal Factory',
      gaaTeam: 'The Déise (White & Blue)',
      nickname: 'The Déise',
    ),

    // CONNACHT
    'G': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Gaillimh',
      famousPerson: 'Noel Purcell',
      famousLandmark: 'Connemara National Park',
      gaaTeam: 'The Tribesmen (Maroon & White)',
      nickname: 'The City of the Tribes',
    ),
    'MO': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Maigh Eo',
      famousPerson: 'Michael Davitt',
      famousLandmark: 'Croagh Patrick',
      gaaTeam: 'The Green & Red',
      nickname: 'The Heather County',
    ),
    'SO': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Sligeach',
      famousPerson: 'W.B. Yeats',
      famousLandmark: 'Ben Bulben',
      gaaTeam: 'The Yeats County (Black & White)',
      nickname: 'The Yeats County',
    ),
    'RN': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Ros Comáin',
      famousPerson: 'Maureen O\'Sullivan',
      famousLandmark: 'Strokestown Park House',
      gaaTeam: 'The Rossies (Primrose & Blue)',
      nickname: 'The Rossies',
    ),
    'LM': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Liatroim',
      famousPerson: 'Seán Mac Diarmada',
      famousLandmark: 'Glencar Waterfall',
      gaaTeam: 'Green & Gold',
      nickname: 'The Wild Rose County',
    ),

    // ULSTER (Republic of Ireland)
    'DL': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Dún na nGall',
      famousPerson: 'Daniel O\'Donnell',
      famousLandmark: 'Slieve League Cliffs',
      gaaTeam: 'The Tír Chonaill (Green & Gold)',
      nickname: 'The Forgotten County',
    ),
    'CN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'An Cabhán',
      famousPerson: 'Percy French',
      famousLandmark: 'Cuilcagh Mountain',
      gaaTeam: 'The Breffni County (Blue & White)',
      nickname: 'The Breffni County',
    ),
    'MN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Muineachán',
      famousPerson: 'Patrick Kavanagh',
      famousLandmark: 'Rossmore Forest Park',
      gaaTeam: 'The Farney County (White & Blue)',
      nickname: 'The Farney County',
    ),

    // ULSTER (Northern Ireland)
    'ANT': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Aontroim',
      famousPerson: 'C.S. Lewis',
      famousLandmark: 'Giant\'s Causeway',
      gaaTeam: 'The Saffrons (Saffron & White)',
      nickname: 'The Glens',
    ),
    'ARM': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Ard Mhacha',
      famousPerson: 'Saint Patrick',
      famousLandmark: 'Navan Fort',
      gaaTeam: 'The Orchard County (Orange & White)',
      nickname: 'The Orchard County',
    ),
    'DWN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'An Dún',
      famousPerson: 'Van Morrison',
      famousLandmark: 'Mourne Mountains',
      gaaTeam: 'The Mourne County (Red & Black)',
      nickname: 'The Mourne County',
    ),
    'FRM': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Fear Manach',
      famousPerson: 'Adrian Dunbar',
      famousLandmark: 'Marble Arch Caves',
      gaaTeam: 'The Erne County (Green & White)',
      nickname: 'The Lakeland County',
    ),
    'LDY': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Doire',
      famousPerson: 'Seamus Heaney',
      famousLandmark: 'Derry City Walls',
      gaaTeam: 'The Oak Leaf County (Red & White)',
      nickname: 'The Maiden City',
    ),
    'TYR': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Tír Eoghain',
      famousPerson: 'Brian Friel',
      famousLandmark: 'Ulster American Folk Park',
      gaaTeam: 'The Red Hand County (White & Red)',
      nickname: 'The Red Hand County',
    ),
  };
}
