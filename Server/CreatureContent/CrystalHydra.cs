// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Spells;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class CrystalHydra : BaseCreature
{
    private static readonly MonsterAbility[] Abilities = [new CrystalHydraBreath()];

    [Constructible]
    public CrystalHydra() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 0x109;
        Hue = 0x47E;
        BaseSoundID = 0x16A;
        SetStr(800, 830);
        SetDex(100, 120);
        SetInt(100, 120);
        SetHits(1450, 1500);
        SetDamage(21, 26);
        SetDamageType(ResistanceType.Physical, 5);
        SetDamageType(ResistanceType.Fire, 5);
        SetDamageType(ResistanceType.Cold, 80);
        SetDamageType(ResistanceType.Poison, 5);
        SetDamageType(ResistanceType.Energy, 5);
        SetResistance(ResistanceType.Physical, 65, 75);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 80, 100);
        SetResistance(ResistanceType.Poison, 35, 45);
        SetResistance(ResistanceType.Energy, 80, 100);
        SetSkill(SkillName.Wrestling, 100.0, 120.0);
        SetSkill(SkillName.Tactics, 100.0, 110.0);
        SetSkill(SkillName.MagicResist, 80.0, 100.0);
        SetSkill(SkillName.Anatomy, 70.0, 80.0);
        Fame = 17000;
        Karma = -17000;
        if (Utility.RandomBool())
        {
            PackItem(Loot.RandomScroll(0, Loot.ArcanistScrollTypes.Length - 1, SpellbookType.Arcanist));
        }
    }

    public override string DefaultName => "a crystal hydra";
    public override string CorpseName => "a crystal hydra corpse";
    public override int Hides => 40;
    public override int Meat => 19;
    public override int TreasureMapLevel => 5;
    public override MonsterAbility[] GetMonsterAbilities() => Abilities;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.UltraRich, 2);
        AddLoot(LootPack.HighScrolls);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        corpse.DropItem(new CrystallineFragments());
        if (Utility.RandomDouble() < 0.25)
        {
            corpse.DropItem(new ShatteredCrystals());
        }
    }

    private sealed class CrystalHydraBreath : ColdBreath
    {
        public override double ChanceToTrigger => 0.10;
        public override TimeSpan MinTriggerCooldown => TimeSpan.FromSeconds(5);
        public override TimeSpan MaxTriggerCooldown => TimeSpan.FromSeconds(7);
        public override double BreathDamageScalar => 0.13;
        public override int BreathEffectHue => 0x47E;
        public override int BreathEffectSound => 0x56D;
        public override int BreathRange(BaseCreature source) => 12;

        public override void Trigger(MonsterAbilityTrigger trigger, BaseCreature source, Mobile target)
        {
            if (source.Mana < 30 || !CanFireBreathTarget(source, target))
            {
                return;
            }
            source.Mana -= 30;
            source.RevealingAction();
            var others = new List<Mobile>();
            foreach (var candidate in source.Map.GetMobilesInRange(target.Location, 5))
            {
                if (candidate != source && candidate != target &&
                    IsSecondaryTarget(source, candidate) && CanFireBreathTarget(source, candidate))
                {
                    others.Add(candidate);
                }
            }
            base.Trigger(trigger, source, target);
            for (var shot = 0; shot < 4 && others.Count > 0; shot++)
            {
                var index = Utility.Random(others.Count);
                var next = others[index];
                others.RemoveAt(index);
                Timer.StartTimer(TimeSpan.FromSeconds(BreathEffectDelay), () =>
                {
                    if (source is { Alive: true, Deleted: false } && CanFireBreathTarget(source, next))
                    {
                        BreathEffect_Callback(source, next);
                    }
                });
            }
        }

        private static bool IsSecondaryTarget(BaseCreature source, Mobile candidate) =>
            !source.Controlled && !source.Summoned
                ? source.IsEnemy(candidate)
                : SpellHelper.ValidIndirectTarget(source, candidate);
    }
}
