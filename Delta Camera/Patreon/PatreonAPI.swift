//
//  PatreonAPI.swift
//  AltStore
//
//  Created by Riley Testut on 8/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AuthenticationServices
import CoreData
import OSLog

enum PatreonAPIError: LocalizedError
{
    case unknown
    case notAuthenticated
    case invalidAccessToken
    case rateLimitExceeded
    
    var failureReason: String? {
        switch self
        {
        case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
        case .notAuthenticated: return NSLocalizedString("No connected Patreon account.", comment: "")
        case .invalidAccessToken: return NSLocalizedString("Invalid access token.", comment: "")
        case .rateLimitExceeded: return NSLocalizedString("The Patreon API rate limit has been exceeded.", comment: "")
        }
    }
}

extension PatreonAPI
{
    static let altstoreCampaignID = "2863968"
    
    typealias FetchAccountResponse = Response<UserAccountResponse>
    typealias FriendZonePatronsResponse = Response<[PatronResponse]>
    
    enum AuthorizationType
    {
        case none
        case user
        case creator
    }
    
    private struct Tokens: Decodable
    {
        var clientID: String
        var clientSecret: String
    }
}

public class PatreonAPI: NSObject
{
    public static let shared = PatreonAPI()
    
    public var isAuthenticated: Bool {
        return Keychain.shared.patreonAccessToken != nil
    }
    
    private var authenticationSession: ASWebAuthenticationSession?
    
    private let session = URLSession(configuration: .ephemeral)
    private let baseURL = URL(string: "https://www.patreon.com/")!
    
    private let clientID: String
    private let clientSecret: String
    
    private override init()
    {
        let fileURL = Bundle.main.url(forResource: "PatreonAPI", withExtension: "plist")!
        
        do
        {
            let data = try Data(contentsOf: fileURL)
            
            let tokens = try PropertyListDecoder().decode(Tokens.self, from: data)
            self.clientID = tokens.clientID
            self.clientSecret = tokens.clientSecret
            
            if self.clientID.isEmpty || self.clientSecret.isEmpty
            {
                Logger.main.error("PatreonAPI.plist is missing clientID and/or clientSecret. Please provide your own API keys to use Patreon functionality.")
            }
        }
        catch
        {
            Logger.main.error("Failed to load PatreonAPI tokens. \(error.localizedDescription, privacy: .public)")
            
            self.clientID = ""
            self.clientSecret = ""
        }
        
        super.init()
    }
}

