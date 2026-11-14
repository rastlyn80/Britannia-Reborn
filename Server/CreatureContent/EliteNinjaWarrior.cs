// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;
using Server.Items;
using Server.Spells;
using Server.Spells.Necromancy;
using Server.Spells.Ninjitsu;

namespace Server.Mobiles;

[SerializationGenerator(0)]
[TypeAlias("Server.Mobiles.EliteNinja")]
public partial class EliteNinjaWarrior : BaseCreature
{
    private long _nextWeaponChange = Core.TickCount;
    private long _nextTechnique = Core.TickCount;
    private long _nextProjectile = Core.TickCount;
    private long _nextHide = Core.TickCount;
    private TimerExecutionToken _projectile;

    [Constructible]
    public EliteNinjaWarrior() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Female = Utility.RandomBool();
        Body = Race.Human.Body(this);
        Hue = Race.RandomSkinHue();
        SpeechHue = Utility.RandomDyedHue();
        Utility.AssignRandomHair(this);

        Fame = 8500;
        Karma = -8500;
        SetStr(126, 225);
        SetDex(81, 95);
        SetInt(151, 165);
        SetHits(251, 350);
        SetDamage(12, 20);
        SetDamageType(ResistanceType.Physical, 65);
        SetDamageType(ResistanceType.Fire, 15);
        SetDamageType(ResistanceType.Poison, 15);
        SetDamageType(ResistanceType.Energy, 5);
        SetResistance(ResistanceType.Physical, 35, 65);
        SetResistance(ResistanceType.Fire, 40, 60);
        SetResistance(ResistanceType.Cold, 25, 45);
        SetResistance(ResistanceType.Poison, 40, 60);
        SetResistance(ResistanceType.Energy, 35, 55);
        SetSkill(SkillName.Anatomy, 105.0, 120.0);
        SetSkill(SkillName.MagicResist, 80.0, 100.0);
        SetSkill(SkillName.Tactics, 115.0, 130.0);
        SetSkill(SkillName.Wrestling, 95.0, 120.0);
        SetSkill(SkillName.Fencing, 95.0, 120.0);
        SetSkill(SkillName.Macing, 95.0, 120.0);
        SetSkill(SkillName.Swords, 95.0, 120.0);
        SetSkill(SkillName.Ninjitsu, 95.0, 120.0);
        SetSkill(SkillName.Hiding, 100.0);
        SetSkill(SkillName.Stealth, 120.0);

        AddItem(new NinjaTabi());
        AddItem(new LeatherNinjaJacket());
        AddItem(new LeatherNinjaHood());
        AddItem(new LeatherNinjaPants());
        AddItem(new LeatherNinjaMitts());
        AddItem(new LeatherNinjaBelt { UsesRemaining = 20, PoisonCharges = 20, Poison = Poison.Greater, Movable = false });

        var fukiyaCount = Skills.Ninjitsu.Value >= 100.0 ? 2 : 1;
        for (var index = 0; index < fukiyaCount; index++)
        {
            PackItem(new Fukiya
            {
                UsesRemaining = 10, PoisonCharges = 10, Poison = fukiyaCount == 2 ? Poison.Greater : Poison.Regular,
                Movable = false
            });
        }
        if (Utility.RandomDouble() < 0.33)
        {
            PackItem(new SmokeBomb());
        }

