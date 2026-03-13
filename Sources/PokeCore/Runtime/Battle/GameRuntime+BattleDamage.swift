import PokeDataModel

extension GameRuntime {
    func beginChargingIfNeeded(move: MoveManifest, attacker: inout RuntimePokemonState) -> [String] {
        if attacker.battleEffects.chargingMoveID == move.id {
            attacker.battleEffects.chargingMoveID = nil
            attacker.battleEffects.isInvulnerable = false
            return []
        }

        attacker.battleEffects.chargingMoveID = move.id
        attacker.battleEffects.isInvulnerable = move.effect == "FLY_EFFECT" || move.id == "DIG"
        return [chargeUpMessage(for: move.id)]
    }

    func chargeUpMessage(for moveID: String) -> String {
        switch moveID {
        case "RAZOR_WIND":
            return "Made a whirlwind!"
        case "SOLARBEAM":
            return "Took in sunlight!"
        case "SKULL_BASH":
            return "Lowered its head!"
        case "SKY_ATTACK":
            return "Is glowing!"
        case "FLY":
            return "Flew up high!"
        case "DIG":
            return "Dug a hole!"
        default:
            return "Is getting ready!"
        }
    }

    func mirrorMoveTarget(for defender: RuntimePokemonState) -> MoveManifest? {
        guard let lastMoveID = defender.battleEffects.lastMoveID else {
            return nil
        }
        return content.move(id: lastMoveID)
    }

    func metronomeMove() -> MoveManifest? {
        let candidates = content.gameplayManifest.moves.filter {
            $0.id != "METRONOME" && $0.id != "STRUGGLE"
        }
        guard candidates.isEmpty == false else {
            return nil
        }
        return candidates[nextBattleRandomByte() % candidates.count]
    }

    func recordLastSelectedMoveMetadata(_ move: MoveManifest, attacker: inout RuntimePokemonState) {
        attacker.battleEffects.lastSelectedMoveID = move.id
        attacker.battleEffects.lastSelectedMovePower = move.power
        attacker.battleEffects.lastSelectedMoveType = move.type
    }

    func moveCanDealDamage(_ move: MoveManifest, forcedDamage: Int?) -> Bool {
        forcedDamage != nil ||
            move.power > 0 ||
            move.effect == "OHKO_EFFECT" ||
            move.effect == "SUPER_FANG_EFFECT" ||
            move.effect == "SPECIAL_DAMAGE_EFFECT"
    }

    func applyIncomingDamageToBattleDefender(
        dealtDamage: Int,
        defender: inout RuntimePokemonState
    ) -> SubstituteDamageResult {
        let substituteResult = applyDamageToSubstituteIfNeeded(
            dealtDamage: dealtDamage,
            defender: &defender
        )
        if substituteResult.hitSubstitute {
            return substituteResult
        }

        defender.currentHP = max(0, defender.currentHP - dealtDamage)
        if defender.battleEffects.bideTurnsRemaining > 0 {
            defender.battleEffects.bideAccumulatedDamage += dealtDamage
        }
        return .init(hitSubstitute: false, appliedDamage: dealtDamage, messages: [])
    }

    func resolvedMoveDamage(
        move: MoveManifest,
        attacker: RuntimePokemonState,
        defender: RuntimePokemonState,
        adjustedAttack: Int,
        adjustedDefense: Int,
        typeMultiplier: Int,
        criticalHit: Bool,
        forcedDamage: Int? = nil
    ) -> Int {
        if let forcedDamage {
            return forcedDamage
        }
        switch move.effect {
        case "OHKO_EFFECT":
            return max(1, defender.currentHP)
        case "SUPER_FANG_EFFECT":
            return max(1, defender.currentHP / 2)
        case "SPECIAL_DAMAGE_EFFECT":
            return fixedDamage(for: move.id, attackerLevel: attacker.level)
        default:
            break
        }

        let battleLevel = criticalHit ? attacker.level * 2 : attacker.level
        let effectiveDefense = max(1, adjustedDefense)
        var damage = max(1, (((((2 * battleLevel) / 5) + 2) * move.power * adjustedAttack) / effectiveDefense) / 50 + 2)

        if hasSTAB(attacker: attacker, moveType: move.type) {
            damage += damage / 2
        }

        return applyTypeMultiplier(typeMultiplier, to: damage)
    }

    func fixedDamage(for moveID: String, attackerLevel: Int) -> Int {
        switch moveID {
        case "SONICBOOM":
            return 20
        case "DRAGON_RAGE":
            return 40
        case "SEISMIC_TOSS", "NIGHT_SHADE":
            return max(1, attackerLevel)
        case "PSYWAVE":
            let upperBound = max(1, (attackerLevel * 3) / 2 - 1)
            return max(1, 1 + (nextBattleRandomByte() % upperBound))
        default:
            return max(1, attackerLevel)
        }
    }

