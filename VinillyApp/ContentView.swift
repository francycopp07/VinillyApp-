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
import PhotosUI

// MARK: - App Entry Point & ContentView

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Vinyl Cover View & Helpers

struct VinylCoverView: View {
    let vinyl: Vinyl
    let size: CGFloat
    
    var body: some View {
        Group {
            if let customData = vinyl.customImageData, let uiImage = UIImage(data: customData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let coverUrl = vinyl.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        customPlaceholder
                    }
                }
            } else {
                customPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
    }
    
    private var customPlaceholder: some View {
        let bgColor = Color(hex: vinyl.customColorHex ?? "#1E1E1E")
        let emoji = vinyl.customEmoji ?? ""
        
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bgColor.gradient)

            Circle()
                .strokeBorder(Color.white.opacity(0.08), lineWidth: size * 0.12)
                .padding(size * 0.1)
            
            if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.35))
            } else {
                Image(systemName: "opticaldisc.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.32)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleanHex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (30, 30, 30)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
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
        HiFiProfile(name: "Living Room Setup (Towers)", setups: [
            HiFiSetup(genre: "Rock", notes: "Pronounced mid-bass, attenuated tweeters.", bass: 2, mid: 1, treble: -1, balance: 0, subwooferLevel: 4, isLoudnessEnabled: false),
            HiFiSetup(genre: "Jazz", notes: "Direct/Flat to keep brass natural.", bass: 0, mid: 0, treble: 0, balance: 0, subwooferLevel: 2, isLoudnessEnabled: false)
        ]),
        HiFiProfile(name: "Studio Setup (Bookshelf)", setups: [
            HiFiSetup(genre: "Pop", notes: "Loudness active for low-volume listening.", bass: 3, mid: 0, treble: 2, balance: -1, subwooferLevel: 6, isLoudnessEnabled: true)
        ])
    ]
    
    func searchByBarcode(_ code: String) -> Vinyl? {
        return DatabaseService.shared.searchByBarcode(code)
    }
    
    func searchManually(query: String) -> [Vinyl] {
        return DatabaseService.shared.searchByText(query: query)
    }
    
    func getOtherVinylsByArtist(artist: String, excludingBarcode: String) -> [Vinyl] {
        return DatabaseService.shared.fetchOtherVinylsByArtist(artist: artist, excludingBarcode: excludingBarcode)
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
        }
        .tint(.green)
    }
}

// MARK: - Collection Tab View with SwiftData Persistence