        PackItem(Utility.RandomBool() ? new Tessen() : new Wakizashi());
        PackItem(Utility.RandomBool() ? new Nunchaku() : new Daisho());
        PackItem(Utility.RandomBool() ? new Sai() : new Tekagi());
        PackItem(Utility.RandomBool() ? new Kama() : new Katana());
        EquipAnotherWeapon();
    }

    public override string DefaultName => "an elite ninja";
    public override string CorpseName => "an elite ninja corpse";
    public override bool BardImmune => true;
    public override bool AlwaysMurderer => true;
    public override bool ClickTitle => false;

    public override void OnThink()
    {
        base.OnThink();
        if (!Alive || BardPacified || Map == Map.Internal)
        {
            return;
        }

        var now = Core.TickCount;
        if (Combatant is not { Alive: true } target || target.Map != Map)
        {
            TryHide(now);
            return;
        }
        if (now - _nextWeaponChange >= 0)
        {
            EquipAnotherWeapon();
        }
        if (now - _nextTechnique >= 0 && SpecialMove.GetCurrentMove(this) == null && Utility.RandomDouble() < 0.05)
        {
            PrepareTechnique(now);
        }
        if (now - _nextProjectile >= 0 && Utility.RandomDouble() < 0.08)
        {
            TryUseProjectile(target, now);
        }
    }

    private void TryHide(long now)
    {
        if (Hidden || now - _nextHide < 0 || now - NextSkillTime < 0)
        {
            return;
        }

        _nextHide = now + 1000;
        var chance = Poisoned ? 0.01 : Hits < 20 ? 0.10 : 0.05;
        if (Utility.RandomDouble() >= chance)
        {
            return;
        }

        FixedParticles(0x3728, 10, 10, 2023, EffectLayer.Waist);
        PlaySound(0x22F);
        Hidden = true;
        UseSkill(SkillName.Stealth);
    }

    private void PrepareTechnique(long now)
    {
        _nextTechnique = now + 15000;
        if (Utility.RandomDouble() < 0.05 && !MirrorImage.HasClone(this))
        {
            new MirrorImage(this, null).Cast();
            return;
        }

        var id = Hidden ? Utility.RandomMinMax(504, 505) : Utility.Random(3) switch
        {
            0 => 500,
            1 => 503,
            _ => 501
        };
        if (SpellRegistry.GetSpecialMove(id) is { } move)
        {
            SpecialMove.SetCurrentMove(this, move);
        }
    }

    private void TryUseProjectile(Mobile target, long now)
    {
        if (!CanBeHarmful(target) || !CanSee(target) || !InLOS(target) || Spell != null)
        {
            return;
        }

        var range = (int)this.GetDistanceToSqrt(target.Location);
        INinjaWeapon? selected = null;
        var count = 0;
        Consider(FindItemOnLayer(Layer.Waist));
        if (Backpack != null)
        {
            foreach (var item in Backpack.Items)
            {
                Consider(item);
            }
        }
        if (selected == null)
        {
            return;
        }

        var weapon = selected;
        var poison = weapon.PoisonCharges > 0 ? weapon.Poison : null;
        weapon.UsesRemaining--;
        if (poison != null)
        {
            weapon.PoisonCharges--;
        }
        if (weapon.PoisonCharges <= 0 || weapon.UsesRemaining <= 0)
        {
            weapon.PoisonCharges = 0;
            weapon.Poison = null;
        }

        _nextProjectile = now + Utility.RandomMinMax(30000, 120000);
        Direction = GetDirectionTo(target);
        RevealingAction();
        weapon.AttackAnimation(this, target);
        var defense = target.Weapon is BaseWeapon defender ? defender.GetDefendSkillValue(this, target) : 0.0;
        var chance = Math.Clamp((Skills.Ninjitsu.Value + 20.0) / (2.0 * Math.Max(1.0, defense + 20.0)), 0.02, 1.0);
        if (CheckSkill(SkillName.Ninjitsu, chance))
        {
            Timer.StartTimer(TimeSpan.FromSeconds(1), () =>
            {
                if (!Alive || !target.Alive || Map != target.Map || !CanBeHarmful(target))
                {
                    return;
                }
                DoHarmful(target);
                AOS.Damage(target, this, weapon.WeaponDamage, 100, 0, 0, 0, 0);
                if (poison != null && target.Alive)
                {
                    target.ApplyPoison(this, EvilOmenSpell.EndEffect(target) ? Poison.IncreaseLevel(poison) : poison);
                }
            }, out _projectile);
        }

        void Consider(Item? item)
        {
            if (item is INinjaWeapon { UsesRemaining: > 0 } candidate &&
                range >= candidate.WeaponMinRange && range <= candidate.WeaponMaxRange && Utility.Random(++count) == 0)
            {
                selected = candidate;
            }
        }
    }

    private void EquipAnotherWeapon()
    {
        _nextWeaponChange = Core.TickCount + Utility.RandomMinMax(30000, 60000);
        if (Backpack == null)
        {
            return;
        }

        BaseWeapon? next = null;
        var candidateCount = 0;
        foreach (var item in Backpack.Items)
        {
            if (item is BaseWeapon candidate && Utility.Random(++candidateCount) == 0)
            {
                next = candidate;
            }
        }
        if (next == null)
        {
            return;
        }

        var previous = FindItemOnLayer(Layer.OneHanded) ?? FindItemOnLayer(Layer.TwoHanded);
        if (previous != null)
        {
            Backpack.DropItem(previous);
        }
        AddItem(next);
    }

    public override void OnDeath(Container corpse)
    {
        _projectile.Cancel();
        SpecialMove.ClearCurrentMove(this);
        base.OnDeath(corpse);
        corpse.DropItem(new BookOfNinjitsu());
    }

    public override void OnAfterDelete()
    {
        _projectile.Cancel();
        SpecialMove.ClearCurrentMove(this);
        base.OnAfterDelete();
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.FilthyRich);
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.Gems, 2);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