    func rolledMultiHitCount(for effect: String) -> Int? {
        switch effect {
        case "ATTACK_TWICE_EFFECT", "TWINEEDLE_EFFECT":
            return 2
        case "TWO_TO_FIVE_ATTACKS_EFFECT":
            var value = nextBattleRandomByte() & 0x3
            if value >= 2 {
                value = nextBattleRandomByte() & 0x3
            }
            return value + 2
        default:
            return nil
        }
    }

    func expectedHitCount(for effect: String) -> Int {
        switch effect {
        case "ATTACK_TWICE_EFFECT", "TWINEEDLE_EFFECT":
            return 2
        case "TWO_TO_FIVE_ATTACKS_EFFECT":
            return 3
        default:
            return 1
        }
    }

    func resolveMultiHitMove(
        move: MoveManifest,
        attacker: RuntimePokemonState,
        defender: inout RuntimePokemonState,
        plannedHits: Int,
        adjustedAttack: Int,
        adjustedDefense: Int,
        typeMultiplier: Int,
        criticalHit: Bool
    ) -> ResolvedMultiHitMove {
        guard typeMultiplier > 0 else {
            return .init(dealtDamage: 0, lastHitDamage: 0, hitSubstitute: false, messages: ["It doesn't affect \(defender.nickname)!"])
        }

        let damagePerHit = resolvedMoveDamage(
            move: move,
            attacker: attacker,
            defender: defender,
            adjustedAttack: adjustedAttack,
            adjustedDefense: adjustedDefense,
            typeMultiplier: typeMultiplier,
            criticalHit: criticalHit
        )

        var totalDamage = 0
        var actualHits = 0
        var lastHitDamage = 0
        var hitSubstitute = false
        var messages: [String] = []
        for _ in 0..<plannedHits where defender.currentHP > 0 || defender.battleEffects.hasSubstitute {
            let hitResult = applyIncomingDamageToBattleDefender(
                dealtDamage: damagePerHit,
                defender: &defender
            )
            totalDamage += hitResult.appliedDamage
            actualHits += 1
            if hitResult.hitSubstitute {
                hitSubstitute = true
            } else {
                lastHitDamage = hitResult.appliedDamage
            }
            for message in hitResult.messages where messages.contains(message) == false {
                messages.append(message)
            }
        }

        if criticalHit {
            messages.append("Critical hit!")
        }
        if typeMultiplier > 10 {
            messages.append("It's super effective!")
        } else if typeMultiplier < 10 {
            messages.append("It's not very effective...")
        }
        if defender.currentHP == 0 {
            messages.append("\(defender.nickname) fainted!")
        } else if actualHits > 1 {
            messages.append("Hit \(actualHits) times!")
        }

        return .init(dealtDamage: totalDamage, lastHitDamage: lastHitDamage, hitSubstitute: hitSubstitute, messages: messages)
    }

    func resolvedCounterDamage(attacker: RuntimePokemonState, defender: RuntimePokemonState) -> Int? {
        guard let lastSelectedMoveID = defender.battleEffects.lastSelectedMoveID,
              lastSelectedMoveID != "COUNTER",
              defender.battleEffects.lastSelectedMovePower > 0,
              let lastSelectedMoveType = defender.battleEffects.lastSelectedMoveType,
              lastSelectedMoveType == "NORMAL" || lastSelectedMoveType == "FIGHTING",
              attacker.battleEffects.lastDamageTaken > 0 else {
            return nil
        }

        return attacker.battleEffects.lastDamageTaken * 2
    }

    func confusionSelfDamage(for pokemon: RuntimePokemonState) -> Int {
        let adjustedAttack = max(1, scaledStat(pokemon.attack, stage: pokemon.attackStage))
        let adjustedDefense = max(1, scaledStat(pokemon.defense, stage: pokemon.defenseStage))
        let damage = (((((2 * pokemon.level) / 5) + 2) * 40 * adjustedAttack) / adjustedDefense) / 50 + 2
        return max(1, damage)
    }

    func effectiveTypes(for pokemon: RuntimePokemonState) -> (primary: String, secondary: String?) {
        if let primary = pokemon.battleEffects.typeOverridePrimary {
            return (primary, pokemon.battleEffects.typeOverrideSecondary)
        }

        guard let species = content.species(id: pokemon.speciesID) else {
            return ("NORMAL", nil)
        }
        return (species.primaryType, species.secondaryType)
    }

    func typeMatchesTarget(moveType: String, target: RuntimePokemonState) -> Bool {
        let types = effectiveTypes(for: target)
        return types.primary == moveType || types.secondary == moveType
    }

