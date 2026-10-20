//
//  ContentView.swift
//  VinillyApp
//
//  Created by Francesca Coppola on 18/10/2026.
//

import SwiftUI
import Observation
import Charts
import VisionKit
import SwiftData

// MARK: - App Entry Point & ContentView

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Placeholder Card

private var placeholderCard: some View {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.black)
        .frame(width: 250, height: 250)
        .overlay(
            Image(systemName: "opticaldisc.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .foregroundColor(.white.opacity(0.8))
        )
}

// MARK: - HiFi Models

struct HiFiProfile: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var setups: [HiFiSetup]
}

struct HiFiSetup: Identifiable, Hashable {
    let id = UUID()
    var genre: String
    var notes: String
    var bass: Double
    var mid: Double
    var treble: Double
    var balance: Double
    var subwooferLevel: Double
    var isLoudnessEnabled: Bool
}

// MARK: - ViewModel

@Observable
class CollectionViewModel {
    var hifiProfiles: [HiFiProfile] = [
        HiFiProfile(name: "Impianto Salotto (Torri)", setups: [
            HiFiSetup(genre: "Rock", notes: "Medio-bassi presenti, tweeter attenuati.", bass: 2, mid: 1, treble: -1, balance: 0, subwooferLevel: 4, isLoudnessEnabled: false),
            HiFiSetup(genre: "Jazz", notes: "Direct/Flat per non colorare fiati.", bass: 0, mid: 0, treble: 0, balance: 0, subwooferLevel: 2, isLoudnessEnabled: false)
        ]),
        HiFiProfile(name: "Impianto Studio (Scaffale)", setups: [
            HiFiSetup(genre: "Pop", notes: "Loudness attivo per bassi volumi.", bass: 3, mid: 0, treble: 2, balance: -1, subwooferLevel: 6, isLoudnessEnabled: true)
        ])
    ]
    
    func searchByBarcode(_ code: String) -> Vinyl? {
        return DatabaseService.shared.searchByBarcode(code)
    }
    
    func searchManually(query: String) -> [Vinyl] {
        return DatabaseService.shared.searchByText(query: query)
    }
    
    func addHiFiProfile(name: String) {
        let newProfile = HiFiProfile(name: name, setups: [])
        hifiProfiles.append(newProfile)
    }
    
    func addSetup(to profileID: UUID, genre: String) {
        if let index = hifiProfiles.firstIndex(where: { $0.id == profileID }) {
            let newSetup = HiFiSetup(genre: genre, notes: "", bass: 0, mid: 0, treble: 0, balance: 0, subwooferLevel: 0, isLoudnessEnabled: false)
            hifiProfiles[index].setups.append(newSetup)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var viewModel = CollectionViewModel()
    
    var body: some View {
        TabView {
            CollectionTabView(viewModel: viewModel)
                .tabItem { Label("Collection", systemImage: "music.note.list") }
            
            StatsTabView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            
            HiFiTabView(viewModel: viewModel)
                .tabItem { Label("Hi-Fi", systemImage: "headphones") }
            
            Text("Impostazioni")
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.green)
    }
}

// MARK: - Collection Tab View con Persistenza SwiftData

struct CollectionTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vinyl.addedAt, order: .reverse) private var vinyls: [Vinyl]
    
    var viewModel: CollectionViewModel
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    
    @State private var showAddMenu = false
    @State private var showScanner = false
    @State private var showManualSearch = false
    @State private var scannedCode: String? = nil
    