struct CollectionTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vinyl.addedAt, order: .reverse) private var vinyls: [Vinyl]
    
    var viewModel: CollectionViewModel
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var selectedVinylForDetail: Vinyl? = nil
    
    @State private var showAddMenu = false
    @State private var showScanner = false
    @State private var showManualSearch = false
    @State private var scannedCode: String? = nil
    
    @State private var showFoundAlert = false
    @State private var showNotFoundAlert = false
    @State private var lastFoundVinyl: Vinyl? = nil
    @State private var lastFailedBarcode: String = ""
    
    @State private var selectedVinylToEdit: Vinyl? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if vinyls.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "bolt")
                            .font(.system(size: 90, weight: .light))
                            .foregroundStyle(.green.gradient)
                            .symbolEffect(.pulse.byLayer, options: .repeating)
                        
                        Text("Your Collection is empty.")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add your first vinyl by scanning the barcode on the back cover or searching the offline database.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showAddMenu = true
                        } label: {
                            Label("Add Vinyl", systemImage: "plus")
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
                                        VinylCoverView(vinyl: vinyl, size: 250)
                                            .onTapGesture {
                                                selectedVinylForDetail = vinyl
                                            }
                                            .contextMenu {
                                                Button {
                                                    selectedVinylToEdit = vinyl
                                                } label: {
                                                    Label("Customize Cover", systemImage: "paintbrush.fill")
                                                }
                                                
                                                Button(role: .destructive) {
                                                    modelContext.delete(vinyl)
                                                    try? modelContext.save()
                                                } label: {
                                                    Label("Remove from Collection", systemImage: "trash")
                                                }
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
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedVinylForDetail = vinyl
                                    }
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
            .navigationTitle("My Collection")
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
            .sheet(item: $selectedVinylToEdit) { vinyl in
                EditCoverSheet(vinyl: vinyl)
            }
            .sheet(item: $selectedVinylForDetail) { vinyl in
                NavigationStack {
                    VinylDetailView(vinyl: vinyl, viewModel: viewModel)
                }
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
                        Text("Search Manually")
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
                        Text("Camera not supported or permission denied.")
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
                    showScanner = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if let found = viewModel.searchByBarcode(validCode) {
                            modelContext.insert(found)
                            do {
                                try modelContext.save()
                            } catch {
                                print("❌ Error while saving in SwiftData: \(error)")
                            }
                            
                            lastFoundVinyl = found
                            showFoundAlert = true
                        } else {
                            lastFailedBarcode = validCode
                            showNotFoundAlert = true
                        }
                    }
                    scannedCode = nil
                }
            }
            .alert("Vinyl Found! 🎉", isPresented: $showFoundAlert, presenting: lastFoundVinyl) { _ in
                Button("Great!", role: .cancel) { }
            } message: { vinyl in
                Text("Added to your collection:\n\"\(vinyl.title)\" by \(vinyl.artist)")
            }
            .alert("No Results Found", isPresented: $showNotFoundAlert) {
                Button("Search Manually") {
                    showManualSearch = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("No match found for barcode '\(lastFailedBarcode)' in the offline database.\n\nWould you like to search by title or artist?")
            }
            .sheet(isPresented: $showManualSearch) {
                ManualSearchView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Edit Cover Sheet

struct EditCoverSheet: View {
    @Bindable var vinyl: Vinyl
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: PhotosPickerItem? = nil
    
    let colorPalette = [
        "#1C1C1E", "#2C3E50", "#E63946", "#F4A261",
        "#E76F51", "#2A9D8F", "#457B9D", "#1D3557",
        "#6A4C93", "#8338EC", "#3A86FF", "#2B9348"
    ]
    
    let emojiSuggestions = ["🎵", "🎸", "🎷", "🎹", "✨", "🔥", "⚡️", "☕️", "🌙", "🌊", "🍄", "💿"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VinylCoverView(vinyl: vinyl, size: 150)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Photo Library")) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.badge.plus")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                if let uiImage = UIImage(data: data),
                                   let compressedData = uiImage.jpegData(compressionQuality: 0.75) {
                                    vinyl.customImageData = compressedData
                                    vinyl.customEmoji = nil
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    
                    if vinyl.customImageData != nil {
                        Button(role: .destructive) {
                            vinyl.customImageData = nil
                            try? modelContext.save()
                        } label: {
                            Label("Remove Custom Photo", systemImage: "trash")
                        }
                    }
                }
                
                Section(header: Text("Placeholder Color")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(colorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(height: 38)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: (vinyl.customColorHex == hex) ? 3 : 0)
                                )
                                .onTapGesture {
                                    vinyl.customColorHex = hex
                                    vinyl.customImageData = nil
                                    try? modelContext.save()
                                }
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                Section(header: Text("Placeholder Emoji")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(emojiSuggestions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background((vinyl.customEmoji == emoji) ? Color.green.opacity(0.2) : Color.gray.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green, lineWidth: (vinyl.customEmoji == emoji) ? 2 : 0)
                                )
                                .onTapGesture {
                                    vinyl.customEmoji = emoji
                                    vinyl.customImageData = nil
                                    try? modelContext.save()
                                }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Customize Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Vinyl Detail View

struct VinylDetailView: View {
    @Bindable var vinyl: Vinyl
    var viewModel: CollectionViewModel
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var otherVinyls: [Vinyl] = []
    @State private var showEditCover = false
    @State private var showAddedSuccessAlert = false
    @State private var newlyAddedVinylTitle = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack(alignment: .bottomTrailing) {
                    VinylCoverView(vinyl: vinyl, size: 260)
                    
                    Button {
                        showEditCover = true
                    } label: {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .padding(12)
                }
                .padding(.top, 16)
                
                VStack(spacing: 6) {
                    Text(vinyl.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(vinyl.artist)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 14) {
                    InfoDetailRow(icon: "calendar", title: "Release Year", value: vinyl.year)
                    Divider()
                    InfoDetailRow(icon: "guitars.fill", title: "Genre", value: vinyl.genre)
                    Divider()
                    InfoDetailRow(icon: "barcode", title: "Barcode", value: vinyl.barcode)
                    Divider()
                    InfoDetailRow(
                        icon: "clock.badge.checkmark",
                        title: "Added on",
                        value: vinyl.addedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                .padding(18)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("More by \(vinyl.artist)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    if otherVinyls.isEmpty {
                        HStack {
                            Spacer()
                            Text("No other records found by this artist in the database.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 16)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(otherVinyls) { other in
                                    VStack(alignment: .leading, spacing: 8) {
                                        VinylCoverView(vinyl: other, size: 140)
                                        
                                        Text(other.title)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .frame(width: 140, alignment: .leading)
                                        
                                        Text(other.year)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Button {
                                            modelContext.insert(other)
                                            try? modelContext.save()
                                            newlyAddedVinylTitle = other.title
                                            showAddedSuccessAlert = true
                                        } label: {
                                            Label("Add", systemImage: "plus")
                                                .font(.caption.bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 6)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundColor(.green)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .frame(width: 140)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 10)
                
                Spacer(minLength: 30)
            }
        }
        .navigationTitle("Record Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            otherVinyls = viewModel.getOtherVinylsByArtist(
                artist: vinyl.artist,
                excludingBarcode: vinyl.barcode
            )
        }
        .sheet(isPresented: $showEditCover) {
            EditCoverSheet(vinyl: vinyl)
        }
        .alert("Added to Collection! 🎉", isPresented: $showAddedSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\"\(newlyAddedVinylTitle)\" has been added to your collection.")
        }
    }
}

struct InfoDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
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
                    Text("Search for a vinyl by artist or title in the database.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(searchResults) { result in
                        Button {
                            modelContext.insert(result)
                            try? modelContext.save()
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
            .searchable(text: $searchText, prompt: "Title or Artist")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
    }
}

// MARK: - Native VisionKit Scanner

struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
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
                dataScanner.stopScanning()
                
                DispatchQueue.main.async {
                    self.parent.scannedCode = barcode.payloadStringValue
                    self.parent.dismiss()
                }
            }
        }
    }
}

// MARK: - Stats View (Advanced Audiophile Dashboard)

struct StatsTabView: View {
    @Query private var vinyls: [Vinyl]
    
    // MARK: - Computed Metrics
    
    private var totalRecords: Int { vinyls.count }
    
    private var uniqueArtistsCount: Int {
        Set(vinyls.map { $0.artist }).count
    }
    
    private var estimatedPlaytimeHours: String {
        let totalMinutes = vinyls.count * 42
        let hours = totalMinutes / 60
        return "\(hours)h"
    }
    
    private var artistStats: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: vinyls, by: { $0.artist }).mapValues { $0.count }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var genreStats: [(genre: String, count: Int)] {
        let counts = Dictionary(grouping: vinyls, by: { $0.genre.isEmpty ? "Unknown" : $0.genre }).mapValues { $0.count }
        return counts.map { (genre: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var topGenre: String {
        genreStats.first?.genre ?? "N/A"
    }
    
    private var decadeStats: [(decade: String, count: Int)] {
        let validYears = vinyls.compactMap { Int($0.year) }
        let grouped = Dictionary(grouping: validYears) { year -> String in
            let decadeStart = (year / 10) * 10
            return "\(decadeStart)s"
        }
        return grouped.map { (decade: $0.key, count: $0.value.count) }
            .sorted { $0.decade < $1.decade }
    }
    
    private var collectionVelocity: [(month: String, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: vinyls) { vinyl -> String in
            let components = calendar.dateComponents([.year, .month], from: vinyl.addedAt)
            let month = components.month ?? 1
            return calendar.shortMonthSymbols[month - 1]
        }
        return grouped.map { (month: $0.key, count: $0.value.count) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if vinyls.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 22) {
                        kpiHighlightsGrid
                        
                        if collectionVelocity.count > 1 {
                            growthTrendCard
                        }
                        
                        topArtistsCard
                        
                        if genreStats.count > 1 {
                            genreBreakdownCard
                        }
                        
                        if !decadeStats.isEmpty {
                            decadesCard
                        }
                        
                        topArtistsLeaderboard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Analytics")
        }
    }
    
    // MARK: - Subviews & Cards
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.green.gradient)
            }
            Text("No Analytics Available")
                .font(.title2.bold())
            Text("Add vinyls to your shelf to reveal your listening personality, collection timeline, and artist insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer(minLength: 120)
        }
    }
    
    private var kpiHighlightsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            KPIMetricCard(icon: "opticaldisc.fill", title: "Total Shelf", value: "\(totalRecords) LPs", accentColor: .green)
            KPIMetricCard(icon: "person.2.fill", title: "Unique Artists", value: "\(uniqueArtistsCount)", accentColor: .blue)
            KPIMetricCard(icon: "guitars.fill", title: "Top Genre", value: topGenre, accentColor: .orange)
            KPIMetricCard(icon: "play.circle.fill", title: "Est. Playtime", value: estimatedPlaytimeHours, accentColor: .purple)
        }
    }
    
    private var growthTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Growth Velocity", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Text("Collection Pace")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Chart(collectionVelocity, id: \.month) { item in
                AreaMark(
                    x: .value("Month", item.month),
                    y: .value("Added", item.count)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.4), Color.green.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(
                    x: .value("Month", item.month),
                    y: .value("Added", item.count)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .foregroundStyle(Color.green)
            }
            .frame(height: 140)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Most Collected Artists", systemImage: "crown.fill")
                .font(.headline)
            
            let topFive = Array(artistStats.prefix(5))
            
            Chart(topFive, id: \.name) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Artist", item.name)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(6)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(item.count)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption.weight(.medium))
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(topFive.count * 44, 140)))
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var genreBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Sound Spectrum", systemImage: "waveform.badge.magnifyingglass")
                .font(.headline)
            
            HStack(spacing: 20) {
                Chart(genreStats, id: \.genre) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.65),
                        angularInset: 2.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Genre", item.genre))
                }
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(genreStats.prefix(4)), id: \.genre) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green.opacity(0.75))
                                .frame(width: 8, height: 8)
                            
                            Text(item.genre)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            let pct = (Double(item.count) / Double(max(totalRecords, 1))) * 100
                            Text("\(Int(pct))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var decadesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Eras & Release Decades", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            
            Chart(decadeStats, id: \.decade) { item in
                BarMark(
                    x: .value("Decade", item.decade),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(6)
            }
            .frame(height: 120)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption2.weight(.medium))
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var topArtistsLeaderboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Artist Ranking", systemImage: "list.number")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(Array(artistStats.prefix(6).enumerated()), id: \.element.name) { index, stat in
                    HStack(spacing: 14) {
                        Text(index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "\(index + 1)")
                            .font(.subheadline.bold())
                            .frame(width: 28, alignment: .center)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(stat.count) \(stat.count == 1 ? "record" : "records")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    if index < min(artistStats.count - 1, 5) {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

// MARK: - KPI Card Component

struct KPIMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(accentColor)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Hi-Fi Studio Deck View

struct HiFiTabView: View {
    @Bindable var viewModel: CollectionViewModel
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    @State private var showAddSetup = false
    @State private var newSetupGenre = ""
    @State private var activeProfileID: UUID?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    audiophileHeaderBanner
                    
                    ForEach($viewModel.hifiProfiles) { $profile in
                        HiFiProfileDeckView(
                            profile: $profile,
                            onAddGenre: {
                                activeProfileID = profile.id
                                showAddSetup = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Hi-Fi Rack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddProfile = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
            }
            .alert("New Listening Room", isPresented: $showAddProfile) {
                TextField("E.g. Living Room Tubes, Studio Desk", text: $newProfileName)
                Button("Cancel", role: .cancel) { newProfileName = "" }
                Button("Create") {
                    if !newProfileName.isEmpty {
                        viewModel.addHiFiProfile(name: newProfileName)
                        newProfileName = ""
                    }
                }
            }
            .alert("Add Sound Profile", isPresented: $showAddSetup) {
                TextField("Music Genre (e.g. Ambient, Funk)", text: $newSetupGenre)
                Button("Cancel", role: .cancel) { newSetupGenre = "" }
                Button("Save Preset") {
                    if let id = activeProfileID, !newSetupGenre.isEmpty {
                        viewModel.addSetup(to: id, genre: newSetupGenre)
                        newSetupGenre = ""
                    }
                }
            }
        }
    }
    
    private var audiophileHeaderBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ANALOG EQUALIZER & DSP")
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundColor(.green)
                Text("Sound Tuning Center")
                    .font(.title3.bold())
                Text("Calibrate acoustic tone curves, balance & gain per setup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "tuningfork")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Profile Deck Component

struct HiFiProfileDeckView: View {
    @Binding var profile: HiFiProfile
    var onAddGenre: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hifispeaker.2.fill")
                    .foregroundColor(.green)
                Text(profile.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(profile.setups.count) Presets")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            
            if profile.setups.isEmpty {
                Text("No acoustic presets for this room yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach($profile.setups) { $setup in
                        NavigationLink {
                            HiFiDetailView(setup: $setup)
                        } label: {
                            HStack(spacing: 14) {
                                EQCurveMiniPreview(bass: setup.bass, mid: setup.mid, treble: setup.treble)
                                    .frame(width: 50, height: 32)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(setup.genre)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 6) {
                                        Text("B: \(Int(setup.bass))dB")
                                        Text("•")
                                        Text("M: \(Int(setup.mid))dB")
                                        Text("•")
                                        Text("T: \(Int(setup.treble))dB")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if setup.isLoudnessEnabled {
                                    Text("LOUD")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.orange.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                
                                Image(systemName: "slider.horizontal.3")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(14)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
            
            Button(action: onAddGenre) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Tuning Preset")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Interactive Hardware Detail View

struct HiFiDetailView: View {
    @Binding var setup: HiFiSetup
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                interactiveCurveCard
                eqSlidersCard
                dspControlsCard
                notesCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(setup.genre)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Interactive Frequency Response Graph
    
    private var interactiveCurveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Frequency Response (DSP)", systemImage: "waveform.path")
                    .font(.headline)
                Spacer()
                Text("REAL-TIME")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
            }
            
            let curvePoints = calculateCurvePoints(bass: setup.bass, mid: setup.mid, treble: setup.treble)
            
            Chart(curvePoints, id: \.freq) { pt in
                AreaMark(
                    x: .value("Frequency", pt.freq),
                    y: .value("Gain", pt.gain)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.4), Color.green.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(
                    x: .value("Frequency", pt.freq),
                    y: .value("Gain", pt.gain)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(Color.green)
            }
            .chartYScale(domain: -12...12)
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: [100, 1000, 10000]) { val in
                    AxisValueLabel {
                        if let hz = val.as(Int.self) {
                            Text(hz >= 1000 ? "\(hz/1000)kHz" : "\(hz)Hz")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [-10, 0, 10]) { val in
                    AxisValueLabel {
                        if let db = val.as(Int.self) {
                            Text("\(db > 0 ? "+" : "")\(db)dB")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var eqSlidersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Tone Control Equalizer", systemImage: "slider.vertical.3")
                .font(.headline)
            
            HardwareSliderRow(title: "Treble (Highs)", subtitle: "10 kHz Shelf", value: $setup.treble, range: -10...10, unit: "dB")
            Divider()
            HardwareSliderRow(title: "Midrange (Vocals)", subtitle: "1 kHz Peaking", value: $setup.mid, range: -10...10, unit: "dB")
            Divider()
            HardwareSliderRow(title: "Bass (Low End)", subtitle: "100 Hz Shelf", value: $setup.bass, range: -10...10, unit: "dB")
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var dspControlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Staging & Sub-Bass", systemImage: "speaker.wave.3.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stereo Balance")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(balanceText(setup.balance))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Slider(value: $setup.balance, in: -5...5, step: 1)
                    .tint(setup.balance == 0 ? .gray : .green)
            }
            
            Divider()
            
            HardwareSliderRow(title: "Subwoofer LFE Gain", subtitle: "20Hz - 80Hz", value: $setup.subwooferLevel, range: 0...10, unit: "/10")
            
            Divider()
            
            Toggle(isOn: $setup.isLoudnessEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loudness Contour")
                        .font(.subheadline.weight(.semibold))
                    Text("Boosts lows & highs during quiet late-night sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.green)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Acoustics & Cartridge Notes", systemImage: "note.text")
                .font(.headline)
            
            TextEditor(text: $setup.notes)
                .frame(minHeight: 110)
                .padding(8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private func balanceText(_ val: Double) -> String {
        if val == 0 { return "Center" }
        if val < 0 { return "L \(Int(abs(val)))" }
        return "R \(Int(val))"
    }
    
    private func calculateCurvePoints(bass: Double, mid: Double, treble: Double) -> [(freq: Int, gain: Double)] {
        return [
            (20, bass * 0.95),
            (60, bass),
            (150, bass * 0.8),
            (400, mid * 0.4),
            (1000, mid),
            (2500, mid * 0.4),
            (6000, treble * 0.7),
            (12000, treble),
            (20000, treble * 0.9)
        ]
    }
}

// MARK: - Mini EQ Preview Graphic

struct EQCurveMiniPreview: View {
    let bass: Double
    let mid: Double
    let treble: Double
    
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let midY = h / 2
            
            Path { path in
                let bY = midY - CGFloat(bass / 10.0) * (h * 0.38)
                let mY = midY - CGFloat(mid / 10.0) * (h * 0.38)
                let tY = midY - CGFloat(treble / 10.0) * (h * 0.38)
                
                path.move(to: CGPoint(x: 0, y: bY))
                path.addQuadCurve(to: CGPoint(x: w * 0.5, y: mY), control: CGPoint(x: w * 0.25, y: (bY + mY)/2))
                path.addQuadCurve(to: CGPoint(x: w, y: tY), control: CGPoint(x: w * 0.75, y: (mY + tY)/2))
            }
            .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Hardware Slider Component

struct HardwareSliderRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(value > 0 && unit == "dB" ? "+" : "")\(Int(value))\(unit)")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundColor(value != 0 ? .green : .secondary)
            }
            Slider(value: $value, in: range, step: 1)
                .tint(value == 0 && unit == "dB" ? .gray : .green)
        }
        .padding(.vertical, 2)
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
                Text("Welcome to")
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
                    title: "Instant Scanning",
                    description: "Frame the barcode on the back cover to identify your record in seconds."
                )
                
                FeatureRow(
                    icon: "externaldrive.fill.badge.checkmark",
                    color: .green,
                    title: "100% Offline",
                    description: "A complete archive built right into your device. No external APIs needed, browse anywhere."
                )
                
                FeatureRow(
                    icon: "slider.vertical.3",
                    color: .orange,
                    title: "Hi-Fi Profiles & Presets",
                    description: "Save EQ settings (bass, midrange, treble, and loudness) tailored to each genre and sound system."
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button {
                hasSeenOnboarding = true
                dismiss()
            } label: {
                Text("Get Started")
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
