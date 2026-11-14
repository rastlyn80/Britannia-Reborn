// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;
using Server.Items;
using Server.Spells;
using Server.Spells.Ninjitsu;

namespace Server.Mobiles;

[SerializationGenerator(1)]
public partial class Travesty : BaseCreature
{
    private static readonly Point3D[] ReinforcementPositions =
    [
        new(80, 1964, 0), new(80, 1949, 0), new(92, 1948, 0), new(92, 1962, 0)
    ];
    private static readonly Point3D[] RetreatPositions =
    [
        new(71, 1939, 0), new(71, 1955, 0), new(69, 1972, 0), new(86, 1971, 0),
        new(103, 1972, 0), new(86, 1939, 0), new(102, 1938, 0)
    ];
    private const string DisguiseTitle = "(Travesty)";
    private long _nextMorph = Core.TickCount;
    private long _nextMirror = Core.TickCount;
    private TimerExecutionToken _restoreDisguise;

    [SerializableField(0)]
    private bool _calledReinforcements;

    [SerializableField(1)]
    private bool _borrowedHealing;

    [SerializableField(2)]
    private System.Collections.Generic.List<BaseCreature> _reinforcements = [];

    internal CitadelKeyTable? KeyTable { get; set; }

    [Constructible]
    public Travesty() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 264;
        BaseSoundID = 0x46E;
        Fame = 30000;
        Karma = -30000;
        VirtualArmor = 50;
        SetStr(900, 950);
        SetDex(900, 950);
        SetInt(900, 950);
        SetHits(35000);
        SetDamage(11, 18);
        SetResistance(ResistanceType.Physical, 50, 70);
        SetResistance(ResistanceType.Fire, 50, 70);
        SetResistance(ResistanceType.Cold, 50, 70);
        SetResistance(ResistanceType.Poison, 50, 70);
        SetResistance(ResistanceType.Energy, 50, 70);
        SetSkill(SkillName.Wrestling, 300.0, 320.0);
        SetSkill(SkillName.Tactics, 100.0, 120.0);
        SetSkill(SkillName.Anatomy, 100.0, 120.0);
        SetSkill(SkillName.Healing, 100.0, 120.0);
        SetSkill(SkillName.Poisoning, 100.0, 120.0);
        SetSkill(SkillName.Parry, 100.0, 110.0);
        SetSkill(SkillName.MagicResist, 100.0, 120.0);
        SetSkill(SkillName.Magery, 100.0, 120.0);
        SetSkill(SkillName.EvalInt, 100.0, 120.0);
        SetSkill(SkillName.Meditation, 100.0, 120.0);
        SetSkill(SkillName.Necromancy, 100.0, 120.0);
        SetSkill(SkillName.SpiritSpeak, 100.0, 120.0);
        SetSkill(SkillName.Ninjitsu, 100.0, 120.0);
        SetSkill(SkillName.DetectHidden, 100.0);
        SetSkill(SkillName.Hiding, 100.0);
        SetSkill(SkillName.Focus, 100.0, 120.0);
        SetSkill(SkillName.Spellweaving, 100.0, 120.0);
        SetSkill(SkillName.Mysticism, 100.0, 120.0);
        SetSkill(SkillName.Bushido, 100.0, 120.0);
        SetSkill(SkillName.Chivalry, 100.0, 120.0);
        SetSkill(SkillName.Discordance, 100.0, 120.0);
        SetSkill(SkillName.Musicianship, 100.0, 120.0);
        SetSkill(SkillName.Provocation, 100.0, 120.0);
        SetSkill(SkillName.Peacemaking, 100.0, 120.0);

