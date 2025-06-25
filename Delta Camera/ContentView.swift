//
//  ContentView.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/29/25.
//

import SwiftUI

import Roxas
import DeltaCore
import GBCDeltaCore

import CaptureKit
import ZIPFoundation

// Copied from Delta
enum ImportError: LocalizedError, Hashable, Equatable
{
    case doesNotExist(URL)
    case invalid(URL)
    case unsupported(URL)
    case unknown(URL, NSError)
    case saveFailed(Set<URL>, NSError)
    
    var errorDescription: String? {
        switch self
        {
        case .doesNotExist: return NSLocalizedString("The file does not exist.", comment: "")
        case .invalid: return NSLocalizedString("The file is invalid.", comment: "")
        case .unsupported: return NSLocalizedString("This file is not supported.", comment: "")
        case .unknown(_, let error): return error.localizedDescription
        case .saveFailed(_, let error): return error.localizedDescription
        }
    }
}

struct ContentView: View
{
    @SwiftUI.State
    private var isImporting: Bool = false
    
    @SwiftUI.State
    private var importError: Error?
    
    @SwiftUI.State
    private var showingErrorAlert: Bool = false
    
    @SwiftUI.State
    private var isGameImported: Bool // No default value since otherwise it can't be changed in init().
    
    init()
    {
        let isGameImported = FileManager.default.fileExists(atPath: URL.gameFileURL.path())
        self.isGameImported = isGameImported
    }
    
    var body: some View {
        if isGameImported
        {
            let game = Game(fileURL: .gameFileURL, type: .gbc)
            GameView(game: game)
        }
        else
        {
            importView
        }
    }
    
    private var importView: some View {
        VStack(spacing: 15) {
            Image(systemName: "camera")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Button("Choose Game Boy Camera ROM…") {
                isImporting = true
            }
        }
        .padding()
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.gb, .gbc, .zip]) { result in
            importGame(with: result)
        }
        .alert("Unable to Open Game", isPresented: $showingErrorAlert, presenting: importError) { error in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

private extension ContentView
{
    func importGame(with result: Result<URL, Error>)
    {
        Task<Void, Never> {
            do
            {
                let fileURL = try result.get()
                
                guard fileURL.startAccessingSecurityScopedResource() else { return }
                defer {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                
                let gameURL: URL
                if fileURL.pathExtension == "zip"
                {
                    let extractedGameURL = try self.unzipGame(at: fileURL)
                    gameURL = extractedGameURL
                }
                else
                {
                    gameURL = fileURL
                }
                
                _ = try FileManager.default.copyItem(at: gameURL, to: .gameFileURL, shouldReplace: true)
                
                isGameImported = true
            }
            catch
            {
                importError = error
                showingErrorAlert = true
            }
        }
    }
    
    // Heavily based on Delta's DatabaseManager.extractCompressedGames(at:completion:)
    private func unzipGame(at url: URL) throws(ImportError) -> URL
    {
        var gameURL: URL?
        
        guard let archive = Archive(url: url, accessMode: .read) else { throw .invalid(url) }
        
        for entry in archive
        {
            do
            {
                // Ensure entry is not in a subdirectory
                guard !entry.path.contains("/") else { continue }
                
                let fileExtension = (entry.path as NSString).pathExtension.lowercased()
                
                guard fileExtension == "gb" || fileExtension == "gbc" else { continue }
                
                // Must use temporary directory, and not the directory containing zip file, since the latter might be read-only (such as when importing from Safari)
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(entry.path)
                
                if FileManager.default.fileExists(atPath: outputURL.path)
                {
                    try FileManager.default.removeItem(at: outputURL)
                }
                
                _ = try archive.extract(entry, to: outputURL, skipCRC32: true)
                
                gameURL = outputURL
            }
            catch let error
            {
                throw .unknown(url, error as NSError)
            }
        }
        
        guard let gameURL else { throw .invalid(url) }
        return gameURL
    }
}

#Preview {
    ContentView()
}
