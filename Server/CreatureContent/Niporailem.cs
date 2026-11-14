// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Spells;
using Server.Spells.Necromancy;

namespace Server.Mobiles;

[SerializationGenerator(1)]
public sealed partial class Niporailem : TombGuardian
{
    [SerializableField(0)]
    private List<BaseCreature> _defenders = [];

    [SerializableField(1)]
    private DateTime _nextTreasure;

    [SerializableField(2)]
    private DateTime _nextDefender;

    [SerializableField(3)]
    private bool _secondThrow;

    [SerializableField(4)]
    private DateTime _nextCurse;

    [Constructible]
    public Niporailem()
    {
        Title = "the Thief";
        SetStr(1000);
        SetDex(1200);
        SetInt(1200);
        SetHits(10000, 10500);
        SetDamage(15, 27);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Cold, 40);
        SetDamageType(ResistanceType.Energy, 40);
        SetResistance(ResistanceType.Physical, 34, 46);
        SetResistance(ResistanceType.Fire, 0);
        SetResistance(ResistanceType.Cold, 31, 49);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 31, 49);
        SetSkill(SkillName.Wrestling, 68.8, 85.0);
        SetSkill(SkillName.Tactics, 56.1, 90.0);
        SetSkill(SkillName.MagicResist, 87.7, 93.5);
        SetSkill(SkillName.EvalInt, 90.0, 100.0);
        SetSkill(SkillName.Magery, 90.0, 100.0);
        SetSkill(SkillName.Necromancy, 120.0);
        SetSkill(SkillName.SpiritSpeak, 120.0);
        Fame = 15000;
        Karma = -15000;
    }

    public override string DefaultName => "Niporailem";
    public override string CorpseName => "the corpse of Niporailem";
    public override bool AlwaysMurderer => true;
    protected override BaseAI ForcedAI => new ThiefMageAI(this);

    public override void GenerateLoot()
    {
        AddLoot(LootPack.FilthyRich, 6);
        AddLoot(LootPack.Gems, 6);
    }

    public override void OnActionCombat()
    {
        base.OnActionCombat();
        if (_nextTreasure > Core.Now || Combatant is not PlayerMobile player || !player.Alive ||
            player.Map != Map || !InRange(player, 12) || !InLOS(player) || !CanBeHarmful(player, false))
        {
            return;
        }

        _secondThrow = !_secondThrow && Utility.RandomDouble() < .75;
        _nextTreasure = Core.Now + TimeSpan.FromSeconds(_secondThrow ? 3 : Utility.RandomMinMax(5, 15));
        this.MarkDirty();

        DoHarmful(player);
        this.MovingParticles(player, 0x0EEF, 9, 0, false, true, 0, 0, 9502, 6014, 0x11D, EffectLayer.Waist, 0);
        Timer.DelayCall(TimeSpan.FromSeconds(1), () => LandGold(player));
    }

    private void LandGold(PlayerMobile player)
    {
        if (Deleted || !Alive || !player.Alive || player.Map != Map || !InRange(player, 12) ||
            !CanBeHarmful(player, false) || player.Backpack is not { } pack)
        {
            return;
        }

        if (player.Hidden)
        {
            SummonCursedDefender(player);
        }

        pack.DropItem(new FoolsGold(this, player));
        BaseMount.Dismount(player);
        player.PlaySound(0x033);
        player.SendLocalizedMessage(1112111);
        AOS.Damage(player, this, Utility.RandomMinMax(8, 14), 100, 0, 0, 0, 0);
    }

    public override void OnGotMeleeAttack(Mobile attacker, int damage)
    {
        base.OnGotMeleeAttack(attacker, damage);
        if (_nextDefender <= Core.Now && Utility.RandomDouble() < (Hits > HitsMax / 4 ? .25 : .10))
        {
            SummonDefender(attacker, false);
        }
    }

    internal void SummonCursedDefender(Mobile target) => SummonDefender(target, true);

    private void SummonDefender(Mobile target, bool cursed)
    {
        ref var cooldown = ref (cursed ? ref _nextCurse : ref _nextDefender);
        if (Deleted || !Alive || !target.Alive || target.Map != Map || !InRange(target, 15) || Map == null ||
            cooldown > Core.Now)
        {
            return;
        }

        _defenders.RemoveAll(mobile => mobile == null || mobile.Deleted);
        if (_defenders.Count >= 10)
        {
            return;
        }

        var placement = Location;
        for (var attempt = 0; attempt < 10; attempt++)
        {
            var near = new Point3D(X + Utility.RandomMinMax(-2, 2), Y + Utility.RandomMinMax(-2, 2), Z);
            if (Map.CanFit(near, 16))
            {
                placement = near;
                break;
            }
        }

        BaseCreature helper = cursed
            ? Utility.RandomBool() ? new CursedMetallicKnight() : new CursedMetallicMage()
            : new SpectralArmour();
        helper.Team = Team;
        helper.Home = placement;
        helper.RangeHome = 10;
        helper.MoveToWorld(placement, Map);
        helper.Combatant = target;
        _defenders.Add(helper);
        cooldown = Core.Now + TimeSpan.FromSeconds(Utility.RandomMinMax(30, 60));
        this.MarkDirty();
        target.SendLocalizedMessage(1112114);
    }

    public override void OnDeath(Container corpse)
    {
        DismissDefenders();
        base.OnDeath(corpse);
    }

    public override void OnDelete()
    {
        DismissDefenders();
        base.OnDelete();
    }

    private void DismissDefenders()
    {
        foreach (var mobile in _defenders)
        {
            mobile?.Delete();
        }
        _defenders.Clear();
    }

    private void MigrateFrom(V0Content content)
    {
        _defenders.AddRange(content.Defenders);
        _nextTreasure = content.NextTreasure;
        _nextDefender = content.NextDefender;
        _secondThrow = content.SecondThrow;
    }

    private sealed class ThiefMageAI(BaseCreature mobile) : MageAI(mobile)
    {
        public override Spell ChooseSpell(Mobile target) =>
            Mobile.Mana >= 29 && Utility.RandomDouble() < .2 ? new StrangleSpell(Mobile) : base.ChooseSpell(target);
    }
}