    @State private var showFoundAlert = false
    @State private var showNotFoundAlert = false
    @State private var lastFoundVinyl: Vinyl? = nil
    @State private var lastFailedBarcode: String = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if vinyls.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "opticaldisc")
                            .font(.system(size: 90, weight: .light))
                            .foregroundStyle(.green.gradient)
                            .symbolEffect(.pulse.byLayer, options: .repeating)
                        
                        Text("La tua collezione è vuota")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Aggiungi il tuo primo vinile scansionando il codice a barre sul retro della copertina o cercando nel database offline.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showAddMenu = true
                        } label: {
                            Label("Aggiungi Vinile", systemImage: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .clipShape(Capsule())
                                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                } else {
                    VStack {
                        Spacer()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(vinyls) { vinyl in
                                    VStack {
                                        if let coverUrl = vinyl.coverUrl, let url = URL(string: coverUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 250, height: 250)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                default:
                                                    placeholderCard
                                                }
                                            }
                                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                                        } else {
                                            placeholderCard
                                                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                                        }
                                        
                                        Text(vinyl.title)
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .padding(.top, 10)
                                        
                                        Text(vinyl.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 260)
                                    .scrollTransition(axis: .horizontal) { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1.15 : 0.8)
                                            .rotation3DEffect(
                                                .degrees(phase.value * 35),
                                                axis: (x: 0, y: 1, z: 0),
                                                perspective: 0.5
                                            )
                                            .offset(x: phase.value * -40)
                                            .opacity(phase.isIdentity ? 1.0 : 0.5)
                                    }
                                }
                            }
                            .padding(.vertical, 50)
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .safeAreaPadding(.horizontal, 60)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("MyCollection")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddMenu = true } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                }
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
            .sheet(isPresented: $showAddMenu) {
                VStack(spacing: 16) {
                    Text("Add to your collection")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    Text("Choose how to add your vinyl")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showAddMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showScanner = true }
                    } label: {
                        Text("Scan Barcode")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        showAddMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showManualSearch = true }
                    } label: {
                        Text("Search manually")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                    Spacer()
                }
                .padding(24)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showScanner) {
                ZStack {
                    if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                        ScannerView(scannedCode: $scannedCode)
                            .ignoresSafeArea()
                    } else {
                        Color.black.ignoresSafeArea()
                        Text("Fotocamera non supportata o permessi mancanti.")
                            .foregroundColor(.white)
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button { showScanner = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
            .onChange(of: scannedCode) { _, code in
                if let validCode = code {
                    print("🔍 Barcode letto: \(validCode)")
                    showScanner = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if let found = viewModel.searchByBarcode(validCode) {
                            print("✅ Match trovato nel DB SQLite: \(found.title) di \(found.artist)")
                            
                            // Salvataggio permanente
                            modelContext.insert(found)
                            do {
                                try modelContext.save()
                                print("💾 SwiftData: vinile salvato con successo!")
                            } catch {
                                print("❌ Errore salvataggio SwiftData: \(error)")
                            }
                            
                            lastFoundVinyl = found
                            showFoundAlert = true
                        } else {
                            print("❌ Nessun match nel DB per il barcode: \(validCode)")
                            lastFailedBarcode = validCode
                            showNotFoundAlert = true
                        }
                    }
                    scannedCode = nil
                }
            }
            .alert("Vinile Trovato! 🎉", isPresented: $showFoundAlert, presenting: lastFoundVinyl) { _ in
                Button("Fantastico!", role: .cancel) { }
            } message: { vinyl in
                Text("Aggiunto alla tua collezione:\n\"\(vinyl.title)\" di \(vinyl.artist)")
            }
            .alert("Nessun Risultato", isPresented: $showNotFoundAlert) {
                Button("Cerca Manualmente") {
                    showManualSearch = true
                }
                Button("Annulla", role: .cancel) { }
            } message: {
                Text("Non abbiamo trovato corrispondenze per il codice '\(lastFailedBarcode)' nel database offline.\n\nVuoi cercarlo per titolo o artista?")
            }
            .sheet(isPresented: $showManualSearch) {
                ManualSearchView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Search View

struct ManualSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    var viewModel: CollectionViewModel
    @State private var searchText = ""
    var searchResults: [Vinyl] { viewModel.searchManually(query: searchText) }
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Text("Cerca un vinile per artista o titolo nel database.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(searchResults) { result in
                        Button {
                            modelContext.insert(result)
                            dismiss()
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                                VStack(alignment: .leading) {
                                    Text(result.title).font(.headline).foregroundColor(.primary)
                                    Text(result.artist).font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Titolo o Artista")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } }
            }
        }
    }
}

// MARK: - Scanner Nativo VisionKit
struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false, // Meno stress per il sensore, evita il crash FigCapture
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: ScannerView
        init(_ parent: ScannerView) { self.parent = parent }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            if let item = addedItems.first, case .barcode(let barcode) = item {
                // Ferma prima la cattura video
                dataScanner.stopScanning()
                
                DispatchQueue.main.async {
                    self.parent.scannedCode = barcode.payloadStringValue
                    self.parent.dismiss()
                }
            }
        }
    }
}

// MARK: - Stats View

struct StatsTabView: View {
    @Query private var vinyls: [Vinyl]
    
