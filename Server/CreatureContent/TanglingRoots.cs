// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Spells;
using Server.Spells.Spellweaving;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class TanglingRoots : BaseCreature
{
    private readonly Dictionary<PlayerMobile, Timer> _acid = new();

    [Constructible]
    public TanglingRoots() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 8;
        BaseSoundID = 684;
        CantWalk = true;
        SetStr(157, 189);
        SetDex(51, 64);
        SetInt(26, 39);
        SetHits(231, 246);
        SetMana(0);
        SetDamage(10, 23);
        SetDamageType(ResistanceType.Physical, 60);
        SetDamageType(ResistanceType.Poison, 40);
        SetResistance(ResistanceType.Physical, 35, 40);
        SetResistance(ResistanceType.Cold, 10, 20);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 10, 20);
        SetSkill(SkillName.MagicResist, 15.1, 20.0);
        SetSkill(SkillName.Tactics, 45.1, 60.0);
        SetSkill(SkillName.Wrestling, 45.1, 60.0);
        Fame = 3000;
        Karma = -3000;
        VirtualArmor = 18;
        PackItem(Utility.RandomDouble() < 0.25 ? new Board(10) : new Log(10));
        PackItem(new MandrakeRoot(3));
    }

    public override string DefaultName => "a tangling root";
    public override string CorpseName => "a tangling root corpse";
    public override Poison PoisonImmune => Poison.Lesser;
    public override bool DisallowAllMoves => true;
    public override OppositionGroup OppositionGroup => OppositionGroup.FeyAndUndead;
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich);

    public override void OnMovement(Mobile mobile, Point3D previous)
    {
        base.OnMovement(mobile, previous);
        if (Deleted || !Alive || mobile is not PlayerMobile player || !CanCatch(player, 6))
        {
            return;
        }

        if (!player.Frozen && Utility.RandomDouble() < 0.2 && player.BeginAction(typeof(TanglingRoots)))
        {
            var hold = TimeSpan.FromSeconds(Utility.RandomMinMax(3, 6));
            player.Freeze(hold);
            player.MoveToWorld(Location, Map);
            player.PlaySound(0x1FE);
            player.SendLocalizedMessage(1111641);
            Timer.DelayCall(hold, static target =>
            {
                if (target is { Deleted: false, Alive: true })
                {
                    target.SendLocalizedMessage(1111642);
                }
            }, player);
            Timer.DelayCall(TimeSpan.FromSeconds(15), static target =>
                target.EndAction(typeof(TanglingRoots)), player);
        }

        if (player.InRange(this, 1) && !_acid.ContainsKey(player))
        {
            _acid[player] = Timer.DelayCall(TimeSpan.Zero, TimeSpan.FromSeconds(1), AcidTick, player);
        }
    }

    private bool CanCatch(PlayerMobile player, int range) =>
        player is { Deleted: false, Alive: true, Hidden: false, AccessLevel: AccessLevel.Player } &&
        player.Map == Map && player.InRange(this, range) && CanSee(player) && InLOS(player) &&
        CanBeHarmful(player, false) && !TransformationSpellHelper.UnderTransformation(player, typeof(EtherealVoyageSpell));

    private void AcidTick(PlayerMobile player)
    {
        if (Deleted || !Alive || !CanCatch(player, 1))
        {
            if (_acid.Remove(player, out var timer))
            {
                timer.Stop();
            }
            return;
        }

        player.Damage(4, this);
        player.SendLocalizedMessage(1111643);
    }

    private void StopAcid()
    {
        foreach (var timer in _acid.Values)
        {
            timer.Stop();
        }
        _acid.Clear();
    }

    public override bool OnBeforeDeath()
    {
        if (!base.OnBeforeDeath())
        {
            return false;
        }
        StopAcid();
        return true;
    }

    public override void OnDelete()
    {
        StopAcid();
        base.OnDelete();
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
