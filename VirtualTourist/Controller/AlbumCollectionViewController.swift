//
//  AlbumCollectionViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit

private let reuseIdentifier = "AlbumCellID"

class AlbumCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
        
    var emptyBbi: UIBarButtonItem!
    
    var flickrAnnotation:FlickrAnnotation!

    
    var flicksToDelete:Set<IndexPath> = []
    
    let CellSpacing:CGFloat = 5.0
    let CellsPerRow:CGFloat = 5.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        flowLayout.minimumLineSpacing = CellSpacing
        flowLayout.minimumInteritemSpacing = CellSpacing
        
        if flickrAnnotation.photosURLString.count > 0 {
            navigationItem.rightBarButtonItem = editButtonItem
        }

        if flickrAnnotation.downloadedFlicks.count != flickrAnnotation.photosURLString.count {
            
            flickrAnnotation.downloadedFlicks = []
            downloadFlicks()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        flowLayout.invalidateLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        flicksToDelete.removeAll()
        collectionView.reloadData()

        if editing {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBbiPressed(sender:)))
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }
}

// MARK: UICollectionViewDataSource
extension AlbumCollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return flickrAnnotation.photosURLString.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! AlbumCollectionViewCell
    
        // Configure the cell
        if indexPath.row < flickrAnnotation.downloadedFlicks.count {
            cell.imageView.image = flickrAnnotation.downloadedFlicks[indexPath.row]
            cell.activityIndicator.stopAnimating()
        } else {
            cell.activityIndicator.startAnimating()
        }

        if isEditing {
            cell.imageView.alpha = 0.75
            
            if flicksToDelete.contains(indexPath) {
                cell.checkmarkImageView.isHidden = false
            } else {
                cell.checkmarkImageView.isHidden = true
            }
        } else {
            cell.imageView.alpha = 1.0
            cell.checkmarkImageView.isHidden = true
        }
        
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension AlbumCollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if !self.isEditing {
            return
        }
        
        if flicksToDelete.contains(indexPath) {
            flicksToDelete.remove(indexPath)
        } else {
            flicksToDelete.insert(indexPath)
        }
        
        navigationItem.leftBarButtonItem?.isEnabled = !flicksToDelete.isEmpty
        
        collectionView.reloadItems(at: [indexPath])
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension AlbumCollectionViewController {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let size = collectionView.bounds.width - (CellsPerRow - 1.0) * CellSpacing
        return CGSize(width: size / CellsPerRow, height: size / CellsPerRow)
    }
}

// MARK: Helpers
extension AlbumCollectionViewController {
    
    fileprivate func downloadFlicks() {
        for urlString in flickrAnnotation.photosURLString {
            if let url = URL(string: urlString) {
                
                FlickrAPI.getFlick(url: url) { image, error in
                    if let image = image {
                        // good image. Add to collectionView
                        let indexPath = IndexPath(row: self.flickrAnnotation.downloadedFlicks.count, section:0)
                        self.flickrAnnotation.downloadedFlicks.append(image)
                        self.collectionView.insertItems(at: [indexPath])
                    }
                }
            }
        }
    }
}

// MARK: BarButtonItem Actions
extension AlbumCollectionViewController {
    
    @objc func trashBbiPressed(sender: UIBarButtonItem) {
        
        let updates = {
            
            var indexPaths = self.flicksToDelete.sorted()
            indexPaths = indexPaths.reversed()
            for indexPath in indexPaths {
                self.flickrAnnotation.photosURLString.remove(at: indexPath.row)
                self.flickrAnnotation.downloadedFlicks.remove(at: indexPath.row)
            }
            
            self.collectionView.reloadSections(IndexSet(integer: 0))
            self.setEditing(false, animated: false)
        }
        
        collectionView.performBatchUpdates(updates) { _ in
        }
    }
}
