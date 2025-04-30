//
//  GameView.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/30/25.
//

import SwiftUI

import DeltaCore

struct GameView: UIViewControllerRepresentable
{
    let game: Game
    
    func makeUIViewController(context: Context) -> some UIViewController
    {
        let gameViewController = GameViewController()
        gameViewController.game = self.game
        gameViewController.loadViewIfNeeded()
        gameViewController.controllerView.playerIndex = 0
        return gameViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context)
    {
    }
}

#Preview {
    ContentView()
}