    func hasSTAB(attacker: RuntimePokemonState, moveType: String) -> Bool {
        let types = effectiveTypes(for: attacker)
        return types.primary == moveType || types.secondary == moveType
    }

    func totalTypeMultiplier(for moveType: String, defender: RuntimePokemonState) -> Int {
        let types = effectiveTypes(for: defender)
        let defendingTypes = [types.primary, types.secondary].compactMap { $0 }
        guard defendingTypes.isEmpty == false else { return 10 }

        return defendingTypes.reduce(10) { partialResult, defendingType in
            let nextMultiplier = content.typeEffectiveness(attackingType: moveType, defendingType: defendingType)?.multiplier ?? 10
            return (partialResult * nextMultiplier) / 10
        }
    }

    func applyTypeMultiplier(_ multiplier: Int, to damage: Int) -> Int {
        guard multiplier > 0 else { return 0 }
        return max(1, (damage * multiplier) / 10)
    }

    func adjustedOffenseStat(for pokemon: RuntimePokemonState, moveType: String, criticalHit: Bool) -> Int {
        if usesSpecialDamage(for: moveType) {
            return adjustedSpecialStat(for: pokemon, criticalHit: criticalHit)
        }
        return adjustedAttackStat(for: pokemon, criticalHit: criticalHit)
    }

    func adjustedDefenseStat(
        for pokemon: RuntimePokemonState,
        moveType: String,
        moveEffect: String,
        criticalHit: Bool
    ) -> Int {
        if usesSpecialDamage(for: moveType) {
            let special = adjustedSpecialStat(for: pokemon, criticalHit: criticalHit)
            return pokemon.battleEffects.hasLightScreen && criticalHit == false ? max(1, special * 2) : special
        }
        let defense = adjustedPhysicalDefenseStat(for: pokemon, criticalHit: criticalHit)
        if moveEffect == "EXPLODE_EFFECT" {
            return max(1, defense / 2)
        }
        return pokemon.battleEffects.hasReflect && criticalHit == false ? max(1, defense * 2) : defense
    }

    func adjustedAttackStat(for pokemon: RuntimePokemonState, criticalHit: Bool) -> Int {
        if criticalHit {
            return pokemon.majorStatus == .burn ? max(1, pokemon.attack / 2) : max(1, pokemon.attack)
        }
        let scaled = max(1, scaledStat(pokemon.attack, stage: pokemon.attackStage))
        if pokemon.majorStatus == .burn {
            return max(1, scaled / 2)
        }
        return scaled
    }

    func adjustedPhysicalDefenseStat(for pokemon: RuntimePokemonState, criticalHit: Bool) -> Int {
        if criticalHit {
            return max(1, pokemon.defense)
        }
        return max(1, scaledStat(pokemon.defense, stage: pokemon.defenseStage))
    }

    func adjustedSpeedStat(for pokemon: RuntimePokemonState) -> Int {
        let scaled = max(1, scaledStat(pokemon.speed, stage: pokemon.speedStage))
        if pokemon.majorStatus == .paralysis {
            return max(1, scaled / 4)
        }
        return scaled
    }

    func adjustedSpecialStat(for pokemon: RuntimePokemonState, criticalHit: Bool) -> Int {
        if criticalHit {
            return max(1, pokemon.special)
        }
        return max(1, scaledStat(pokemon.special, stage: pokemon.specialStage))
    }

    func usesSpecialDamage(for moveType: String) -> Bool {
        Self.specialMoveTypes.contains(moveType)
    }

    func isCriticalHit(for pokemon: RuntimePokemonState) -> Bool {
        let baseSpeed = content.species(id: pokemon.speciesID)?.baseSpeed ?? 0
        var threshold = min(255, max(1, baseSpeed / 2))
        if pokemon.battleEffects.isGettingPumped {
            threshold = max(1, threshold / 4)
        }
        return nextBattleRandomByte() < threshold
    }

    private func applyDamageToSubstituteIfNeeded(
        dealtDamage: Int,
        defender: inout RuntimePokemonState
    ) -> SubstituteDamageResult {
        guard dealtDamage > 0,
              defender.battleEffects.hasSubstitute else {
            return .init(hitSubstitute: false, appliedDamage: dealtDamage, messages: [])
        }

        let appliedDamage = min(defender.battleEffects.substituteHP, dealtDamage)
        defender.battleEffects.substituteHP = max(0, defender.battleEffects.substituteHP - appliedDamage)

        var messages = ["Substitute took damage!"]
        if defender.battleEffects.substituteHP == 0 {
            defender.battleEffects.hasSubstitute = false
            messages.append("Substitute broke!")
        }

        return .init(hitSubstitute: true, appliedDamage: appliedDamage, messages: messages)
    }
}
