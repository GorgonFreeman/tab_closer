import SwiftUI

@MainActor
final class TabListModel: ObservableObject {
    @Published var sections: [(domain: String, tabs: [ChromeTab])] = []
    @Published var statusMessage: String?
    @Published var isLoading = false

    func refresh() {
        isLoading = true
        statusMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tabs = try ChromeTabs.fetchTabs()
                let grouped = ChromeTabs.groupedByDomain(tabs)
                DispatchQueue.main.async {
                    self.sections = grouped
                    self.isLoading = false
                    if grouped.isEmpty {
                        self.statusMessage = "No open Chrome tabs."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.sections = []
                    self.isLoading = false
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func close(_ tab: ChromeTab) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ChromeTabs.closeTab(tab)
                DispatchQueue.main.async {
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.refresh()
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var model = TabListModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tab Closer")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh tabs")
                .disabled(model.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let statusMessage = model.statusMessage, model.sections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Refresh") {
                        model.refresh()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.sections, id: \.domain) { section in
                        Section(section.domain) {
                            ForEach(section.tabs) { tab in
                                HStack(spacing: 10) {
                                    Text(tab.title)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .help(tab.url)

                                    Button {
                                        model.close(tab)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 22, height: 22)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Close tab")
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            model.refresh()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 480, height: 560)
}
