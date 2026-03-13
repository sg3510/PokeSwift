import PokeDataModel

extension GameRuntime {
    func preparePokemonForTurn(
        pokemon: inout RuntimePokemonState,
        opponent: RuntimePokemonState,
        selectedMoveIndex: Int
    ) -> BattleTurnPreparationResult {
        var messages: [String] = []

        if pokemon.majorStatus == .sleep {
            if pokemon.statusCounter > 0 {
                pokemon.statusCounter -= 1
            }
            if pokemon.statusCounter <= 0 {
                pokemon.majorStatus = .none
                pokemon.statusCounter = 0
                return .init(
                    messages: ["\(pokemon.nickname) woke up!"],
                    canAct: false,
                    shouldSkipPP: false,
                    shouldSkipAccuracy: false,
                    shouldSkipEffect: false,
                    forcedDamage: nil
                )
            }
            return .init(
                messages: ["\(pokemon.nickname) is fast asleep!"],
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.majorStatus == .freeze {
            return .init(
                messages: ["\(pokemon.nickname) is frozen solid!"],
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.skipTurnOnce {
            pokemon.battleEffects.skipTurnOnce = false
            return .init(
                messages: [],
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if opponent.battleEffects.trappingTurnsRemaining > 0,
           opponent.currentHP > 0 {
            return .init(
                messages: ["\(pokemon.nickname) can't move!"],
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.isFlinched {
            pokemon.battleEffects.isFlinched = false
            return .init(
                messages: ["\(pokemon.nickname) flinched!"],
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.needsRecharge {
            pokemon.battleEffects.needsRecharge = false
            return .init(
                messages: ["\(pokemon.nickname) must recharge!"],
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.disabledTurnsRemaining > 0 {
            pokemon.battleEffects.disabledTurnsRemaining -= 1
            if pokemon.battleEffects.disabledTurnsRemaining == 0 {
                pokemon.battleEffects.disabledMoveID = nil
                messages.append("\(pokemon.nickname)'s disabled move is no longer disabled!")
            }
        }

        if pokemon.battleEffects.disabledTurnsRemaining > 0,
           pokemon.moves.indices.contains(selectedMoveIndex),
           pokemon.moves[selectedMoveIndex].id == pokemon.battleEffects.disabledMoveID {
            let disabledMoveName = content.move(id: pokemon.moves[selectedMoveIndex].id)?.displayName
                ?? pokemon.moves[selectedMoveIndex].id
            messages.append("\(disabledMoveName) is disabled!")
            return .init(
                messages: messages,
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.confusionTurnsRemaining > 0 {
            pokemon.battleEffects.confusionTurnsRemaining -= 1
            if pokemon.battleEffects.confusionTurnsRemaining == 0 {
                messages.append("\(pokemon.nickname) snapped out of confusion!")
            } else {
                messages.append("\(pokemon.nickname) is confused!")
                if nextBattleRandomByte() >= 128 {
                    clearInterruptedMultiTurnState(for: &pokemon)
                    messages.append(contentsOf: applyConfusionSelfDamage(to: &pokemon))
                    return .init(
                        messages: messages,
                        canAct: false,
                        shouldSkipPP: false,
                        shouldSkipAccuracy: false,
                        shouldSkipEffect: false,
                        forcedDamage: nil
                    )
                }
            }
        }

        if pokemon.majorStatus == .paralysis, nextBattleRandomByte() < 64 {
            clearInterruptedMultiTurnState(for: &pokemon)
            messages.append("\(pokemon.nickname) is fully paralyzed!")
            return .init(
                messages: messages,
                canAct: false,
                shouldSkipPP: false,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.bideTurnsRemaining > 0 {
            pokemon.battleEffects.bideTurnsRemaining -= 1
            if pokemon.battleEffects.bideTurnsRemaining > 0 {
                return .init(
                    messages: messages,
                    canAct: false,
                    shouldSkipPP: true,
                    shouldSkipAccuracy: true,
                    shouldSkipEffect: true,
                    forcedDamage: nil
                )
            }

            pokemon.battleEffects.pendingBideDamage = max(0, pokemon.battleEffects.bideAccumulatedDamage * 2)
            messages.append("\(pokemon.nickname) unleashed energy!")
            return .init(
                messages: messages,
                canAct: true,
                shouldSkipPP: true,
                shouldSkipAccuracy: true,
                shouldSkipEffect: true,
                forcedDamage: max(0, pokemon.battleEffects.pendingBideDamage ?? 0)
            )
        }

        if pokemon.battleEffects.thrashTurnsRemaining > 0 {
            messages.append("\(pokemon.nickname) is thrashing about!")
            pokemon.battleEffects.thrashTurnsRemaining -= 1
            if pokemon.battleEffects.thrashTurnsRemaining == 0 {
                pokemon.battleEffects.confusionTurnsRemaining = 2 + (nextBattleRandomByte() & 0x3)
                pokemon.battleEffects.thrashMoveID = nil
            }
            return .init(
                messages: messages,
                canAct: true,
                shouldSkipPP: true,
                shouldSkipAccuracy: false,
                shouldSkipEffect: true,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.trappingTurnsRemaining > 0 {
            messages.append("Attack continues!")
            pokemon.battleEffects.trappingTurnsRemaining -= 1
            if pokemon.battleEffects.trappingTurnsRemaining == 0 {
                pokemon.battleEffects.trappingMoveID = nil
            }
            return .init(
                messages: messages,
                canAct: true,
                shouldSkipPP: true,
                shouldSkipAccuracy: true,
                shouldSkipEffect: true,
                forcedDamage: pokemon.battleEffects.trappingDamage
            )
        }

        if pokemon.battleEffects.chargingMoveID != nil {
            return .init(
                messages: messages,
                canAct: true,
                shouldSkipPP: true,
                shouldSkipAccuracy: false,
                shouldSkipEffect: false,
                forcedDamage: nil
            )
        }

        if pokemon.battleEffects.isUsingRage {
            return .init(
                messages: messages,
                canAct: true,
                shouldSkipPP: true,
                shouldSkipAccuracy: false,
                shouldSkipEffect: true,
                forcedDamage: nil
            )
        }

        return .init(
            messages: messages,
            canAct: true,
            shouldSkipPP: false,
            shouldSkipAccuracy: false,
            shouldSkipEffect: false,
            forcedDamage: nil
        )
    }

    func clearInterruptedMultiTurnState(for pokemon: inout RuntimePokemonState) {
        pokemon.battleEffects.bideTurnsRemaining = 0
        pokemon.battleEffects.pendingBideDamage = nil
        pokemon.battleEffects.bideAccumulatedDamage = 0
        pokemon.battleEffects.thrashTurnsRemaining = 0
        pokemon.battleEffects.thrashMoveID = nil
        pokemon.battleEffects.chargingMoveID = nil
        pokemon.battleEffects.isInvulnerable = false
        pokemon.battleEffects.trappingTurnsRemaining = 0
        pokemon.battleEffects.trappingMoveID = nil
        pokemon.battleEffects.trappingDamage = 0
    }

    func clearVolatileBattleState(for pokemon: inout RuntimePokemonState) {
        pokemon.battleEffects.confusionTurnsRemaining = 0
        pokemon.battleEffects.disabledMoveID = nil
        pokemon.battleEffects.disabledTurnsRemaining = 0
        pokemon.battleEffects.isProtectedByMist = false
        pokemon.battleEffects.hasLightScreen = false
        pokemon.battleEffects.hasReflect = false
        pokemon.battleEffects.isGettingPumped = false
        pokemon.battleEffects.isSeeded = false
        pokemon.battleEffects.needsRecharge = false
        pokemon.battleEffects.isFlinched = false
        pokemon.battleEffects.skipTurnOnce = false
    }

    func forcedMoveIndex(for pokemon: RuntimePokemonState) -> Int? {
        let forcedMoveID: String?
        if pokemon.battleEffects.bideTurnsRemaining > 0 {
            forcedMoveID = "BIDE"
        } else if let chargingMoveID = pokemon.battleEffects.chargingMoveID {
            forcedMoveID = chargingMoveID
        } else if pokemon.battleEffects.thrashTurnsRemaining > 0 {
            forcedMoveID = pokemon.battleEffects.thrashMoveID
        } else if pokemon.battleEffects.trappingTurnsRemaining > 0 {
            forcedMoveID = pokemon.battleEffects.trappingMoveID
        } else if pokemon.battleEffects.isUsingRage {
            forcedMoveID = "RAGE"
        } else {
            forcedMoveID = nil
        }

        guard let forcedMoveID else {
            return nil
        }
        return pokemon.moves.firstIndex { $0.id == forcedMoveID }
    }

    func resetBattleStages(for pokemon: inout RuntimePokemonState) {
        pokemon.attackStage = 0
        pokemon.defenseStage = 0
        pokemon.speedStage = 0
        pokemon.specialStage = 0
        pokemon.accuracyStage = 0
        pokemon.evasionStage = 0
    }
}
