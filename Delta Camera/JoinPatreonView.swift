//
//  JoinPatreonView.swift
//  Delta Camera
//
//  Created by Riley Testut on 6/18/25.
//

import SwiftUI

struct JoinPatreonView: View
{
    @Binding
    var isActivePatron: Bool
    
    @State
    private var userAccount: PatreonAPI.UserAccount?
    
    @State
    private var authError: Error?
    
    @State
    private var isShowingErrorAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 15) {
            if let userAccount
            {
                Text("Hi, \(userAccount.name)")
            }
            
            Text("You must be an active patron to use Delta Camera while it is in beta.")
            
            if userAccount == nil
            {
                Button("Connect Patreon Account", action: connectPatreonAccount)
            }
        }
        .padding()
        .preferredColorScheme(.dark)
        .alert("Unable to Connect Patreon Account", isPresented: $isShowingErrorAlert, presenting: authError) { error in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

private extension JoinPatreonView
{
    func connectPatreonAccount()
    {
        PatreonAPI.shared.authenticate { result in
            switch result
            {
            case .failure(let error):
                self.authError = error
                self.isShowingErrorAlert = true
                
            case .success(let account):
                if account.hasBetaAccess
                {
                    Keychain.shared.patreonAccountID = account.identifier
                    self.isActivePatron = true
                }
                else
                {
                    self.isActivePatron = false
                }
                
                self.userAccount = account
            }
        }
    }
}

#Preview {
    JoinPatreonView(isActivePatron: .constant(false))
}