        for (var index = 0; index < 8; index++)
        {
            PackItem(Utility.Random(6) switch
            {
                0 => new Blight(),
                1 => new Scourge(),
                2 => new Taint(),
                3 => new Putrefication(),
                4 => new Corruption(),
                _ => new Muculent()
            });
        }
        var talismans = Utility.Random(5);
        for (var index = 0; index < talismans; index++)
        {
            PackItem(new RandomTalisman());
        }
        PackArcaneScroll(1, 6);
    }

    public override string DefaultName => "Travesty";
    public override string CorpseName => "a travesty's corpse";
    public override bool ShowFameTitle => false;
    public override bool CanHeal => _borrowedHealing;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override WeaponAbility? GetWeaponAbility() => Weapon is BaseWeapon weapon
        ? Utility.RandomBool() ? weapon.PrimaryAbility : weapon.SecondaryAbility
        : null;

    public override void OnDamage(int amount, Mobile from, bool willKill)
    {
        base.OnDamage(amount, from, willKill);
        if (willKill || Map == null || Map == Map.Internal)
        {
            return;
        }

        var now = Core.TickCount;
        if (!IsBodyMod && now - _nextMorph >= 0 && Utility.RandomDouble() < 0.25)
        {
            TryDisguise();
        }
        if (now - _nextMirror >= 0 && Utility.RandomDouble() < 0.10)
        {
            _nextMirror = now + Utility.RandomMinMax(20000, 45000);
            new MirrorImage(this, null).Cast();
        }
        if (!_calledReinforcements && Hits < 2000 && Map == Map.Malas && Region.IsPartOf("The Citadel"))
        {
            CallReinforcements();
        }
    }

    private void TryDisguise()
    {
        PlayerMobile? model = null;
        var visiblePlayers = 0;
        foreach (var player in GetMobilesInRange<PlayerMobile>(5))
        {
            if (player.Alive && player.AccessLevel == AccessLevel.Player && CanSee(player) &&
                Utility.Random(++visiblePlayers) == 0)
            {
                model = player;
            }
        }
        if (model == null)
        {
            return;
        }

        BodyMod = model.Body;
        HueMod = model.Hue;
        NameMod = model.Name;
        Female = model.Female;
        Title = DisguiseTitle;
        HairItemID = model.HairItemID;
        HairHue = model.HairHue;
        FacialHairItemID = model.FacialHairItemID;
        FacialHairHue = model.FacialHairHue;
        _borrowedHealing = model.Skills.Healing.Base > 20;
        this.MarkDirty();

        foreach (var item in model.Items)
        {
            if (item.Layer is > Layer.Invalid and < Layer.Mount &&
                item.Layer is not (Layer.Backpack or Layer.Hair or Layer.FacialHair) &&
                FindItemOnLayer(item.Layer) == null)
            {
                AddItem(new Changeling.ClonedItem(item));
            }
        }
        ApplyBorrowedCombatStyle(model);
        PlaySound(0x511);
        FixedParticles(0x376A, 1, 14, 5045, EffectLayer.Waist);
        _nextMorph = Core.TickCount + 10000;
        Timer.StartTimer(TimeSpan.FromMinutes(1), RestoreDisguise, out _restoreDisguise);
    }

    private void ApplyBorrowedCombatStyle(PlayerMobile model)
    {
        if (model.Skills.Magery.Value >= 50 || model.Skills.Necromancy.Value >= 50)
        {
            return;
        }
        if (model.Skills.Archery.Value >= 50 && model.Weapon is BaseRanged ranged &&
            Loot.Construct(ranged.GetType()) is BaseRanged copy)
        {
            FindItemOnLayer(Layer.OneHanded)?.Delete();
            FindItemOnLayer(Layer.TwoHanded)?.Delete();
            copy.Movable = false;
            copy.Hue = ranged.Hue;
            AddItem(copy);
            if (copy.Ammo is { } ammo)
            {
                ammo.Amount = 35;
                PackItem(ammo);
            }
            ChangeAIType(AIType.AI_Archer);
        }
        else if (Math.Max(model.Skills.Swords.Value, Math.Max(model.Skills.Fencing.Value, model.Skills.Macing.Value)) >= 50)
        {
            ChangeAIType(AIType.AI_Melee);
        }
    }

    private void RestoreDisguise()
    {
        _restoreDisguise.Cancel();
        if (Title != DisguiseTitle)
        {
            return;
        }

        BodyMod = 0;
        HueMod = -1;
        NameMod = null;
        Female = false;
        Title = null;
        HairItemID = 0;
        HairHue = 0;
        FacialHairItemID = 0;
        FacialHairHue = 0;
        _borrowedHealing = false;
        this.MarkDirty();
        RemoveDisguiseItems(Items);
        if (Backpack != null)
        {
            RemoveDisguiseItems(Backpack.Items);
        }
        ChangeAIType(AIType.AI_Mage);
    }

    private static void RemoveDisguiseItems(System.Collections.Generic.IReadOnlyList<Item> items)
    {
        for (var index = items.Count - 1; index >= 0; index--)
        {
            if (items[index] is Changeling.ClonedItem or BaseRanged { Movable: false })
            {
                items[index].Delete();
            }
        }
    }

    private void CallReinforcements()
    {
        _calledReinforcements = true;
        this.MarkDirty();
        foreach (var point in ReinforcementPositions)
        {
            if (!Map.CanSpawnMobile(point))
            {
                continue;
            }
            var mages = new DragonsFlameMage();
            var assassins = new SerpentsFangAssassin();
            var thieves = new TigersClawThief();
            foreach (var ally in new BaseCreature[] { mages, assassins, thieves })
            {
                ally.Home = point;
                ally.RangeHome = 8;
                ally.MoveToWorld(point, Map);
                _reinforcements.Add(ally);
            }
        }
        var retreat = RetreatPositions[Utility.Random(RetreatPositions.Length)];
        if (Map.CanSpawnMobile(retreat))
        {
            MoveToWorld(retreat, Map);
        }
    }

    public override bool OnBeforeDeath()
    {
        RestoreDisguise();
        return base.OnBeforeDeath();
    }

    public override void OnAfterDelete()
    {
        _restoreDisguise.Cancel();
        RemoveReinforcements();
        base.OnAfterDelete();
    }

    internal void RemoveReinforcements()
    {
        foreach (var ally in _reinforcements)
        {
            if (!ally.Deleted)
            {
                ally.Delete();
            }
        }
        _reinforcements.Clear();
        this.MarkDirty();
    }

    public override void GenerateLoot() => AddLoot(LootPack.SuperBoss, 8);

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        KeyTable?.BossDefeated(this);
        corpse.DropItem(new EyeOfTheTravesty());
        corpse.DropItem(new OrdersFromMinax());
        corpse.DropItem(Utility.Random(3) switch
        {
            0 => new TravestysSushiPreparations(),
            1 => new TravestysFineTeakwoodTray(),
            _ => new TravestysCollectionOfShells()
        });
    }

    [AfterDeserialization]
    private void RecoverDisguise()
    {
        RestoreDisguise();
    }

    private void MigrateFrom(V0Content content)
    {
        _calledReinforcements = content.CalledReinforcements;
        _borrowedHealing = content.BorrowedHealing;
    }
}
