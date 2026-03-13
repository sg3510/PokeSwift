import PokeDataModel

extension GameRuntime {
    func selectEnemyMoveIndex(
        battle: RuntimeBattleState,
        enemyPokemon: RuntimePokemonState,
        playerPokemon: RuntimePokemonState
    ) -> Int {
        if let forcedMoveIndex = forcedMoveIndex(for: enemyPokemon) {
            return forcedMoveIndex
        }
        let availableMoves = enemyPokemon.moves.enumerated().filter { $0.element.currentPP > 0 }
        guard availableMoves.isEmpty == false else { return 0 }
        let selectableMoves = availableMoves.filter { entry in
            enemyPokemon.battleEffects.disabledTurnsRemaining == 0 ||
                entry.element.id != enemyPokemon.battleEffects.disabledMoveID
        }
        let candidateMoves = selectableMoves.isEmpty ? availableMoves : selectableMoves

        if battle.kind == .wild {
            return chooseRandomMoveIndex(from: candidateMoves)
        }

        let trainerClass = battle.trainerClass ?? ""
        let modifications = content.trainerAIMoveChoiceModifications(trainerClass: trainerClass)?.modifications ?? []
        guard modifications.isEmpty == false else {
            return chooseRandomMoveIndex(from: candidateMoves)
        }

        var discouragements = Array(repeating: 10, count: enemyPokemon.moves.count)
        applyTrainerAINoOpMoveDiscouragement(
            discouragements: &discouragements,
            enemyPokemon: enemyPokemon,
            playerPokemon: playerPokemon
        )

        for modification in modifications {
            switch modification {
            case 1:
                applyTrainerAIModification1(
                    discouragements: &discouragements,
                    enemyPokemon: enemyPokemon,
                    playerPokemon: playerPokemon
                )
            case 2:
                applyTrainerAIModification2(
                    discouragements: &discouragements,
                    enemyPokemon: enemyPokemon,
                    layer2EncouragementValue: battle.aiLayer2Encouragement
                )
            case 3:
                applyTrainerAIModification3(
                    discouragements: &discouragements,
                    enemyPokemon: enemyPokemon,
                    playerPokemon: playerPokemon
                )
            default:
                break
            }
        }

        let selectable = candidateMoves.filter { entry in
            discouragements.indices.contains(entry.offset)
        }
        let minimumDiscouragement = selectable.map { discouragements[$0.offset] }.min() ?? 10
        let candidates = selectable.filter { discouragements[$0.offset] == minimumDiscouragement }
        return chooseRandomMoveIndex(from: candidates)
    }

    func applyTrainerAINoOpMoveDiscouragement(
        discouragements: inout [Int],
        enemyPokemon: RuntimePokemonState,
        playerPokemon: RuntimePokemonState
    ) {
        for (index, runtimeMove) in enemyPokemon.moves.enumerated() {
            guard discouragements.indices.contains(index),
                  runtimeMove.currentPP > 0,
                  let move = content.move(id: runtimeMove.id),
                  move.power == 0,
                  let descriptor = statStageEffectDescriptor(for: move.effect),
                  descriptor.isSideEffect == false,
                  statStageMoveWouldBeNoOp(
                    descriptor: descriptor,
                    attacker: enemyPokemon,
                    defender: playerPokemon
                  ) else {
                continue
            }
            discouragements[index] += 5
        }
    }

    func chooseRandomMoveIndex(
        from availableMoves: [EnumeratedSequence<[RuntimeMoveState]>.Element]
    ) -> Int {
        guard availableMoves.isEmpty == false else { return 0 }
        let selected = nextBattleRandomByte() % availableMoves.count
        return availableMoves[selected].offset
    }

    func applyTrainerAIModification1(
        discouragements: inout [Int],
        enemyPokemon: RuntimePokemonState,
        playerPokemon: RuntimePokemonState
    ) {
        guard playerPokemon.majorStatus != .none else {
            return
        }

        for (index, runtimeMove) in enemyPokemon.moves.enumerated() {
            guard discouragements.indices.contains(index),
                  runtimeMove.currentPP > 0,
                  let move = content.move(id: runtimeMove.id),
                  move.power == 0,
                  Self.trainerAIStatusAilmentEffects.contains(move.effect) else {
                continue
            }
            discouragements[index] += 5
        }
    }

    func applyTrainerAIModification2(
        discouragements: inout [Int],
        enemyPokemon: RuntimePokemonState,
        layer2EncouragementValue: Int
    ) {
        guard layer2EncouragementValue == 1 else {
            return
        }

        for (index, runtimeMove) in enemyPokemon.moves.enumerated() {
            guard discouragements.indices.contains(index),
                  runtimeMove.currentPP > 0,
                  let move = content.move(id: runtimeMove.id),
                  Self.trainerAIModification2PreferredEffects.contains(move.effect) else {
                continue
            }
            discouragements[index] -= 1
        }
    }

    func applyTrainerAIModification3(
        discouragements: inout [Int],
        enemyPokemon: RuntimePokemonState,
        playerPokemon: RuntimePokemonState
    ) {
        for (index, runtimeMove) in enemyPokemon.moves.enumerated() {
            guard discouragements.indices.contains(index),
                  runtimeMove.currentPP > 0,
                  let move = content.move(id: runtimeMove.id) else {
                continue
            }

            let typeMultiplier = totalTypeMultiplier(for: move.type, defender: playerPokemon)
            if typeMultiplier > 10 {
                discouragements[index] -= 1
                continue
            }

            guard typeMultiplier < 10,
                  trainerAIHasBetterAlternativeMove(
                    currentMove: move,
                    enemyPokemon: enemyPokemon
                  ) else {
                continue
            }
            discouragements[index] += 1
        }
    }

    func trainerAIHasBetterAlternativeMove(currentMove: MoveManifest, enemyPokemon: RuntimePokemonState) -> Bool {
        for runtimeMove in enemyPokemon.moves where runtimeMove.currentPP > 0 {
            guard let move = content.move(id: runtimeMove.id) else {
                continue
            }
            switch move.effect {
            case "SUPER_FANG_EFFECT", "SPECIAL_DAMAGE_EFFECT", "FLY_EFFECT":
                return true
            default:
                break
            }

            if move.type != currentMove.type && move.power > 0 {
                return true
            }
        }

        return false
    }

    func projectedDamage(move: MoveManifest, attacker: RuntimePokemonState, defender: RuntimePokemonState) -> Int {
        guard move.power > 0 else { return 0 }
        let adjustedAttack = adjustedOffenseStat(for: attacker, moveType: move.type, criticalHit: false)
        let adjustedDefense = max(1, adjustedDefenseStat(for: defender, moveType: move.type, moveEffect: move.effect, criticalHit: false))
        var damage = max(1, (((((2 * attacker.level) / 5) + 2) * move.power * adjustedAttack) / adjustedDefense) / 50 + 2)
        if hasSTAB(attacker: attacker, moveType: move.type) {
            damage += damage / 2
        }
        let resolvedDamage = applyTypeMultiplier(totalTypeMultiplier(for: move.type, defender: defender), to: damage)
        return resolvedDamage * expectedHitCount(for: move.effect)
    }
}
