//
//  Pin+Ext.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 7/10/22.
//
/*
 About Pin+Ext:
 Extension of Pin entity
 */
import Foundation
import CoreData

extension Pin {
    
    // count of Photo's with non-nil imageData (i.e. downloaded images)
    func downloadedPhotoImageCount() -> Int {
        guard let photos = self.photos as? Set<Photo> else {
            return 0
        }
        
        var count = 0
        for photo in photos {
            if let _ = photo.imageData {
                count += 1
            }
        }
        return count
    }
}
