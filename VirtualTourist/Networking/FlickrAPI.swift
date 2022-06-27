//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

/*
 Key:f966f92b0e383ff5e2807efe3be9891f
*/

import Foundation

class FlickrAPI {
    
    struct UserInfo {
        static let apikey = "f966f92b0e383ff5e2807efe3be9891f"
    }
    
    struct APIInfo {
        static let scheme = "https"
        static let host = "www.flickr.com"
        static let path = "/services/rest/"
    }
    
    enum Endpoints {
        case searchText(String)
        case searchGeo(Float, Float)
        
        var url:URL? {
            var components = URLComponents()
            components.scheme = APIInfo.scheme
            components.host = APIInfo.host
            components.path = APIInfo.path
            var items:[URLQueryItem] = []
            items.append(URLQueryItem(name: "method", value: "flickr.photos.search"))
            items.append(URLQueryItem(name: "api_key", value: UserInfo.apikey))
            items.append(URLQueryItem(name: "format", value: "json"))
            items.append(URLQueryItem(name: "nojsoncallback", value: "1"))

            switch self {
            case .searchText(let text):
                items.append(URLQueryItem(name: "text", value: text))
                break
            case .searchGeo(let lon, let lat):
                items.append(URLQueryItem(name: "lat", value: "\(lat)"))
                items.append(URLQueryItem(name: "lon", value: "\(lon)"))
                break
            }
            components.queryItems = items
            return components.url
        }
    }
    
    enum FlickrError: LocalizedError {
        case urlError
    }
}

extension FlickrAPI {
    
    class func textSearchFlickr(text: String, completion: @escaping (Bool, Error?) -> Void) {
        
        guard let url = Endpoints.searchText(text).url else {
            completion(false, FlickrError.urlError)
            return
        }
        
        print(url)
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                print("bad data")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
                print("good brute force json")
                print(json)
            } catch {
                print("bad brute force json")
            }
            
            do {
                let _ = try JSONDecoder().decode(FlickrSearchResponse.self, from: data)
                print("good json")
            } catch {
                print("bad json")
            }
        }
        task.resume()
    }
}
