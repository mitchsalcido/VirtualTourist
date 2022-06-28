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
    
    static let MAX_FLICKS = 50
    static var flickURLStringArray:[String] = []

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
            flickURLStringArray = createRandomURLStringArray(response: response)
            completion(true, nil)
        }
    }
    
    class func getFlick(url: URL, completion: @escaping (UIImage?, Error?) -> Void) {
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            DispatchQueue.main.async {
                completion(UIImage(data: data), nil)
            }
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
    
    // parse FlickrSearchResponse and return url strings formatted per Flickr API docs
    class func createRandomURLStringArray(response: FlickrSearchResponse) -> [String] {
        
        var photo = response.photos.photo
        
        // random photo responses
        var randomPhotoArray:[PhotoResponse] = []
        while photo.count > 0 {
            let randomIndex = Int.random(in: 0..<photo.count)
            randomPhotoArray.append(photo.remove(at: randomIndex))
        }
        
        if randomPhotoArray.count > MAX_FLICKS {
            var smallerArray:[PhotoResponse] = []
            for index in 0..<MAX_FLICKS {
                smallerArray.append(randomPhotoArray[index])
            }
            randomPhotoArray = smallerArray
        }
        
        var urlStringArray:[String] = []
        for flick in randomPhotoArray {
            let urlString = APIInfo.urlHostBase + flick.server + "/" + flick.id + "_" + flick.secret + ".jpg"
            urlStringArray.append(urlString)
        }
        return urlStringArray
    }
}
