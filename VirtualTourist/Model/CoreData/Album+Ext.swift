//
//  Album+Ext.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 7/3/22.
//

import Foundation
import CoreData

extension Album {
    
    func downloadedFlickImageCount() -> Int {
        guard let flicks = self.flicks as? Set<Flick> else {
            return 0
        }
        
        var count = 0
        for flick in flicks {
            if let _ = flick.imageData {
                count += 1
            }
        }
        return count
    }
}
