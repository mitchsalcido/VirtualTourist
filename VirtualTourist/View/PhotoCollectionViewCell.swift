//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/27/22.
//
/*
 About PhotoCollectionViewCell:
 Custom collectionView cell
 */
import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    // Photo
    @IBOutlet weak var imageView: UIImageView!
    
    // checkmark image. Used to indicate ready for deletion
    @IBOutlet weak var checkmarkImageView: UIImageView!
    
    // downloading photo in progress
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!    
}
