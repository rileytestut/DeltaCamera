//
//  Account.swift
//  AltStoreCore
//
//  Created by Riley Testut on 11/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI
{
    typealias UserAccountResponse = DataResponse<UserAccountAttributes, AnyRelationships>
    
    struct UserAccountAttributes: Decodable
    {
        var first_name: String?
        var full_name: String
    }
}

extension PatreonAPI
{
    public struct UserAccount
    {
        var name: String
        var firstName: String?
        var identifier: String
        
        // Relationships
        var pledges: [Patron]?
        
        // Helper
        var hasBetaAccess: Bool = false
        
        init(response: UserAccountResponse, including included: IncludedResponses?)
        {
            self.identifier = response.id
            self.name = response.attributes.full_name
            self.firstName = response.attributes.first_name
            
            guard let included else { return }
            
            let patrons = included.patrons.values.compactMap { response -> Patron? in
                let patron = Patron(response: response, including: included)
                return patron
            }
            
            self.pledges = patrons
            
            if let altstorePledge = patrons.first(where: { $0.campaign?.identifier == PatreonAPI.altstoreCampaignID })
            {
                let hasBetaAccess = altstorePledge.benefits.contains(where: { $0.identifier == .betaAccess })
                self.hasBetaAccess = hasBetaAccess
            }
            else
            {
                self.hasBetaAccess = false
            }
        }
    }
}
