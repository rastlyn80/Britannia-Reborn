"""Select one reviewed ModernUO constructor per source-backed wire-route body."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FAMILY = 'classic_wire_aliases'
CONSTRUCTORS = {
    77: 'Kraken',
    74: 'Imp',
    9: 'Daemon',
    62: 'Wyvern',
    26: 'Wraith',
    60: 'Drake',
    250: 'TsukiWolf',
    240: 'Kappa',
    317: 'VampireBat',
    128: 'Pixie',
    775: 'PlagueBeast',
    154: 'Mummy',
    40: 'Balron',
    148: 'SkeletalMage',
    245: 'YomotsuWarrior',
    11: 'DreadSpider',
    59: 'Dragon',
    86: 'OphidianWarrior',
    75: 'Cyclops',
    76: 'Titan',
    85: 'OphidianMage',
    71: 'TerathanDrone',
    70: 'TerathanWarrior',
    302: 'SkitteringHopper',
    247: 'FanDancer',
    87: 'OphidianMatriarch',
    149: 'Succubus',
    776: 'HordeMinion',
    67: 'StoneGargoyle',
    778: 'GazerLarva',
    805: 'BlackSolenWorker',
    152: 'TerathanAvenger',
    780: 'BogThing',
    789: 'Quagmire',
    784: 'ArcaneDaemon',
    772: 'MeerEternal',
    267: 'Troglodyte',
    304: 'FleshGolem',
    46: 'AncientWyrm',
    756: 'ExodusOverseer',
    252: 'LadyOfTheSnow',
    271: 'Satyr',
    280: 'MinotaurCaptain',
    43: 'IceFiend',
    768: 'Juggernaut',
    307: 'Gibberling',
    807: 'BlackSolenQueen',
    249: 'Yamandon',
    308: 'BoneDemon',
    103: 'SerpentineDragon',
    104: 'SkeletalDragon',
    10: 'SummonedDaemon',
    38: 'ServantOfSemidar',
    101: 'Centaur',
    174: 'Semidar',
    262: 'TormentedMinotaur',
    306: 'Impaler',
    311: 'ShadowKnight',
    312: 'AbysmalHorror',
    313: 'DarknightCreeper',
    314: 'Ravager',
    315: 'FleshRenderer',
    316: 'WandererOfTheVoid',
    318: 'DemonKnight',
    319: 'MoundOfMaggots',
    758: 'Provisioner',
    50: 'Skeleton',
    53: 'Troll',
    54: 'Troll',
    42: 'Ratman',
    39: 'Mongbat',
    30: 'Harpy',
    21: 'GiantSerpent',
    1: 'Ogre',
    3: 'Zombie',
    4: 'Gargoyle',
    14: 'EarthElemental',
    48: 'Scorpion',
    55: 'FrostTroll',
}


def prepared(entries):
    table = json.loads((ROOT / 'Viewer/Presentation/creature-wire-routes.json').read_text(encoding='utf-8'))
    assert set(map(int, table)) == CONSTRUCTORS.keys()
    owners = {int(identity['body']): row for row in entries if row['status'] == 'validated' for identity in row['bodies']}
    rows = []
    for key in table:
        body = int(key)
        name = CONSTRUCTORS[body]
        base = owners[body]
        identity, = (item for item in base['bodies'] if int(item['body']) == body)
        row = dict(base, bodies=[identity], family=FAMILY, status='prepared')
        row.pop('native_constructor_hues', None)
        row.pop('native_constructor_hue_ranges', None)
        rows.append(row)
    return rows, {body: [name] for body, name in CONSTRUCTORS.items()}
