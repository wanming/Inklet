import Combine
import SwiftUI
import WritingPopoverCore

@MainActor
final class WritingPopoverViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var resultText = ""
    @Published var errorMessage: String?
    @Published var isTransforming = false
    @Published var selectedModeID: String
    @Published var openRevision = 0

    let modes: [PromptMode]

    init(modes: [PromptMode] = PromptModeStore.defaultStore().visibleModes) {
        self.modes = modes
        self.selectedModeID = modes.first?.id ?? PromptMode.polishEnglishID
    }

    func resetForOpen() {
        sourceText = ""
        resultText = ""
        errorMessage = nil
        isTransforming = false
        openRevision += 1

        if !modes.contains(where: { $0.id == selectedModeID }) {
            selectedModeID = modes.first?.id ?? PromptMode.polishEnglishID
        }
    }

    func transform() {
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            resultText = ""
            errorMessage = "请输入要转换的文本。"
            return
        }

        errorMessage = nil
        isTransforming = false
        resultText = trimmedSource
    }
}

struct WritingPopoverView: View {
    @ObservedObject var model: WritingPopoverViewModel
    @FocusState private var isSourceFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("模式", selection: $model.selectedModeID) {
                ForEach(model.modes) { mode in
                    Text(mode.name).tag(mode.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextEditor(text: $model.sourceText)
                .font(.body)
                .frame(minHeight: 96)
                .focused($isSourceFocused)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                }

            HStack(spacing: 10) {
                Button("转换") {
                    model.transform()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isTransforming)

                if model.isTransforming {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Text("Enter 输入换行，⌥Space 打开浮窗")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if !model.resultText.isEmpty {
                TextEditor(text: $model.resultText)
                    .font(.body)
                    .frame(minHeight: 72)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    }
            }
        }
        .padding(16)
        .frame(minWidth: 520, idealWidth: 520, minHeight: 320)
        .onAppear {
            focusSourceEditor()
        }
        .onChange(of: model.openRevision) {
            focusSourceEditor()
        }
    }

    private func focusSourceEditor() {
        DispatchQueue.main.async {
            isSourceFocused = true
        }
    }
}
