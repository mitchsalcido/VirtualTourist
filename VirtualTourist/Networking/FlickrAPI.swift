//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//
/*
 About FlickrAPI:
 Handle Flickr API interface, networking, photo search and image download
*/

import Foundation
import UIKit
import CoreLocation

class FlickrAPI {
    
    // constant for maximum download flicks per album
    static let MAX_FLICKS = 50
    
    // store found flicks in array of dictionaries [[URLString:Title]]
    static var foundFlicksArray:[[String:String]] = []

    // user
    struct UserInfo {
        static let apikey = "f966f92b0e383ff5e2807efe3be9891f"
    }
    
    // network parameters
    struct APIInfo {
        static let scheme = "https"
        static let host = "www.flickr.com"
        static let path = "/services/rest/"
        static let urlHostBase = "https://live.staticflickr.com/"
    }
    
    /*
     Flickr endpoints
     Handle building and creation of endpoint URL using URLComponents
     */
    enum Endpoints {
        // search geographic region
        case searchGeo(lat: Double, lon: Double)
        
        // return url for endpoint
        var url:URL? {
            // build components
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
    
    /*
     FlickrError
     Error handling for Flickr networking
     */
    enum FlickrError: LocalizedError {
        case urlError
        case badFlickrDownload
        case geoError
        
        var errorDescription: String? {
            switch self {
            case .urlError:
                return "Bad URL"
            case .badFlickrDownload:
                return "Bad Flickr download."
            case .geoError:
                return "Error with geography."
            }
        }
        var failureReason: String? {
            switch self {
            case .urlError:
                return "Possbile bad text formatting."
            case .badFlickrDownload:
                return "Bad data/response from Flickr."
            case .geoError:
                return "Possible invalid coordinates."
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

// MARK: Flickr API and GeoCode methods
extension FlickrAPI {
    
    /*
     handle geoSearch
     Search geography and place found flicks into foundFlicksArray
     */
    class func geoSearchFlickr(latitude: Double, longitude: Double, completion: @escaping (Bool, LocalizedError?) -> Void) {
        
        // verify good enpoint URL
        guard let url = Endpoints.searchGeo(lat: latitude, lon: longitude).url else {
            completion(false, FlickrError.urlError)
            return
        }
        
        // Perform task
        taskGET(url: url, responseType: FlickrSearchResponse.self) { response, error in
            guard let response = response else {
                // bad response
                completion(false, FlickrError.urlError)
                return
            }
            // good response
            foundFlicksArray = createRandomURLStringArray(response: response)
            completion(true, nil)
        }
    }
    
    /*
     handle reverse geocoding
     Retrieve a sting name (city name, state name, etc) for location
     */
    class func reverseGeoCode(location: CLLocation, completion: @escaping (String?, LocalizedError?) -> Void) {
        /*
         Use reverseGeocodeLocation to retrieve appropriate name string. This string is used for map annotation title and album name
         */
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(location) { placemarks, error in
            
            guard let placeMark = placemarks?.first else {
                DispatchQueue.main.async {
                    completion(nil, FlickrError.geoError)
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
    
    /*
     handle flick data retrieval
     Retrieve flick image in Data format
     */
    class func getFlickData(url: URL, completion: @escaping (Data?, LocalizedError?) -> Void) {
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                // bad return data
                completion(nil, FlickrError.urlError)
                return
            }
            // good data
            completion(data, nil)
        }
        task.resume()
    }
}

// MARK: Network methods
extension FlickrAPI {
    
    // Network GET. Retreive data formatted to "ResponseType"
    class func taskGET<ResponseType: Decodable>(url: URL, responseType:ResponseType.Type, completion: @escaping (ResponseType?, LocalizedError?) -> Void) {
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                // bad data
                DispatchQueue.main.async {
                    completion(nil, FlickrError.badFlickrDownload)
                }
                return
            }
            do {
                // good data returned. Decode into ResponseType format
                let response = try JSONDecoder().decode(responseType.self, from: data)
                DispatchQueue.main.async {
                    completion(response, nil)
                }
            } catch {
                // unable to decode
                DispatchQueue.main.async {
                    completion(nil, FlickrError.badFlickrDownload)
                }
                return
            }
        }
        task.resume()
    }
}

// MARK: Helper methods
extension FlickrAPI {
    
    // parse FlickrSearchResponse and return [[urlString:title]]
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
            
            // url creation per Flickr API
            let urlString = APIInfo.urlHostBase + flick.server + "/" + flick.id + "_" + flick.secret + ".jpg"
            
            // flick title
            let title = (flick.title == "") ? ("Flick: \(index)") : flick.title
            
            dictionary[urlString] = title
        }
        
        // sort by url string..same order that's used in AlbumView..aids in Album collection view, forcing images to download and appear in order
        var urlStringArray:[[String:String]] = []
        for key in dictionary.keys.sorted() {
            if let value = dictionary[key] {
                urlStringArray.append([key:value])
            }
        }
        return urlStringArray
    }
}
