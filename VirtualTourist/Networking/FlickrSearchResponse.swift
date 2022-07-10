//
//  FlickrSearchResponse.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//
/*
 About FlickrSearchResponse:
 Data model for Flickr responses. Geosearch data resturned from Flickr is decoded into stucts below
*/

import Foundation

// top level photo response
struct FlickrSearchResponse: Codable {
    let stat: String
    let photos: PhotosResponse
    
    enum CodingKeys: String, CodingKey {
        case stat
        case photos
    }
}

// returned photos
struct PhotosResponse: Codable {
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int
    let photo: [PhotoResponse]

    enum CodingKeys: String, CodingKey {
        case page
        case pages
        case perPage = "perpage"
        case total
        case photo
    }
}

// a single photo
struct PhotoResponse: Codable {
    let id: String
    let owner: String
    let secret: String
    let server: String
    let farm: Int
    let title: String
    let isPublic: Int
    let isFriend: Int
    let isFamily: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case owner
        case secret
        case server
        case farm
        case title
        case isPublic = "ispublic"
        case isFriend = "isfriend"
        case isFamily = "isfamily"
    }
}