    var artistStats: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: vinyls, by: { $0.artist }).mapValues { $0.count }
        return counts.map { (name: $0.key, count: $0.value) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading) {
                        Text("Most Collected")
                            .font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary).padding(.bottom, 4)
                        if artistStats.isEmpty {
                            Text("Aggiungi dei vinili per visualizzare le statistiche.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                        } else {
                            Chart(artistStats, id: \.name) { stat in
                                BarMark(x: .value("Artist", stat.name), y: .value("Count", stat.count))
                                    .foregroundStyle(Color.green.gradient).cornerRadius(4)
                                    .annotation(position: .top, alignment: .center) {
                                        Text("\(stat.count)").font(.caption2).foregroundColor(.secondary)
                                    }
                            }
                            .frame(height: 180)
                        }
                    }.padding(.vertical, 8)
                } header: { Text("Overview") }
                
                if !artistStats.isEmpty {
                    Section(header: Text("Top Artists")) {
                        ForEach(artistStats.sorted(by: { $0.count > $1.count }), id: \.name) { stat in
                            HStack { Text(stat.name); Spacer(); Text("\(stat.count)").foregroundColor(.secondary) }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }
}

// MARK: - Hi-Fi View

struct HiFiTabView: View {
    @Bindable var viewModel: CollectionViewModel
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    
    @State private var showAddSetup = false
    @State private var newSetupGenre = ""
    @State private var activeProfileID: UUID?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach($viewModel.hifiProfiles) { $profile in
                    Section {
                        ForEach($profile.setups) { $setup in
                            NavigationLink {
                                HiFiDetailView(setup: $setup)
                            } label: {
                                Text(setup.genre)
                                    .font(.headline)
                                    .padding(.vertical, 4)
                            }
                        }
                        
                        Button {
                            activeProfileID = profile.id
                            showAddSetup = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Aggiungi Genere")
                            }
                            .foregroundColor(.green)
                            .font(.subheadline)
                        }
                        
                    } header: {
                        Text(profile.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .textCase(nil)
                    }
                }
            }
            .navigationTitle("Hi-Fi Setups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddProfile = true
                    } label: {
                        Image(systemName: "plus").foregroundColor(.green)
                    }
                }
            }
            .alert("Nuovo Impianto", isPresented: $showAddProfile) {
                TextField("Nome Impianto (es. Salotto)", text: $newProfileName)
                Button("Annulla", role: .cancel) { newProfileName = "" }
                Button("Aggiungi") {
                    if !newProfileName.isEmpty {
                        viewModel.addHiFiProfile(name: newProfileName)
                        newProfileName = ""
                    }
                }
            }
            .alert("Aggiungi Regolazione", isPresented: $showAddSetup) {
                TextField("Genere (es. Elettronica)", text: $newSetupGenre)
                Button("Annulla", role: .cancel) { newSetupGenre = "" }
                Button("Aggiungi") {
                    if let id = activeProfileID, !newSetupGenre.isEmpty {
                        viewModel.addSetup(to: id, genre: newSetupGenre)
                        newSetupGenre = ""
                    }
                }
            }
        }
    }
}

struct HiFiDetailView: View {
    @Binding var setup: HiFiSetup
    
    var body: some View {
        Form {
            Section(header: Text("Equalizzatore (EQ)")) {
                SliderRow(title: "Alti (Treble)", value: $setup.treble, range: -10...10, unit: "dB")
                SliderRow(title: "Medi (Midrange)", value: $setup.mid, range: -10...10, unit: "dB")
                SliderRow(title: "Bassi (Bass)", value: $setup.bass, range: -10...10, unit: "dB")
            }
            
            Section(header: Text("Controlli Sistema")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Bilanciamento L/R")
                        Spacer()
                        Text(balanceText(setup.balance))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $setup.balance, in: -5...5, step: 1)
                        .tint(setup.balance == 0 ? .gray : .green)
                }
                .padding(.vertical, 4)
                
                SliderRow(title: "Livello Subwoofer", value: $setup.subwooferLevel, range: 0...10, unit: "")
                
                Toggle("Loudness", isOn: $setup.isLoudnessEnabled)
                    .tint(.green)
            }
            
            Section(header: Text("Note di Ascolto e Posizionamento")) {
                TextEditor(text: $setup.notes)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle(setup.genre)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func balanceText(_ val: Double) -> String {
        if val == 0 { return "Centro" }
        if val < 0 { return "L \(Int(abs(val)))" }
        return "R \(Int(val))"
    }
}

struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value > 0 && unit == "dB" ? "+" : "")\(Int(value)) \(unit)")
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, step: 1)
                .tint(value == 0 && unit == "dB" ? .gray : .green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Benvenuto in")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Vinilly")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.green.gradient)
            }
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "barcode.viewfinder",
                    color: .blue,
                    title: "Scansione Istantanea",
                    description: "Inquadra il codice a barre sul retro della copertina per riconoscere il disco in un attimo."
                )
                
                FeatureRow(
                    icon: "externaldrive.fill.badge.checkmark",
                    color: .green,
                    title: "100% Offline",
                    description: "Un archivio completo integrato sul dispositivo. Nessuna API esterna, naviga ovunque."
                )
                
                FeatureRow(
                    icon: "slider.vertical.3",
                    color: .orange,
                    title: "Setup & Profili Hi-Fi",
                    description: "Salva i parametri di equalizzazione (bassi, medi, alti e loudness) dedicati a ciascun genere e impianto."
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button {
                hasSeenOnboarding = true
                dismiss()
            } label: {
                Text("Inizia")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
    }
}

struct FeatureRow: View {
    var icon: String
    var color: Color
    var title: String
    var description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ContentView()
}
