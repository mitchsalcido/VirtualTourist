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
import UIKit
import CoreLocation

class FlickrAPI {
    
    static let MAX_FLICKS = 30
    static var foundFlicksArray:[[String:String]] = []

    struct UserInfo {
        static let apikey = "f966f92b0e383ff5e2807efe3be9891f"
    }
    
    struct APIInfo {
        static let scheme = "https"
        static let host = "www.flickr.com"
        static let path = "/services/rest/"
        static let urlHostBase = "https://live.staticflickr.com/"
    }
    
    enum Endpoints {
        case searchGeo(lat: Double, lon: Double)
        
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
        case badFlickrDownload
        
        var errorDescription: String? {
            switch self {
            case .urlError:
                return "Bad URL"
            case .badFlickrDownload:
                return "Bad Flickr download."
            }
        }
        var failureReason: String? {
            switch self {
            case .urlError:
                return "Possbile bad text formatting."
            case .badFlickrDownload:
                return "Bad data/response from Flickr."
            }
        }
        var helpAnchor: String? {
            return "Contact developer for prompt and courteous service."
        }
        var recoverySuggestion: String? {
            return "Close App and re-open."
        }
    }
}

extension FlickrAPI {
    
    class func geoSearchFlickr(latitude: Double, longitude: Double, completion: @escaping (Bool, Error?) -> Void) {
        
        guard let url = Endpoints.searchGeo(lat: latitude, lon: longitude).url else {
            completion(false, FlickrError.urlError)
            return
        }
        taskGET(url: url, responseType: FlickrSearchResponse.self) { response, error in
            guard let response = response else {
                completion(false, error)
                return
            }
            foundFlicksArray = createRandomURLStringArray(response: response)
            completion(true, nil)
        }
    }

    class func getFlickData(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion(nil, error)
                return
            }
            completion(data, nil)
        }
        task.resume()
    }
    
    class func reverseGeoCode(location: CLLocation, completion: @escaping (String?, Error?) -> Void) {
        
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(location) { placemarks, error in
            
            guard let placeMark = placemarks?.first else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            var name = "Unknown"
            if let local = placeMark.locality {
                name = local
            } else if let local = placeMark.administrativeArea {
                name = local
            } else if let local = placeMark.country {
                name = local
            } else if let local = placeMark.ocean {
                name = local
            }
            DispatchQueue.main.async {
                completion(name, nil)
            }
        }
    }
}

extension FlickrAPI {
    
    class func taskGET<ResponseType: Decodable>(url: URL, responseType:ResponseType.Type, completion: @escaping (ResponseType?, Error?) -> Void) {
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            do {
                let response = try JSONDecoder().decode(responseType.self, from: data)
                DispatchQueue.main.async {
                    completion(response, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
        }
        task.resume()
    }
}

extension FlickrAPI {
    
    // parse FlickrSearchResponse and return url string/title formatted per Flickr API docs
    class func createRandomURLStringArray(response: FlickrSearchResponse) -> [[String:String]] {
        
        // array of flicks
        var photo = response.photos.photo
        
        // random photo responses, limited to MAX_FLICKS
        var randomPhotoArray:[PhotoResponse] = []
        while (photo.count > 0) && (randomPhotoArray.count < MAX_FLICKS) {
            let randomIndex = Int.random(in: 0..<photo.count)
            randomPhotoArray.append(photo.remove(at: randomIndex))
        }
        
        // create a dictionary containing [URLString:Title]
        var dictionary:[String:String] = [:]
        for (index, flick) in randomPhotoArray.enumerated() {
            
            // per Flickr API
            let urlString = APIInfo.urlHostBase + flick.server + "/" + flick.id + "_" + flick.secret + ".jpg"
            let title = (flick.title == "") ? ("Flick: \(index)") : flick.title
            
            dictionary[urlString] = title
        }
        
        // sort by url string..same order that's used in AlbumView
        var urlStringArray:[[String:String]] = []
        for key in dictionary.keys.sorted() {
            if let value = dictionary[key] {
                urlStringArray.append([key:value])
            }
        }
        return urlStringArray
    }
}
