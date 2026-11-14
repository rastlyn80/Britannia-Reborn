// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Spells;
using Server.Spells.Mysticism;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class Skree : BaseCreature
{
    [Constructible]
    public Skree() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 733;
        SetStr(297, 330);
        SetDex(96, 124);
        SetInt(188, 260);
        SetHits(205, 300);
        SetDamage(5, 7);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 55, 65);
        SetResistance(ResistanceType.Fire, 45, 55);
        SetResistance(ResistanceType.Cold, 25, 40);
        SetResistance(ResistanceType.Poison, 55, 65);
        SetResistance(ResistanceType.Energy, 25, 40);
        SetSkill(SkillName.EvalInt, 90.6, 115.0);
        SetSkill(SkillName.Magery, 90.2, 114.2);
        SetSkill(SkillName.Meditation, 65.3, 75.0);
        SetSkill(SkillName.MagicResist, 75.1, 90.0);
        SetSkill(SkillName.Tactics, 20.2, 24.7);
        SetSkill(SkillName.Wrestling, 101.9, 117.9);
        SetSkill(SkillName.Mysticism, 80.0, 105.0);
        SetSkill(SkillName.Parry, 75.0, 85.0);
        Tamable = true;
        ControlSlots = 4;
        MinTameSkill = 95.1;
    }

    public override string DefaultName => "a skree";
    public override string CorpseName => "a skree corpse";
    public override bool CanAngerOnTame => true;
    public override int Meat => 3;
    public override MeatType MeatType => MeatType.Bird;
    public override int Hides => 5;
    public override int GetIdleSound() => 1585;
    public override int GetAngerSound() => 1582;
    public override int GetHurtSound() => 1584;
    public override int GetDeathSound() => 1583;
    protected override BaseAI ForcedAI => new SkreeMysticAI(this);

    public override void GenerateLoot() => AddLoot(LootPack.Average);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    private sealed class SkreeMysticAI(BaseCreature creature) : MageAI(creature)
    {
        private bool CanMixMagery => !Mobile.Controlled && Mobile.Skills[SkillName.Magery].Base >= 20.0;

        public override bool Think()
        {
            if (Mobile.Target is ISpellTarget<IPoint3D> { Spell: HailStormSpell or NetherCycloneSpell } &&
                Mobile.Target is { } cursor && Mobile.Combatant is { } target &&
                Mobile.InRange(target, cursor.Range) && Mobile.CanSee(target) && Mobile.InLOS(target))
            {
                cursor.Invoke(Mobile, target);
                return true;
            }

            return base.Think();
        }

        public override Spell? ChooseSpell(Mobile target)
        {
            if (!Core.SA || CanMixMagery && Utility.RandomBool())
            {
                return base.ChooseSpell(target);
            }

            var mana = Mobile.Mana;
            var heal = new CleansingWindsSpell(Mobile, null);
            if (Mobile.Hits < Mobile.HitsMax / 2 && mana >= heal.GetMana())
            {
                return heal;
            }

            var curse = new SpellPlagueSpell(Mobile);
            if (mana >= curse.GetMana() && Utility.Random(6) == 0)
            {
                return curse;
            }

            Spell attack = Utility.Random(mana >= 50 ? 4 : mana >= 20 ? 2 : 1) switch
            {
                1 => new BombardSpell(Mobile, null),
                2 => new HailStormSpell(Mobile),
                3 => new NetherCycloneSpell(Mobile),
                _ => new EagleStrikeSpell(Mobile)
            };
            if (mana < attack.GetMana())
            {
                attack = new EagleStrikeSpell(Mobile);
            }

            return mana >= attack.GetMana() ? attack : null;
        }
    }
}