public extension PatreonAPI
{
    func authenticate(completion: @escaping (Result<UserAccount, Swift.Error>) -> Void)
    {
        var components = URLComponents(string: "/oauth2/authorize")!
        components.queryItems = [URLQueryItem(name: "response_type", value: "code"),
                                 URLQueryItem(name: "client_id", value: self.clientID),
                                 URLQueryItem(name: "redirect_uri", value: "https://rileytestut.com/patreon/altstore")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        
        self.authenticationSession = ASWebAuthenticationSession(url: requestURL, callbackURLScheme: "altstore") { (callbackURL, error) in
            do
            {
                guard let callbackURL = callbackURL else { throw error ?? URLError(.badURL) }
                                
                guard
                    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let codeQueryItem = components.queryItems?.first(where: { $0.name == "code" }),
                    let code = codeQueryItem.value
                else { throw PatreonAPIError.unknown }
                
                self.fetchAccessToken(oauthCode: code) { (result) in
                    switch result
                    {
                    case .failure(let error): completion(.failure(error))
                    case .success((let accessToken, let refreshToken)):
                        Keychain.shared.patreonAccessToken = accessToken
                        Keychain.shared.patreonRefreshToken = refreshToken
                        
                        self.fetchAccount(completion: completion)
                    }
                }
            }
            catch ASWebAuthenticationSessionError.canceledLogin
            {
                completion(.failure(CancellationError()))
            }
            catch
            {
                completion(.failure(error))
            }
        }
                
        self.authenticationSession?.presentationContextProvider = self
        self.authenticationSession?.start()
    }
    
    func fetchAccount(completion: @escaping (Result<UserAccount, Swift.Error>) -> Void)
    {
        var components = URLComponents(string: "/api/oauth2/v2/identity")!
        components.queryItems = [URLQueryItem(name: "include", value: "memberships.campaign.tiers,memberships.currently_entitled_tiers.benefits"),
                                 URLQueryItem(name: "fields[user]", value: "first_name,full_name"),
                                 URLQueryItem(name: "fields[tier]", value: "title,amount_cents"),
                                 URLQueryItem(name: "fields[benefit]", value: "title"),
                                 URLQueryItem(name: "fields[campaign]", value: "url"),
                                 URLQueryItem(name: "fields[member]", value: "full_name,patron_status,currently_entitled_amount_cents,campaign_lifetime_support_cents")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        let request = URLRequest(url: requestURL)
        
        self.send(request, authorizationType: .user) { (result: Result<FetchAccountResponse, Swift.Error>) in
            switch result
            {
            case .failure(PatreonAPIError.notAuthenticated):
                self.signOut()
                completion(.failure(PatreonAPIError.notAuthenticated))
                
            case .failure(let error as DecodingError):
                do
                {
                    let nsError = error as NSError
                    guard let codingPath = nsError.userInfo["NSCodingPath"] as? [CodingKey] else { throw error }
                    
                    let rawComponents = codingPath.map { $0.intValue?.description ?? $0.stringValue }
                    let pathDescription = rawComponents.joined(separator: " > ")
                                        
                    let localizedDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String ?? nsError.localizedDescription
                    let debugDescription = localizedDescription + " Path: " + pathDescription
                    
                    var userInfo = nsError.userInfo
                    userInfo[NSDebugDescriptionErrorKey] = debugDescription
                    throw NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
                }
                catch let error as NSError
                {
                    let localizedDescription = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
                    Logger.main.error("Failed to fetch Patreon account. \(localizedDescription, privacy: .public)")
                    completion(.failure(error))
                }
                
            case .failure(let error as NSError):
                let localizedDescription = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
                Logger.main.error("Failed to fetch Patreon account. \(localizedDescription, privacy: .public)")
                completion(.failure(error))
                
            case .success(let response):
                let account = PatreonAPI.UserAccount(response: response.data, including: response.included)
                completion(.success(account))
            }
        }
    }
    
    func signOut()
    {
        Keychain.shared.patreonAccessToken = nil
        Keychain.shared.patreonRefreshToken = nil
        Keychain.shared.patreonAccountID = nil
    }
}

private extension PatreonAPI
{
    func fetchAccessToken(oauthCode: String, completion: @escaping (Result<(String, String), Swift.Error>) -> Void)
    {
        let encodedRedirectURI = ("https://rileytestut.com/patreon/altstore" as NSString).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let encodedOauthCode = (oauthCode as NSString).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        
        let body = "code=\(encodedOauthCode)&grant_type=authorization_code&client_id=\(self.clientID)&client_secret=\(self.clientSecret)&redirect_uri=\(encodedRedirectURI)"
        
        let requestURL = URL(string: "/api/oauth2/token", relativeTo: self.baseURL)!
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        struct Response: Decodable
        {
            var access_token: String
            var refresh_token: String
        }
        
        self.send(request, authorizationType: .none) { (result: Result<Response, Swift.Error>) in
            switch result
            {
            case .failure(let error): completion(.failure(error))
            case .success(let response): completion(.success((response.access_token, response.refresh_token)))
            }
        }
    }
    
    func refreshAccessToken(completion: @escaping (Result<Void, Swift.Error>) -> Void)
    {
        guard let refreshToken = Keychain.shared.patreonRefreshToken else { return }
        
        var components = URLComponents(string: "/api/oauth2/token")!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token"),
                                 URLQueryItem(name: "refresh_token", value: refreshToken),
                                 URLQueryItem(name: "client_id", value: self.clientID),
                                 URLQueryItem(name: "client_secret", value: self.clientSecret)]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        
        struct Response: Decodable
        {
            var access_token: String
            var refresh_token: String
        }
        
        self.send(request, authorizationType: .none) { (result: Result<Response, Swift.Error>) in
            switch result
            {
            case .failure(let error): completion(.failure(error))
            case .success(let response):
                Keychain.shared.patreonAccessToken = response.access_token
                Keychain.shared.patreonRefreshToken = response.refresh_token
                
                completion(.success(()))
            }
        }
    }
    
    func send<ResponseType: Decodable>(_ request: URLRequest, authorizationType: AuthorizationType, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void)
    {
        var request = request
        
        switch authorizationType
        {
        case .none: break
        case .creator:
            guard let creatorAccessToken = Keychain.shared.patreonCreatorAccessToken else { return completion(.failure(PatreonAPIError.invalidAccessToken)) }
            request.setValue("Bearer " + creatorAccessToken, forHTTPHeaderField: "Authorization")
            
        case .user:
            guard let accessToken = Keychain.shared.patreonAccessToken else { return completion(.failure(PatreonAPIError.notAuthenticated)) }
            request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }
        
        func send(retryDelay: TimeInterval = 1.0, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void)
        {
            let task = self.session.dataTask(with: request) { (data, response, error) in
                do
                {
                    guard let data else { throw error! }
                    
                    if let response = response as? HTTPURLResponse
                    {
                        switch response.statusCode
                        {
                        case 401:
                            // Unauthorized
                            switch authorizationType
                            {
                            case .creator: completion(.failure(PatreonAPIError.invalidAccessToken))
                            case .none: completion(.failure(PatreonAPIError.notAuthenticated))
                            case .user:
                                self.refreshAccessToken() { (result) in
                                    switch result
                                    {
                                    case .failure(let error): completion(.failure(error))
                                    case .success: self.send(request, authorizationType: authorizationType, completion: completion)
                                    }
                                }
                            }
                            
                            return
                            
                        case 429:
                            // Rate Limited
                            let rateLimitDelay: TimeInterval
                            if let delayString = response.value(forHTTPHeaderField: "Retry-After"), let delay = TimeInterval(delayString)
                            {
                                rateLimitDelay = delay
                            }
                            else
                            {
                                rateLimitDelay = retryDelay
                            }
                            
                            guard rateLimitDelay <= 60 else {
                                // Assume request failed.
                                return completion(.failure(PatreonAPIError.rateLimitExceeded))
                            }
                            
                            Logger.main.error("Patreon API rate limit exceeded. Retrying request after delay: \(rateLimitDelay)")
                            
                            DispatchQueue.global().asyncAfter(deadline: .now() + Double(rateLimitDelay)) {
                                // Double previous delay, in case Patreon API doesn't return Retry-After header.
                                send(retryDelay: rateLimitDelay * 2, completion: completion)
                            }
                            
                            return
                            
                        default: break
                        }
                    }
                    
                    let response = try JSONDecoder().decode(ResponseType.self, from: data)
                    completion(.success(response))
                }
                catch let error
                {
                    completion(.failure(error))
                }
            }
            
            task.resume()
        }
        
        send(completion: completion)
    }
}

extension PatreonAPI: ASWebAuthenticationPresentationContextProviding
{
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor
    {
        return ASPresentationAnchor()
    }
}
