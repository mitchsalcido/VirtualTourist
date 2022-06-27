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
    
    static var flickURLArray:[URL] = []
    
    struct UserInfo {
        static let apikey = "f966f92b0e383ff5e2807efe3be9891f"
    }
    
    struct APIInfo {
        static let scheme = "https"
        static let host = "www.flickr.com"
        static let path = "/services/rest/"
        static let urlHost = "live.staticflickr.com"
    }
    
    enum Endpoints {
        case searchText(String)
        case searchGeo(lat: Float, lon: Float)
        
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
            case .searchGeo(let lat, let lon):
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
    
    class func geoSearchFlickr(latitude: Float, longitude: Float, completion: @escaping (Bool, Error?) -> Void) {
        
        guard let url = Endpoints.searchGeo(lat: latitude, lon: longitude).url else {
            completion(false, FlickrError.urlError)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion(false, error)
                return
            }
            
            do {
                let response = try JSONDecoder().decode(FlickrSearchResponse.self, from: data)
                flickURLArray = createURLArray(response: response)
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
        task.resume()
    }
    
    class func textSearchFlickr(text: String, completion: @escaping (Bool, Error?) -> Void) {
        
        guard let url = Endpoints.searchText(text).url else {
            completion(false, FlickrError.urlError)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion(false, error)
                return
            }
            
            do {
                let response = try JSONDecoder().decode(FlickrSearchResponse.self, from: data)
                flickURLArray = createURLArray(response: response)
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
        task.resume()
    }
}

extension FlickrAPI {
    
    // parse FlickrSearchResponse and return url strings formatter per Flickr API docs
    static func createURLArray(response: FlickrSearchResponse) -> [URL] {
        
        let photos = response.photos
        let photo = photos.photo
        
        var urlArray:[URL] = []
        var components = URLComponents()
        components.scheme = APIInfo.scheme
        components.host = APIInfo.urlHost
        for flick in photo {
            let server = flick.server
            let id = flick.id
            let secret = flick.secret
            let path = "/" + server + "/" + id + "_" + secret + ".jpg"
            components.path = path
            if let url = components.url {
                urlArray.append(url)
            }
        }
        return urlArray
    }
}
