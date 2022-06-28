//
//  AlbumCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/27/22.
//

import UIKit

class AlbumCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var checkmarkImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var markedForDeletion = false
}
