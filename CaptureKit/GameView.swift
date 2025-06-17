//
//  GameView.swift
//  CaptureKit
//
//  Created by Riley Testut on 6/17/25.
//

import SwiftUI

import DeltaCore

public struct GameView: View
{
    let game: Game
    
    public init(game: Game)
    {
        self.game = game
    }
    
    public var body: some View {
        _GameView(game: game)
            .ignoresSafeArea()
            .statusBarHidden()
    }
}

private struct _GameView: UIViewControllerRepresentable
{
    let game: Game
    
    public init(game: Game)
    {
        self.game = game
    }
    
    public func makeUIViewController(context: Context) -> some UIViewController
    {
        let gameViewController = GameViewController()
        gameViewController.game = self.game
        gameViewController.loadViewIfNeeded()
        gameViewController.controllerView.playerIndex = 0
        return gameViewController
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context)
    {
    }
}
