import SwiftUI
import PokeDataModel

private enum FieldScreenShader {
    static let function = ShaderFunction(
        library: .bundle(PokeUIResources.bundle),
        name: "fieldScreenEffect"
    )
}

private enum BattleScreenShader {
    static let function = ShaderFunction(
        library: .bundle(PokeUIResources.bundle),
        name: "battleScreenEffect"
    )
}

extension View {
    func fieldScreenEffect(displayStyle: FieldDisplayStyle, displayScale: CGFloat) -> some View {
        modifier(FieldScreenEffectModifier(displayStyle: displayStyle, displayScale: displayScale))
    }

    func battleScreenEffect(
        displayScale: CGFloat,
        presentation: BattlePresentationTelemetry
    ) -> some View {
        modifier(BattleScreenEffectModifier(displayScale: displayScale, presentation: presentation))
    }
}

private struct FieldScreenEffectModifier: ViewModifier {
    let displayStyle: FieldDisplayStyle
    let displayScale: CGFloat

    func body(content: Content) -> some View {
        guard displayStyle != .rawGrayscale else {
            return AnyView(content)
        }

        return AnyView(
            content
                .colorEffect(
                    Shader(
                        function: FieldScreenShader.function,
                        arguments: [
                            .float(shaderViewportWidth),
                            .float(shaderViewportHeight),
                            .float(Float(max(1, displayScale))),
                            .float(displayStyle.shaderPresetValue),
                        ]
                    )
                )
                .drawingGroup()
        )
    }

    private var shaderViewportWidth: Float {
        Float(CGFloat(FieldSceneRenderer.viewportPixelSize.width) * displayScale)
    }

    private var shaderViewportHeight: Float {
        Float(CGFloat(FieldSceneRenderer.viewportPixelSize.height) * displayScale)
    }
}

private struct BattleScreenEffectModifier: ViewModifier {
    let displayScale: CGFloat
    let presentation: BattlePresentationTelemetry
    @State private var displayedIntroProgress: CGFloat = 1
    @State private var displayedIntroAmount: CGFloat = 0
    @State private var hasAnimatedIntro = false
    @State private var seededIntroRevision: Int?

    func body(content: Content) -> some View {
        content
            .layerEffect(
                Shader(
                    function: BattleScreenShader.function,
                    arguments: [
                        .float(shaderViewportWidth),
                        .float(shaderViewportHeight),
                        .float(Float(max(1, displayScale))),
                        .float(introStyleValue),
                        .float(Float(displayedIntroProgress)),
                        .float(Float(displayedIntroAmount)),
                    ]
                ),
                maxSampleOffset: .init(width: maxSampleOffset, height: maxSampleOffset)
            )
            .drawingGroup()
            .onAppear {
                syncIntroState(animated: false)
            }
            .onChange(of: presentation.transitionStyle) { _, _ in
                syncIntroState(animated: true)
            }
            .onChange(of: presentation.stage) { _, _ in
                syncIntroState(animated: true)
            }
            .onChange(of: presentation.revision) { _, _ in
                syncIntroState(animated: true)
            }
    }

    private var shaderViewportWidth: Float {
        Float(CGFloat(FieldSceneRenderer.viewportPixelSize.width) * displayScale)
    }

    private var shaderViewportHeight: Float {
        Float(CGFloat(FieldSceneRenderer.viewportPixelSize.height) * displayScale)
    }

    private var maxSampleOffset: CGFloat {
        max(12, displayScale * 10)
    }

    private var introStyleValue: Float {
        switch presentation.transitionStyle {
        case .none:
            return 0
        case .circle:
            return 1
        case .spiral:
            return 2
        }
    }

    private var targetIntroProgress: CGFloat {
        switch presentation.stage {
        case .introTransition:
            return 1
        case .introEnemySendOut, .introPlayerSendOut, .introSettle:
            return 1
        case .commandReady, .attackWindup, .attackImpact, .hpDrain, .resultText, .faint, .experience, .levelUp, .enemySendOut, .turnSettle, .battleComplete, .idle:
            return 1
        }
    }

    private var targetIntroAmount: CGFloat {
        switch presentation.stage {
        case .introTransition:
            return presentation.transitionStyle == .none ? 0 : 1
        case .introEnemySendOut:
            return presentation.transitionStyle == .none ? 0 : 0.08
        case .introPlayerSendOut, .introSettle, .commandReady, .attackWindup, .attackImpact, .hpDrain, .resultText, .faint, .experience, .levelUp, .enemySendOut, .turnSettle, .battleComplete, .idle:
            return 0
        }
    }

    private func syncIntroState(animated: Bool) {
        guard presentation.transitionStyle != .none else {
            displayedIntroProgress = 1
            displayedIntroAmount = 0
            hasAnimatedIntro = false
            seededIntroRevision = nil
            return
        }

        if presentation.stage == .introTransition, seededIntroRevision != presentation.revision {
            seededIntroRevision = presentation.revision
            hasAnimatedIntro = true
            displayedIntroProgress = 0.01
            displayedIntroAmount = targetIntroAmount
            DispatchQueue.main.async {
                withAnimation(transitionAnimation) {
                    displayedIntroProgress = targetIntroProgress
                    displayedIntroAmount = targetIntroAmount
                }
            }
            return
        }

        if animated == false || hasAnimatedIntro == false {
            hasAnimatedIntro = true
            displayedIntroProgress = 0.01
            displayedIntroAmount = targetIntroAmount
            DispatchQueue.main.async {
                withAnimation(transitionAnimation) {
                    displayedIntroProgress = targetIntroProgress
                    displayedIntroAmount = targetIntroAmount
                }
            }
            return
        }

        withAnimation(transitionAnimation) {
            displayedIntroProgress = targetIntroProgress
            displayedIntroAmount = targetIntroAmount
        }
    }

    private var transitionAnimation: Animation {
        switch presentation.stage {
        case .introTransition:
            return presentation.transitionStyle == .circle ? .easeOut(duration: 0.64) : .easeOut(duration: 0.62)
        case .introEnemySendOut:
            return .easeOut(duration: 0.18)
        case .introPlayerSendOut:
            return .easeOut(duration: 0.14)
        case .introSettle:
            return .easeOut(duration: 0.18)
        default:
            return .easeInOut(duration: 0.2)
        }
    }
}

private extension FieldDisplayStyle {
    var shaderPresetValue: Float {
        switch self {
        case .rawGrayscale:
            return 0
        case .dmgAuthentic:
            return 1
        case .dmgTinted:
            return 2
        }
    }
}
