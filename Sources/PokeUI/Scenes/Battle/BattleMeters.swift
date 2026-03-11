import SwiftUI
import PokeDataModel

struct BattleExperienceBar: View {
    let experience: ExperienceProgressTelemetry
    let meterAnimation: BattleMeterAnimationTelemetry?
    let animationRevision: Int

    @State private var displayedTotal = 0
    @State private var displayedLevelStart = 0
    @State private var displayedNextLevel = 1

    private var fraction: CGFloat {
        let range = max(0, displayedNextLevel - displayedLevelStart)
        guard range > 0 else { return 1 }
        let progress = min(range, max(0, displayedTotal - displayedLevelStart))
        return CGFloat(progress) / CGFloat(range)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width * fraction)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(FieldRetroPalette.track)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.28, green: 0.46, blue: 0.62))
                    .frame(width: width)
            }
        }
        .onAppear {
            sync(to: experience)
        }
        .onChange(of: experience) { _, updatedExperience in
            sync(to: updatedExperience)
        }
        .onChange(of: animationRevision) { _, _ in
            guard let meterAnimation, meterAnimation.kind == .experience else { return }
            runExperienceAnimation(meterAnimation)
        }
    }

    private func sync(to experience: ExperienceProgressTelemetry) {
        displayedTotal = experience.total
        displayedLevelStart = experience.levelStart
        displayedNextLevel = experience.nextLevel
    }

    private func runExperienceAnimation(_ meterAnimation: BattleMeterAnimationTelemetry) {
        let fallbackStart = meterAnimation.startLevelStart ?? experience.levelStart
        let fallbackNext = meterAnimation.startNextLevel ?? experience.nextLevel
        displayedLevelStart = fallbackStart
        displayedNextLevel = fallbackNext
        displayedTotal = meterAnimation.fromValue

        if let startNextLevel = meterAnimation.startNextLevel,
           let endLevelStart = meterAnimation.endLevelStart,
           let endNextLevel = meterAnimation.endNextLevel,
           meterAnimation.endLevel != meterAnimation.startLevel {
            withAnimation(.linear(duration: 0.18)) {
                displayedTotal = startNextLevel
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                displayedLevelStart = endLevelStart
                displayedNextLevel = endNextLevel
                displayedTotal = endLevelStart
                withAnimation(.linear(duration: 0.2)) {
                    displayedTotal = meterAnimation.toValue
                }
            }
        } else {
            withAnimation(.linear(duration: 0.24)) {
                displayedTotal = meterAnimation.toValue
            }
        }
    }
}

struct BattleHPBar: View {
    let currentHP: Int
    let maxHP: Int
    let meterAnimation: BattleMeterAnimationTelemetry?
    let animationRevision: Int

    @State private var displayedCurrentHP = 0

    private var hpFraction: CGFloat {
        CGFloat(displayedCurrentHP) / CGFloat(max(1, maxHP))
    }

    private var barColor: Color {
        switch hpFraction {
        case ..<0.25:
            return Color(red: 0.63, green: 0.27, blue: 0.24)
        case ..<0.5:
            return Color(red: 0.72, green: 0.55, blue: 0.21)
        default:
            return Color(red: 0.2, green: 0.32, blue: 0.14)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width * hpFraction)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(FieldRetroPalette.track)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(barColor)
                    .frame(width: width)
            }
        }
        .onAppear {
            displayedCurrentHP = currentHP
        }
        .onChange(of: currentHP) { _, updatedHP in
            displayedCurrentHP = updatedHP
        }
        .onChange(of: animationRevision) { _, _ in
            guard let meterAnimation, meterAnimation.kind == .hp else { return }
            displayedCurrentHP = meterAnimation.fromValue
            withAnimation(.linear(duration: 0.26)) {
                displayedCurrentHP = meterAnimation.toValue
            }
        }
    }
}
